import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import check


class AttemptTests(unittest.TestCase):
    def test_cli_retries_preserve_current_counter_and_reject_changed_inputs(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "o--r-1.json"
            base = [
                "check.py",
                "attempt",
                "--repo",
                "o/r",
                "--pr",
                "1",
                "--state-dir",
                directory,
                "--problem",
                "ci:test",
            ]

            def invoke(attempt_id, outcome, reason="result"):
                argv = base + [
                    "--attempt-id",
                    attempt_id,
                    "--outcome",
                    outcome,
                    "--reason",
                    reason,
                ]
                with patch.object(sys, "argv", argv), patch("builtins.print") as output:
                    self.assertEqual(0, check.main())
                    return json.loads(output.call_args.args[0])

            for count in range(1, 4):
                expected = {
                    "status": "hold" if count == 3 else "continue",
                    "failures": count,
                }
                self.assertEqual(expected, invoke(str(count), "failed"))
                saved = path.read_bytes()
                self.assertEqual(expected, invoke(str(count), "failed"))
                self.assertEqual(saved, path.read_bytes())
            self.assertEqual(
                {"status": "continue", "failures": 0}, invoke("success", "succeeded")
            )
            self.assertEqual(0, invoke("1", "failed")["failures"])
            self.assertEqual(1, invoke("4", "failed")["failures"])
            self.assertEqual(1, invoke("success", "succeeded")["failures"])
            self.assertEqual(0, invoke("reset", "reset")["failures"])
            self.assertEqual(1, invoke("5", "failed")["failures"])
            self.assertEqual(1, invoke("reset", "reset")["failures"])
            saved = path.read_bytes()
            for outcome, reason in [("succeeded", "result"), ("failed", "changed")]:
                with (
                    self.subTest(outcome=outcome, reason=reason),
                    patch("sys.stderr"),
                    self.assertRaises(SystemExit) as error,
                ):
                    invoke("5", outcome, reason)
                self.assertEqual(2, error.exception.code)
                self.assertEqual(saved, path.read_bytes())
            argv = base + ["--outcome", "failed", "--reason", "result"]
            with (
                patch.object(sys, "argv", argv),
                patch("sys.stderr"),
                self.assertRaises(SystemExit),
            ):
                check.main()
            self.assertEqual(saved, path.read_bytes())

    def test_existing_counter_and_problem_scoped_ids(self):
        state = {"attempts": {"old": {"failures": 2, "reason": "legacy"}}}
        self.assertEqual(
            {"status": "hold", "failures": 3},
            check.record_attempt(state, "old", "1", "failed", "result"),
        )
        self.assertEqual(
            {"status": "continue", "failures": 1},
            check.record_attempt(state, "other", "1", "failed", "result"),
        )
        self.assertEqual(3, state["attempts"]["old"]["failures"])


if __name__ == "__main__":
    unittest.main()
