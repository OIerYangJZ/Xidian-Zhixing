from __future__ import annotations

import json
import unittest
from pathlib import Path

from agent_harness.ui import validate_ui


class UIProtocolTests(unittest.TestCase):
    def test_shared_protocol_fixtures(self):
        fixtures = json.loads((Path(__file__).resolve().parents[2] / 'tests/fixtures/ai-ui.json').read_text(encoding='utf-8'))
        for case in fixtures['cases']:
            with self.subTest(case['name']):
                ui, errors = validate_ui(case['value'], fixtures['sources'], {'ehall', 'campus-network-usage'})
                self.assertEqual(len(ui.cards) if ui else 0, case['cards'])
                self.assertEqual(errors, case['errors'])

