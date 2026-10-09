"""Run with .venv/Scripts/python -m unittest discover -s agent_harness/tests -v."""
from __future__ import annotations

import asyncio
import json
import os
import socket
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import AsyncMock, Mock, patch

from pydantic_ai.messages import ModelResponse, RetryPromptPart, TextPart, ToolCallPart, ToolReturnPart
from pydantic_ai.models.function import DeltaToolCall, FunctionModel
from pydantic_ai.usage import UsageLimits

with patch.dict(os.environ, {"AGENT_HARNESS_API_KEY": "unit-test-key", "AGENT_HARNESS_BASE_URL": "https://api.deepseek.com"}):
    from agent_harness import app as h


class HarnessTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="harness-test-")
        self.addCleanup(self.tmp.cleanup)
        self.db = Path(self.tmp.name) / "knowledge.db"
        self.row = {"id": "doc", "title": "campus scholarship", "content": "scholarship application instructions",
                    "sourceUrl": "https://news.xidian.edu.cn/info/doc.htm", "status": "published"}
        with closing(sqlite3.connect(self.db)) as connection:
            connection.execute("CREATE TABLE documents(data TEXT)")
            connection.execute("INSERT INTO documents VALUES(?)", (json.dumps(self.row),))
            connection.commit()
        self.patch(h, "corpus_path", self.db)
        self.patch(h, "run_slots", asyncio.Semaphore(4))
        self.patch(h, "_search_campus_pages", AsyncMock(return_value=[]))
        self.patch(h, "_search_internet_pages", AsyncMock(return_value=[]))
        self.patch(h, "_resolve_via_doh", Mock(return_value=()))
        self.deps = h.AgentContext(h.CampusCorpus(self.db))
        self.ctx = SimpleNamespace(deps=self.deps)
        self.request = h.ChatRequest(question="scholarship instructions", trace_id="test-trace")

    def patch(self, target, name, value):
        patcher = patch.object(target, name, value)
        patcher.start()
        self.addCleanup(patcher.stop)

    def update(self, **changes):
        self.row.update(changes)
        with closing(sqlite3.connect(self.db)) as connection:
            connection.execute("UPDATE documents SET data=?", (json.dumps(self.row),))
            connection.commit()

    async def collect(self, request=None):
        response = await h.chat_stream(request or self.request)
        return [json.loads(frame.removeprefix("data: ").strip()) async for frame in response.body_iterator]

    async def test_title_and_body_match_merge_without_losing_excerpts(self):
        result = await h.search_all_sources(self.ctx, ["scholarship"])
        self.assertEqual(len(result["local_documents"]), 1)
        self.assertTrue(result["local_documents"][0]["excerpts"])

    async def test_unreturned_local_document_does_not_suppress_web_result(self):
        h._search_internet_pages.return_value = [{"url": self.row["sourceUrl"], "title": "new activity"}]
        result = await h.search_all_sources(self.ctx, ["unmatched"])
        self.assertEqual(result["local_documents"], [])
        self.assertEqual(len(result["internet_pages"]), 1)

    async def test_returned_local_source_can_be_opened_for_fresh_verification(self):
        h._search_internet_pages.return_value = [{"url": self.row["sourceUrl"], "title": "scholarship"}]
        result = await h.search_all_sources(self.ctx, ["scholarship"])
        self.assertEqual(result["internet_pages"], [])
        self.assertIn(self.row["sourceUrl"], self.deps.discovered_pages)

    async def test_archived_document_is_removed_from_search_and_read(self):
        self.update(status="archived")
        result = await h.search_all_sources(self.ctx, ["scholarship"])
        self.assertEqual(result["local_documents"], [])
        self.assertIn("error", h.read_files(self.ctx, ["doc"])[0])

    async def test_document_revision_is_visible_without_restart(self):
        self.update(content="updated scholarship instructions")
        result = h.read_files(self.ctx, ["doc"])
        self.assertEqual(result[0]["content"], self.row["content"])

    async def test_real_agent_search_read_and_citation(self):
        calls = 0

        def model(messages, info):
            nonlocal calls
            calls += 1
            if calls == 1:
                return ModelResponse(parts=[ToolCallPart("search_all_sources", {"queries": ["scholarship"]})])
            if calls == 2:
                return ModelResponse(parts=[ToolCallPart("read_files", {"file_ids": ["doc"]})])
            return ModelResponse(parts=[TextPart("Application instructions [1]")])

        with h.agent.override(model=FunctionModel(model)):
            result = await h.chat(self.request)
        self.assertEqual(result["sources"][0]["documentId"], "doc")
        self.assertEqual(result["usage"]["requests"], 3)
        self.assertEqual(result["usage"]["toolCalls"], 2)

    def ui_request(self):
        return h.ChatRequest(question='scholarship instructions', uiVersion=1,
                             uiServices=[{'id': 'ehall', 'name': '服务大厅', 'description': '打开官方入口。'}])

    async def test_card_only_citations_are_preserved_in_final_sources(self):
        calls = 0

        def model(messages, info):
            nonlocal calls
            calls += 1
            if calls == 1:
                return ModelResponse(parts=[ToolCallPart('read_files', {'file_ids': ['doc']})])
            if calls == 2:
                return ModelResponse(parts=[ToolCallPart('present_ui', {'ui': {'version': 1, 'cards': [
                    {'type': 'source_list', 'citations': [1]},
                    {'type': 'guide', 'title': '申请说明', 'steps': [
                        {'title': '准备材料', 'detail': '阅读申请通知。', 'citations': [1]}]},
                    {'type': 'service_links', 'serviceIds': ['ehall']}]}})])
            return ModelResponse(parts=[TextPart('Read the application notice and prepare the required documents.')])

        with h.agent.override(model=FunctionModel(model)):
            result = await h.chat(self.ui_request())
        self.assertEqual(len(result['ui']['cards']), 3)
        self.assertEqual(result['sources'][0]['documentId'], 'doc')
        self.assertEqual(result['usage']['requests'], 3)
        self.assertEqual(result['uiErrors'], [])

    async def test_unregistered_service_falls_back_to_text(self):
        calls = 0

        def model(messages, info):
            nonlocal calls
            calls += 1
            if calls == 1:
                return ModelResponse(parts=[ToolCallPart('present_ui', {'ui': {'version': 1, 'cards': [
                    {'type': 'service_links', 'serviceIds': ['personal-grades']}]}})])
            return ModelResponse(parts=[TextPart('Personal data is not connected.')])

        with h.agent.override(model=FunctionModel(model)):
            result = await h.chat(self.ui_request())
        self.assertIsNone(result['ui'])
        self.assertIn('unknown_service', result['uiErrors'][0])
        self.assertEqual(result['answer'], 'Personal data is not connected.')

    async def test_malformed_presentation_falls_back_without_tool_validation_retry(self):
        calls = 0

        def model(messages, info):
            nonlocal calls
            calls += 1
            if calls == 1:
                schema = next(tool.parameters_json_schema for tool in info.function_tools if tool.name == 'present_ui')
                self.assertIn('cards', schema['properties']['ui']['properties'])
                return ModelResponse(parts=[ToolCallPart('present_ui', {'ui': {'version': 1, 'cards': [
                    {'type': 'html', 'html': '<script>alert(1)</script>'}]}})])
            return ModelResponse(parts=[TextPart('Plain answer after invalid presentation.')])

        with h.agent.override(model=FunctionModel(model)):
            result = await h.chat(self.ui_request())
        self.assertIsNone(result['ui'])
        self.assertIn('invalid_schema', result['uiErrors'][0])
        self.assertEqual(calls, 2)

    async def test_ui_is_hidden_from_legacy_client_model(self):
        def model(messages, info):
            self.assertNotIn('present_ui', [tool.name for tool in info.function_tools])
            return ModelResponse(parts=[TextPart('Plain answer.')])

        with h.agent.override(model=FunctionModel(model)):
            result = await h.chat(self.request)
        self.assertIsNone(result['ui'])

    async def test_archived_card_source_drops_card_without_breaking_text(self):
        calls = 0

        def model(messages, info):
            nonlocal calls
            calls += 1
            if calls == 1:
                return ModelResponse(parts=[ToolCallPart('read_files', {'file_ids': ['doc']})])
            if calls == 2:
                return ModelResponse(parts=[ToolCallPart('present_ui', {'ui': {'version': 1, 'cards': [
                    {'type': 'source_list', 'citations': [1]}, {'type': 'service_links', 'serviceIds': ['ehall']}]}})])
            self.update(status='archived')
            return ModelResponse(parts=[TextPart('Open the official service for current information.')])

        with h.agent.override(model=FunctionModel(model)):
            result = await h.chat(self.ui_request())
        self.assertEqual(result['ui']['cards'], [{'type': 'service_links', 'serviceIds': ['ehall']}])
        self.assertEqual(result['sources'], [])
        self.assertIn('invalid_source', result['uiErrors'][0])

    async def test_ui_latest_valid_submission_wins_and_retry_does_not_show_draft(self):
        calls = 0

        async def model(messages, info):
            nonlocal calls
            calls += 1
            if calls in (1, 2):
                ids = ['ehall'] if calls == 1 else ['ehall', 'schoolnet']
                yield {0: DeltaToolCall(name='present_ui', json_args=json.dumps({'ui': {'version': 1,
                    'cards': [{'type': 'service_links', 'serviceIds': ids}]}}), tool_call_id=f'ui-{calls}')}
            elif calls == 3:
                yield 'Unsupported [99]'
            else:
                yield 'Use the official service.'

        request = self.ui_request()
        request.uiServices.append(h.UIService(id='schoolnet', name='校园网', description='校园网入口。'))
        with h.agent.override(model=FunctionModel(stream_function=model)):
            events = await self.collect(request)
        complete = events[-1]
        self.assertEqual(complete['type'], 'complete')
        self.assertEqual(complete['ui']['cards'][0]['serviceIds'], ['ehall', 'schoolnet'])
        self.assertEqual(complete['answer'], 'Use the official service.')
        self.assertFalse(any('ui' in event for event in events[:-1]))

    async def test_cancelled_presentation_has_no_complete_event(self):
        calls = 0
        waiting = asyncio.Event()
        stopped = asyncio.Event()

        async def model(messages, info):
            nonlocal calls
            calls += 1
            if calls == 1:
                yield {0: DeltaToolCall(name='present_ui', json_args=json.dumps({'ui': {'version': 1,
                    'cards': [{'type': 'service_links', 'serviceIds': ['ehall']}]}}), tool_call_id='ui')}
            else:
                waiting.set()
                try:
                    await asyncio.sleep(10)
                finally:
                    stopped.set()

        with h.agent.override(model=FunctionModel(stream_function=model)):
            pending = asyncio.create_task(self.collect(self.ui_request()))
            await asyncio.wait_for(waiting.wait(), 1)
            pending.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await pending
            await asyncio.wait_for(stopped.wait(), 1)

    async def test_invalid_citation_triggers_real_model_retry(self):
        calls = 0

        def model(messages, info):
            nonlocal calls
            calls += 1
            if calls == 1:
                return ModelResponse(parts=[TextPart("Unsupported [99]")])
            return ModelResponse(parts=[TextPart("No verified source found.")])

        with h.agent.override(model=FunctionModel(model)):
            result = await h.chat(self.request)
        self.assertEqual(calls, 2)
        self.assertNotIn("[99]", result["answer"])
        self.assertEqual(result["sources"], [])

    async def test_archiving_between_read_and_answer_rejects_stale_citation(self):
        calls = 0

        def model(messages, info):
            nonlocal calls
            calls += 1
            if calls == 1:
                return ModelResponse(parts=[ToolCallPart("read_files", {"file_ids": ["doc"]})])
            if calls == 2:
                self.update(status="archived")
                return ModelResponse(parts=[TextPart("Old rule [1]")])
            return ModelResponse(parts=[TextPart("The document is no longer published.")])

        with h.agent.override(model=FunctionModel(model)):
            result = await h.chat(self.request)
        self.assertEqual(calls, 3)
        self.assertEqual(result["sources"], [])

    async def test_stream_contains_real_tools_answer_and_usage(self):
        calls = 0

        async def model(messages, info):
            nonlocal calls
            calls += 1
            if calls == 1:
                yield {0: DeltaToolCall(name="read_files", json_args='{"file_ids":["doc"]}', tool_call_id="read-1")}
            else:
                yield "Application "
                yield "instructions [1]"

        with h.agent.override(model=FunctionModel(stream_function=model)):
            events = await self.collect()
        kinds = [event["type"] for event in events]
        self.assertIn("tool_call", kinds)
        self.assertIn("tool_result", kinds)
        self.assertIn("answer_delta", kinds)
        self.assertEqual(events[-1]["type"], "complete")
        self.assertEqual(events[-1]["sources"][0]["documentId"], "doc")

    async def test_rejected_tool_call_reports_failure_and_finishes(self):
        """A tool call rejected before execution yields a RetryPromptPart result.

        That part has no `outcome`, so reading it unconditionally raised AttributeError inside the
        SSE generator and cut the stream off without an `error` or `complete` frame.
        """
        calls = 0

        async def model(messages, info):
            nonlocal calls
            calls += 1
            if calls == 1:
                yield {0: DeltaToolCall(name="read_files", json_args='{"file_ids": 12345}', tool_call_id="read-1")}
            else:
                yield "No verified source found."

        with h.agent.override(model=FunctionModel(stream_function=model)):
            events = await self.collect()
        results = [event for event in events if event["type"] == "tool_result"]
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]["tool"], "read_files")
        self.assertEqual(results[0]["outcome"], "failed")
        self.assertEqual(events[-1]["type"], "complete")
        self.assertEqual(events[-1]["answer"], "No verified source found.")

    async def test_tool_result_outcome_distinguishes_return_and_retry(self):
        self.assertEqual(h._tool_result_outcome(ToolReturnPart("read_files", "{}", tool_call_id="c")), "success")
        self.assertEqual(h._tool_result_outcome(RetryPromptPart("bad args", tool_name="read_files", tool_call_id="c")), "failed")
        self.assertEqual(h._tool_result_outcome(SimpleNamespace(part_kind="retry-prompt")), "failed")
        self.assertEqual(h._tool_result_outcome(SimpleNamespace(part_kind="anything-else")), "unknown")

    async def test_stream_retry_resets_provisional_answer(self):
        calls = 0

        async def model(messages, info):
            nonlocal calls
            calls += 1
            yield "Unsupported [99]" if calls == 1 else "No verified source found."

        with h.agent.override(model=FunctionModel(stream_function=model)):
            events = await self.collect()
        displayed = ""
        for event in events:
            if event["type"] == "answer_reset":
                displayed = ""
            elif event["type"] == "answer_delta":
                displayed += event["text"]
        self.assertEqual(events[-1]["type"], "complete")
        self.assertEqual(displayed, events[-1]["answer"])
        self.assertNotIn("[99]", displayed)

    async def test_model_loop_hits_request_budget(self):
        self.patch(h, "RUN_LIMITS", UsageLimits(request_limit=2))
        model = FunctionModel(lambda messages, info: ModelResponse(parts=[ToolCallPart("get_current_datetime", {})]))
        with h.agent.override(model=model), self.assertRaises(h.HTTPException) as caught:
            await h.chat(self.request)
        self.assertEqual(caught.exception.detail["code"], "ai_budget_exceeded")
        self.assertFalse(h.run_slots.locked())

    async def test_timeout_cancels_model_and_releases_slot(self):
        self.patch(h, "RUN_TIMEOUT_SECONDS", 0.03)
        stopped = asyncio.Event()

        async def model(messages, info):
            try:
                await asyncio.sleep(10)
            finally:
                stopped.set()

        with h.agent.override(model=FunctionModel(model)), self.assertRaises(h.HTTPException) as caught:
            await h.chat(self.request)
        self.assertEqual(caught.exception.detail["code"], "ai_timeout")
        self.assertTrue(stopped.is_set())
        self.assertFalse(h.run_slots.locked())

    async def test_busy_service_rejects_without_waiting(self):
        self.patch(h, "run_slots", asyncio.Semaphore(1))
        async with h._run_slot():
            with self.assertRaises(h.HTTPException) as caught:
                await h.chat(self.request)
        self.assertEqual(caught.exception.detail["code"], "ai_busy")

    async def test_cancelled_stream_cancels_framework_background_model(self):
        started, stopped = asyncio.Event(), asyncio.Event()

        async def model(messages, info):
            started.set()
            try:
                await asyncio.sleep(10)
                yield "finished"
            finally:
                stopped.set()

        with h.agent.override(model=FunctionModel(stream_function=model)):
            consumer = asyncio.create_task(self.collect())
            await asyncio.wait_for(started.wait(), 2)
            consumer.cancel()
            with self.assertRaises(asyncio.CancelledError):
                await consumer
        self.assertTrue(stopped.is_set())
        self.assertFalse(h.run_slots.locked())

    def test_history_preserves_source_map_and_limits_total_size(self):
        source = {"citation": 1, "title": "old source", "source": self.row["sourceUrl"], "documentId": "doc"}
        request = h.ChatRequest(question="follow up", history=[
            {"role": "user", "content": "previous question"},
            {"role": "assistant", "content": "previous answer [1]", "sources": [source]},
        ])
        history = h._build_history(request)
        self.assertIn(self.row["sourceUrl"], history[-1].parts[0].content)
        request.history *= 8
        self.assertLessEqual(sum(len(message.parts[0].content) for message in h._build_history(request)), h.MAX_HISTORY_CHARS)

    def test_corpus_read_connection_is_closed(self):
        h.CampusCorpus(self.db)
        moved = self.db.with_suffix(".moved")
        self.db.rename(moved)
        moved.rename(self.db)

    def test_reserved_private_and_mixed_dns_addresses_are_rejected(self):
        for addresses in [["127.0.0.1"], ["198.18.0.1"], ["93.184.216.34", "10.0.0.1"]]:
            rows = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", (address, 443)) for address in addresses]
            with patch.object(h.socket, "getaddrinfo", return_value=rows):
                self.assertFalse(h._is_public_internet_url("https://example.com/"))
        self.assertFalse(h._is_public_internet_url("https://example.com:bad/"))
        self.assertFalse(h._is_public_internet_url("https://user:password@example.com/"))

    def test_dns_rebinding_is_rechecked_before_socket_connection(self):
        public = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))]
        private = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("127.0.0.1", 443))]
        with patch.object(h.socket, "getaddrinfo", side_effect=[public, private]), patch.object(h.socket, "socket") as socket_factory:
            self.assertTrue(h._is_public_internet_url("https://example.com/"))
            with self.assertRaises(ValueError):
                h._create_public_connection(("example.com", 443))
            socket_factory.assert_not_called()

    def test_connection_uses_checked_numeric_address(self):
        rows = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", 443))]
        connection = Mock()
        with patch.object(h.socket, "getaddrinfo", return_value=rows), patch.object(h.socket, "socket", return_value=connection):
            self.assertIs(h._create_public_connection(("example.com", 443)), connection)
        connection.connect.assert_called_once_with(("93.184.216.34", 443))

    def test_proxy_dns_uses_real_public_address_instead_of_allowing_reserved_range(self):
        rows = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("198.18.0.1", 443))]
        h._resolve_via_doh.return_value = ("93.184.216.34",)
        connection = Mock()
        with patch.object(h.socket, "getaddrinfo", return_value=rows), patch.object(h.socket, "socket", return_value=connection):
            self.assertTrue(h._is_public_internet_url("https://example.com/"))
            h._create_public_connection(("example.com", 443))
            self.assertFalse(h._is_public_internet_url("https://198.18.0.1/"))
        connection.connect.assert_called_once_with(("93.184.216.34", 443))

    def test_unavailable_public_dns_does_not_relax_destination_check(self):
        rows = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("198.18.0.1", 443))]
        h._resolve_via_doh.side_effect = OSError("DNS unavailable")
        with patch.object(h.socket, "getaddrinfo", return_value=rows):
            self.assertFalse(h._is_public_internet_url("https://example.com/"))
            with self.assertRaises(OSError):
                h._create_public_connection(("example.com", 443))


if __name__ == "__main__":
    unittest.main()
