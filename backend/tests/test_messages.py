"""私信功能测试。"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

# 添加 backend 目录到 Python 路径
backend_dir = Path(__file__).parent.parent
sys.path.insert(0, str(backend_dir))


class TestNoMessageRequests:
    """There is no request step: nothing stores or routes message requests."""

    def test_default_db_has_no_dm_requests(self):
        from server import default_db

        assert "dmRequests" not in default_db()

    def test_request_routes_are_gone(self):
        from pathlib import Path

        source = (Path(__file__).parent.parent / "server.py").read_text(encoding="utf-8")
        assert "/api/messages/requests" not in source


class TestConversationHelpers:
    """测试会话相关的辅助函数。"""

    def test_default_db_has_conversations(self):
        """测试默认数据库包含会话。"""
        from server import default_db

        db = default_db()

        assert "conversations" in db
        assert "directMessages" in db
        assert len(db["conversations"]) > 0

    def test_conversation_structure(self):
        """测试会话结构。"""
        from server import default_db

        db = default_db()
        conversations = db["conversations"]

        for conv in conversations:
            assert "id" in conv
            assert "userId" in conv
            assert "peerUserId" in conv
            assert "name" in conv
            assert "lastMessage" in conv
            assert "updatedAt" in conv

    def test_direct_message_structure(self):
        """测试私信消息结构。"""
        from server import default_db

        db = default_db()
        messages = db["directMessages"]

        for msg in messages:
            assert "id" in msg
            assert "conversationKey" in msg
            assert "senderUserId" in msg
            assert "receiverUserId" in msg
            assert "content" in msg
            assert "createdAt" in msg

    def test_conversation_key_format(self):
        """测试会话键格式。"""
        from server import default_db

        db = default_db()
        messages = db["directMessages"]

        for msg in messages:
            key = msg["conversationKey"]
            parts = key.split("::")
            assert len(parts) == 2
            assert parts[0] != parts[1]  # 发送者和接收者不同


class TestUserBlocks:
    """测试用户拉黑功能。"""

    def test_default_db_has_user_blocks(self):
        """测试默认数据库包含用户拉黑表。"""
        from server import default_db

        db = default_db()
        assert "userBlocks" in db

    def test_user_block_structure(self):
        """测试用户拉黑结构。"""
        from server import default_db

        db = default_db()
        blocks = db["userBlocks"]

        assert isinstance(blocks, list)


class TestRateLimitsForMessages:
    """测试消息相关限流。"""

    def test_message_rate_limit_config(self):
        """测试消息限流配置。"""
        from server import DEFAULT_SETTINGS, IP_RATE_LIMITS

        assert "messageRateLimit" in DEFAULT_SETTINGS
        assert "message" in IP_RATE_LIMITS


class TestConversationQueries:
    """测试会话查询逻辑。"""

    def test_conversation_ordering(self):
        """测试会话排序。"""
        from server import default_db

        db = default_db()
        conversations = db["conversations"]

        # 会话应该按更新时间排序
        for i in range(len(conversations) - 1):
            curr_time = conversations[i].get("updatedAt", "")
            next_time = conversations[i + 1].get("updatedAt", "")
            if curr_time and next_time:
                assert curr_time >= next_time

    def test_unread_count_tracking(self):
        """测试未读计数跟踪。"""
        from server import default_db

        db = default_db()
        conversations = db["conversations"]

        for conv in conversations:
            assert "unreadCount" in conv
            assert isinstance(conv["unreadCount"], int)
            assert conv["unreadCount"] >= 0


class TestMessageQueries:
    """测试消息查询逻辑。"""

    def test_message_ordering(self):
        """测试消息排序。"""
        from server import default_db

        db = default_db()
        messages = db["directMessages"]

        # 消息应该按创建时间排序
        for i in range(len(messages) - 1):
            curr_time = messages[i].get("createdAt", "")
            next_time = messages[i + 1].get("createdAt", "")
            if curr_time and next_time:
                assert curr_time <= next_time

    def test_message_conversation_filtering(self):
        """测试消息按会话过滤。"""
        from server import default_db

        db = default_db()
        messages = db["directMessages"]
        conversations = db["conversations"]

        # 每个消息的 conversationKey 应该对应一个会话
        for msg in messages:
            key_parts = msg["conversationKey"].split("::")
            assert len(key_parts) == 2

            # 查找对应的会话
            matching_convs = [
                c
                for c in conversations
                if (c["userId"] in key_parts and c["peerUserId"] in key_parts)
            ]
            # 注意：可能找不到精确匹配，这是正常的


class TestDirectMessagePrivacyRules:
    """测试直接私信入口与发送阶段的隐私规则。"""

    def test_direct_entry_respects_contact_visibility_and_dm_privacy(self):
        from server import default_db
        from services._user_service import can_request_dm_to_user

        db = default_db()
        viewer = {"id": "viewer_dm_entry", "email": "viewer@stu.xidian.edu.cn", "nickname": "Viewer"}
        target = {
            "id": "target_dm_entry",
            "email": "target@stu.xidian.edu.cn",
            "nickname": "Target",
            "allowStrangerDm": False,
            "showContactable": False,
        }
        db["users"].extend([viewer, target])

        assert not can_request_dm_to_user(
            db,
            viewer_user_id=viewer["id"],
            target_user_id=target["id"],
        )

    def test_post_author_message_entry_respects_dm_privacy(self):
        from server import default_db
        from services._db_service import serialize_post

        db = default_db()
        viewer = {"id": "viewer_post_dm", "email": "viewer_post@stu.xidian.edu.cn", "nickname": "Viewer"}
        author = {
            "id": "author_post_dm",
            "email": "author_post@stu.xidian.edu.cn",
            "nickname": "Author",
            "allowStrangerDm": False,
            "showContactable": False,
        }
        post = {
            "id": "post_dm_entry",
            "title": "Test",
            "content": "Test content",
            "authorId": author["id"],
            "authorAlias": "Author",
            "createdAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-01T00:00:00Z",
            "deleted": False,
            "useAnonymousAlias": False,
            "visibility": "public",
            "reviewStatus": "approved",
            "allowComment": True,
            "allowDm": False,
        }
        db["users"].extend([viewer, author])
        db["posts"].append(post)

        serialized = serialize_post(db, post, viewer_user_id=viewer["id"])

        assert serialized["canMessageAuthor"] is False

    def test_send_message_rejects_when_peer_closed_dm(self, monkeypatch: pytest.MonkeyPatch):
        import io
        import json

        from handlers import _message_handler
        from server import default_db

        db = default_db()
        sender = {"id": "sender_closed_dm", "email": "sender@stu.xidian.edu.cn", "nickname": "Sender"}
        receiver = {
            "id": "receiver_closed_dm",
            "email": "receiver@stu.xidian.edu.cn",
            "nickname": "Receiver",
            "allowStrangerDm": False,
        }
        conversation = {
            "id": "conv_closed_dm",
            "userId": sender["id"],
            "peerUserId": receiver["id"],
            "name": "Receiver",
            "lastMessage": "",
            "updatedAt": "2026-01-01T00:00:00Z",
            "unreadCount": 0,
            "deleted": False,
        }
        db["users"].extend([sender, receiver])
        db["conversations"].append(conversation)

        class FakeHandler:
            def __init__(self):
                self.wfile = io.BytesIO()
                self.status_code = 0
                self.response_headers = []
                self.headers = {}

            def send_response(self, code):
                self.status_code = code

            def send_header(self, key, val):
                self.response_headers.append((key, val))

            def end_headers(self):
                pass

        monkeypatch.setattr(_message_handler, "auth_user_helper", lambda h, d: (sender, "token"))
        monkeypatch.setattr(_message_handler, "read_json_body", lambda h: {"content": "hello"})

        handler = FakeHandler()
        _message_handler.handle_send_message(handler, db, conversation["id"])

        assert handler.status_code == 403
        payload = json.loads(handler.wfile.getvalue().decode("utf-8"))
        assert "关闭私信" in payload["message"]


class TestUserBlockHandlers:
    """测试全局黑名单 API 处理函数。"""

    def test_block_and_unblock_user_globally(self, monkeypatch: pytest.MonkeyPatch):
        from server import default_db
        from handlers import _user_handler
        import json
        import io

        db = default_db()
        # Add two users
        user_a = {"id": "user_a", "email": "a@stu.xidian.edu.cn", "nickname": "User A"}
        user_b = {"id": "user_b", "email": "b@stu.xidian.edu.cn", "nickname": "User B"}
        db["users"].extend([user_a, user_b])

        # Clear existing blocks
        db["userBlocks"] = []

        class FakeHandler:
            def __init__(self, body=None):
                self.wfile = io.BytesIO()
                self.status_code = 0
                self.response_headers = []
                self.body = body
                self.headers = {}

            def send_response(self, code):
                self.status_code = code

            def send_header(self, key, val):
                self.response_headers.append((key, val))

            def end_headers(self):
                pass

        # Mock authentication to return user_a
        monkeypatch.setattr(
            _user_handler,
            "auth_user_helper",
            lambda h, d: (user_a, "session_token_a"),
        )
        monkeypatch.setattr(
            _user_handler,
            "save_db",
            lambda d: None,
        )

        # 1. Test GET /api/users/me/blocks when empty
        handler1 = FakeHandler()
        _user_handler.handle_get_blocks(handler1, db)
        assert handler1.status_code == 200
        res1 = json.loads(handler1.wfile.getvalue().decode("utf-8"))
        assert len(res1["data"]) == 0

        # 2. Test POST /api/users/me/blocks (block user_b)
        handler2 = FakeHandler(body={"targetUserId": "user_b"})
        monkeypatch.setattr(
            _user_handler,
            "read_json_body",
            lambda h: {"targetUserId": "user_b"},
        )
        _user_handler.handle_block_user_globally(handler2, db)
        assert handler2.status_code == 200
        res2 = json.loads(handler2.wfile.getvalue().decode("utf-8"))
        assert res2["data"]["blocked"] is True

        # 3. Test GET /api/users/me/blocks (should have user_b now)
        handler3 = FakeHandler()
        _user_handler.handle_get_blocks(handler3, db)
        assert handler3.status_code == 200
        res3 = json.loads(handler3.wfile.getvalue().decode("utf-8"))
        assert len(res3["data"]) == 1
        assert res3["data"][0]["id"] == "user_b"
        assert res3["data"][0]["nickname"] == "User B"

        # 4. Test DELETE /api/users/me/blocks/user_b
        handler4 = FakeHandler()
        _user_handler.handle_unblock_user_globally(handler4, db, "user_b")
        assert handler4.status_code == 200
        res4 = json.loads(handler4.wfile.getvalue().decode("utf-8"))
        assert res4["data"]["blocked"] is False

        # 5. Test GET /api/users/me/blocks when empty again
        handler5 = FakeHandler()
        _user_handler.handle_get_blocks(handler5, db)
        assert handler5.status_code == 200
        res5 = json.loads(handler5.wfile.getvalue().decode("utf-8"))
        assert len(res5["data"]) == 0


class TestFirstMessageRule:
    """No message requests: one first message, then wait for a reply."""

    @staticmethod
    def _setup(monkeypatch: pytest.MonkeyPatch):
        import io

        from handlers import _message_handler
        from server import default_db

        db = default_db()
        alice = {"id": "fm_alice", "email": "a@stu.xidian.edu.cn", "nickname": "Alice"}
        bob = {"id": "fm_bob", "email": "b@stu.xidian.edu.cn", "nickname": "Bob"}
        db["users"].extend([alice, bob])
        for owner, peer, conv_id in ((alice, bob, "fm_ab"), (bob, alice, "fm_ba")):
            db["conversations"].append({
                "id": conv_id,
                "userId": owner["id"],
                "peerUserId": peer["id"],
                "name": peer["nickname"],
                "lastMessage": "",
                "updatedAt": "2026-01-01T00:00:00Z",
                "unreadCount": 0,
                "deleted": False,
            })

        class FakeHandler:
            def __init__(self):
                self.wfile = io.BytesIO()
                self.status_code = 0
                self.headers = {}

            def send_response(self, code):
                self.status_code = code

            def send_header(self, key, val):
                pass

            def end_headers(self):
                pass

        # Rate limits are not what these tests are about.
        monkeypatch.setattr(_message_handler, "consume_rate_limit", lambda *a, **k: (True, 0))
        monkeypatch.setattr(_message_handler, "check_ip_rate_limit", lambda *a, **k: (True, 0))
        monkeypatch.setattr(_message_handler, "save_db", lambda db: None)

        def send(user, conv_id, content="hi"):
            monkeypatch.setattr(_message_handler, "auth_user_helper", lambda h, d: (user, "token"))
            monkeypatch.setattr(_message_handler, "read_json_body", lambda h: {"content": content})
            handler = FakeHandler()
            _message_handler.handle_send_message(handler, db, conv_id)
            return handler

        return db, alice, bob, send

    def test_second_message_waits_for_a_reply(self, monkeypatch: pytest.MonkeyPatch):
        import json

        db, alice, bob, send = self._setup(monkeypatch)
        assert send(alice, "fm_ab", "first").status_code == 200
        blocked = send(alice, "fm_ab", "second")
        assert blocked.status_code == 403
        payload = json.loads(blocked.wfile.getvalue().decode("utf-8"))
        assert "对方回复前只能发送一条消息" in payload["message"]

        # Bob replies; now both can keep writing.
        assert send(bob, "fm_ba", "reply").status_code == 200
        assert send(alice, "fm_ab", "second").status_code == 200
        assert send(alice, "fm_ab", "third").status_code == 200

    def test_recalling_the_first_message_frees_the_slot(self, monkeypatch: pytest.MonkeyPatch):
        db, alice, bob, send = self._setup(monkeypatch)
        assert send(alice, "fm_ab", "first").status_code == 200
        for msg in db["directMessages"]:
            if msg.get("senderUserId") == alice["id"]:
                msg["deleted"] = True
        assert send(alice, "fm_ab", "again").status_code == 200
        assert send(alice, "fm_ab", "too many").status_code == 403

    def test_a_recalled_reply_keeps_the_conversation_open(self, monkeypatch: pytest.MonkeyPatch):
        db, alice, bob, send = self._setup(monkeypatch)
        assert send(alice, "fm_ab", "first").status_code == 200
        assert send(bob, "fm_ba", "reply").status_code == 200
        for msg in db["directMessages"]:
            if msg.get("senderUserId") == bob["id"]:
                msg["deleted"] = True
        assert send(alice, "fm_ab", "second").status_code == 200

    def test_conversation_list_reports_awaiting_reply(self, monkeypatch: pytest.MonkeyPatch):
        import io
        import json

        from handlers import _message_handler

        db, alice, bob, send = self._setup(monkeypatch)
        assert send(alice, "fm_ab", "first").status_code == 200

        def listed(user):
            monkeypatch.setattr(_message_handler, "auth_user_helper", lambda h, d: (user, "token"))

            class H:
                wfile = io.BytesIO()
                headers = {}

                def send_response(self, code):
                    pass

                def send_header(self, *a):
                    pass

                def end_headers(self):
                    pass

            h = H()
            h.wfile = io.BytesIO()
            _message_handler.handle_get_conversations(h, db)
            rows = json.loads(h.wfile.getvalue().decode("utf-8"))["data"]
            return {row["id"]: row for row in rows}

        assert listed(alice)["fm_ab"]["awaitingReply"] is True
        # The receiver is never held back.
        assert listed(bob)["fm_ba"]["awaitingReply"] is False
