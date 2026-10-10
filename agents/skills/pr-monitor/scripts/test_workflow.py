import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import check
import workflow
from test_check import snapshot, thread


def planned(data=None, **options):
    state = check.update({}, data or snapshot())
    state["plannedActions"] = {
        action["id"]: action for action in check.plan_actions(state, **options)
    }
    return state


def command(name, *arguments):
    return [name, *arguments]


class WorkflowTests(unittest.TestCase):
    def test_failed_title_does_not_block_reviews_and_retries_on_check(self):
        data = snapshot()
        data["prReactions"] = [
            {"id": 1, "content": "+1", "user": {"login": "chatgpt-codex-connector"}}
        ]
        data["reviewThreads"] = [thread()]
        state = planned(data, current_interval=1)
        state["executionMode"] = "direct"
        action = workflow.next_step(state, command)["action"]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "o--r-1.json"
            check.save(path, state)
            base = ["check.py", "--repo", "o/r", "--pr", "1", "--state-dir", directory]
            args = base + [
                "defer-title",
                "--action",
                action["id"],
                "--reason",
                "tool unavailable",
            ]
            for _ in range(2):
                with patch.object(sys, "argv", args), patch("builtins.print") as output:
                    self.assertEqual(0, check.main())
                    result = json.loads(output.call_args.args[0])
                self.assertEqual("handle_event", result["action"]["type"])
            state = json.loads(path.read_text())
            self.assertNotIn(action["id"], state["completedActions"])
            self.assertEqual("tool unavailable", state["deferredTitles"][action["id"]])
            with (
                patch.object(sys, "argv", base + ["check"]),
                patch.object(check, "collect", return_value=data),
                patch("builtins.print") as output,
            ):
                self.assertEqual(0, check.main())
                result = json.loads(output.call_args.args[0])
            self.assertEqual("set_title", result["nextStep"]["action"]["type"])
            self.assertTrue(result["nextStep"]["optional"])

    def test_new_check_retries_previously_skipped_title(self):
        data = snapshot()
        data["prReactions"] = [
            {"id": 1, "content": "+1", "user": {"login": "chatgpt-codex-connector"}}
        ]
        state = planned(data, current_interval=1)
        action = next(
            a for a in state["plannedActions"].values() if a["type"] == "set_title"
        )
        state["completedActions"][action["id"]] = "title tool unavailable; skipped"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "o--r-1.json"
            check.save(path, state)
            args = [
                "check.py",
                "check",
                "--repo",
                "o/r",
                "--pr",
                "1",
                "--state-dir",
                directory,
            ]
            with (
                patch.object(sys, "argv", args),
                patch.object(check, "collect", return_value=data),
                patch("builtins.print") as output,
            ):
                self.assertEqual(0, check.main())
                result = json.loads(output.call_args.args[0])
            self.assertEqual("set_title", result["nextStep"]["action"]["type"])
            self.assertEqual("set_thread_title", result["nextStep"]["operation"])
            self.assertNotIn(
                action["id"], json.loads(path.read_text())["completedActions"]
            )

    def test_completion_retry_preserves_saved_result_and_advances(self):
        state = planned()
        action = workflow.next_step(state, command)["action"]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "o--r-1.json"
            check.save(path, state)
            args = [
                "check.py",
                "complete",
                "--repo",
                "o/r",
                "--pr",
                "1",
                "--state-dir",
                directory,
                "--action",
                action["id"],
                "--reason",
                "verified interval",
            ]
            with patch.object(sys, "argv", args), patch("builtins.print"):
                self.assertEqual(0, check.main())
                saved = path.read_text()
                self.assertEqual(0, check.main())
            self.assertEqual(saved, path.read_text())
            state = json.loads(saved)
            self.assertEqual(1, state["checkOptions"]["--current-interval"])
            self.assertEqual(
                "continue_required", workflow.next_step(state, command)["status"]
            )

    def test_fetch_failure_blocks_stale_plan(self):
        state = planned()
        state["lastError"] = "API down"
        self.assertEqual("check_required", workflow.next_step(state, command)["status"])
        with self.assertRaises(RuntimeError):
            workflow.require_turn(state, next(iter(state["plannedActions"])))

    def test_default_continues_and_once_finishes(self):
        state = planned(current_interval=1)
        result = workflow.next_step(state, command)
        self.assertEqual("continue_required", result["status"])
        self.assertFalse(result["canEndTurn"])
        state["once"] = True
        state["plannedActions"] = {a["id"]: a for a in check.plan_actions(state)}
        self.assertEqual("finished", workflow.next_step(state, command)["status"])

    def test_direct_mode_keeps_waiting_after_multiple_unchanged_checks(self):
        state = planned()
        state["executionMode"] = "direct"
        for _ in range(3):
            state = check.update(state, snapshot())
            state["plannedActions"] = {a["id"]: a for a in check.plan_actions(state)}
            result = workflow.next_step(state, command)
            self.assertEqual("continue_required", result["status"])
            self.assertFalse(result["canEndTurn"])
            self.assertEqual(60, result["waitSeconds"])
            self.assertEqual(["check"], result["command"])

    def test_paused_finishes_without_restarting(self):
        state = planned(current_interval=1)
        state["monitorStatus"] = "PAUSED"
        self.assertEqual("finished", workflow.next_step(state, command)["status"])

    def test_completed_steps_and_acked_events_advance_without_recheck(self):
        data = snapshot()
        data["reviewThreads"] = [thread()]
        state = planned(data)
        first = workflow.next_step(state, command)["action"]
        self.assertEqual("set_interval", first["type"])
        state["completedActions"][first["id"]] = "verified interval"
        result = workflow.next_step(state, command)
        self.assertEqual("thread", result["event"]["kind"])
        self.assertEqual("finish-review", result["resolvedCompletion"][0])
        state["pending"].pop(result["event"]["id"])
        self.assertEqual(
            "continue_required", workflow.next_step(state, command)["status"]
        )

    def test_terminal_order_and_unknown_delivery_block_cleanup(self):
        data = snapshot()
        data["pr"]["state"] = "MERGED"
        state = planned(data, title="Chat")
        actions = list(state["plannedActions"].values())
        self.assertEqual(
            [
                "pause_monitor",
                "cleanup_worktree",
                "notify",
                "delete_monitor",
                "cleanup_state",
            ],
            [a["type"] for a in actions],
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            notify = actions[2]
            with self.assertRaises(RuntimeError):
                check.prepare_notification(state, path, notify["id"])
            self.assertFalse(path.exists())
            for action in actions[:2]:
                state["completedActions"][action["id"]] = "verified"
            self.assertEqual(
                "dispatch",
                check.prepare_notification(state, path, notify["id"])["status"],
            )
            self.assertEqual(
                "reconcile_notification",
                workflow.next_step(state, command)["action"]["type"],
            )
            with self.assertRaises(RuntimeError):
                workflow.require_type(state, "cleanup_state")
            self.assertEqual(
                "delivery_unknown",
                check.prepare_notification(state, path, notify["id"])["status"],
            )
            check.record_notification(
                state, path, notify["id"], "succeeded", "message id"
            )
            self.assertEqual(
                "delete_monitor", workflow.next_step(state, command)["action"]["type"]
            )

    def test_cli_next_preserves_check_options(self):
        with tempfile.TemporaryDirectory() as directory:
            state = planned(current_interval=1)
            state["checkOptions"] = {
                "--interval-minutes": 3,
                "--current-interval": 3,
                "--monitor-status": "ACTIVE",
                "--execution-mode": "direct",
            }
            path = Path(directory) / "o--r-1.json"
            check.save(path, state)
            args = [
                "check.py",
                "next",
                "--repo",
                "o/r",
                "--pr",
                "1",
                "--state-dir",
                directory,
            ]
            for _ in range(2):
                with patch.object(sys, "argv", args), patch("builtins.print") as output:
                    self.assertEqual(0, check.main())
                    result = json.loads(output.call_args.args[0])
                self.assertEqual("continue_required", result["status"])
                self.assertIn("--interval-minutes", result["command"])
                self.assertIn("--execution-mode", result["command"])
            self.assertEqual(state, json.loads(path.read_text()))

    def test_wait_time_tracks_phase_and_override(self):
        from datetime import datetime, timedelta, timezone

        now = datetime.now(timezone.utc)
        for draft, approval_age, override, expected in (
            (False, None, None, 60),
            (True, None, None, 300),
            (False, 599, None, 60),
            (False, 600, None, 1200),
            (True, 600, 2, 120),
        ):
            with self.subTest(
                draft=draft, approval_age=approval_age, override=override
            ):
                data = snapshot()
                data["pr"]["isDraft"] = draft
                state = planned(data)
                state["executionMode"] = "direct"
                if approval_age is not None:
                    state["codexPassedHead"] = "abc"
                    state["codexPassedAt"] = (
                        now - timedelta(seconds=approval_age)
                    ).isoformat()
                state = check.update(state, data, now=now, interval_minutes=override)
                # This case exercises timing after event handling has completed.
                state["pending"] = {}
                state["plannedActions"] = {
                    a["id"]: a for a in check.plan_actions(state)
                }
                self.assertEqual(
                    expected, workflow.next_step(state, command)["waitSeconds"]
                )

    def test_state_cleanup_returns_terminal_step_including_retry(self):
        data = snapshot()
        data["pr"]["state"] = "CLOSED"
        state = planned(data, monitor_status="PAUSED")
        for action in state["plannedActions"].values():
            if action["type"] != "cleanup_state":
                state["completedActions"][action["id"]] = "verified"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "o--r-1.json"
            check.save(path, state)
            args = [
                "check.py",
                "cleanup",
                "--repo",
                "o/r",
                "--pr",
                "1",
                "--state-dir",
                directory,
                "--apply",
            ]
            for expected in ("deleted", "absent"):
                with (
                    patch.object(sys, "argv", args),
                    patch.object(check, "gh", return_value={"state": "CLOSED"}),
                    patch("builtins.print") as output,
                ):
                    self.assertEqual(0, check.main())
                    result = json.loads(output.call_args.args[0])
                self.assertEqual(expected, result["status"])
                self.assertEqual(
                    {"status": "finished", "canEndTurn": True}, result["nextStep"]
                )
                self.assertFalse(path.exists())

    def test_cli_rejects_out_of_order_completion_and_state_deletion(self):
        data = snapshot()
        data["pr"]["state"] = "MERGED"
        state = planned(data)
        actions = list(state["plannedActions"].values())
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "o--r-1.json"
            check.save(path, state)
            original = path.read_text()
            base = ["check.py", "--repo", "o/r", "--pr", "1", "--state-dir", directory]
            with (
                patch.object(
                    sys,
                    "argv",
                    base
                    + ["complete", "--action", actions[3]["id"], "--reason", "done"],
                ),
                patch("builtins.print"),
            ):
                self.assertEqual(1, check.main())
            with (
                patch.object(sys, "argv", base + ["cleanup", "--apply"]),
                patch.object(check, "gh") as api,
                patch("builtins.print"),
            ):
                self.assertEqual(0, check.main())
                api.assert_not_called()
            self.assertEqual(original, path.read_text())


if __name__ == "__main__":
    unittest.main()
