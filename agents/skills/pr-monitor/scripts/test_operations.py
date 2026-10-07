import copy
import json
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

import check
import worktree_cleanup
from test_check import snapshot, thread


class OperationTests(unittest.TestCase):
    def test_standalone_review_response_loss_and_retry(self):
        for operation in ("reply", "resolve"):
            with (
                self.subTest(operation=operation),
                tempfile.TemporaryDirectory() as directory,
            ):
                data = snapshot()
                data["reviewThreads"] = [thread()]
                state = check.update({}, data)
                event_id = next(iter(state["pending"]))
                path = Path(directory) / "state.json"
                live = thread()
                live["pullRequest"] = {
                    "number": 1,
                    "headRefOid": "abc",
                    "repository": {"nameWithOwner": "o/r"},
                }
                calls = []

                def mutate(
                    query, live=live, calls=calls, operation=operation, **variables
                ):
                    calls.append(operation)
                    if operation == "reply":
                        live["comments"].append(
                            {
                                "id": "reply",
                                "url": "url",
                                "body": variables["body"],
                                "author": {"login": "me"},
                            }
                        )
                    else:
                        live["isResolved"] = True
                    raise RuntimeError("Response lost")

                with (
                    patch.object(
                        check,
                        "read_review_thread",
                        side_effect=lambda _, live=live: (copy.deepcopy(live), "me"),
                    ),
                    patch.object(check, "graphql", side_effect=mutate),
                ):
                    with self.assertRaises(RuntimeError):
                        check.review_operation(
                            state,
                            path,
                            event_id,
                            "Fixed" if operation == "reply" else "",
                            "",
                            "o/r",
                            1,
                            operation,
                        )
                    result = check.review_operation(
                        json.loads(path.read_text()),
                        path,
                        event_id,
                        "Fixed" if operation == "reply" else "",
                        "",
                        "o/r",
                        1,
                        operation,
                    )
                self.assertEqual("completed", result["status"])
                self.assertEqual([operation], calls)
                self.assertIn(event_id, json.loads(path.read_text())["pending"])

    def test_merge_preview_blocking_head_guard_and_success_recovery(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            state = check.update({}, snapshot())
            with (
                patch.object(check, "collect", return_value=snapshot()),
                patch.object(check, "graphql") as mutation,
            ):
                result = check.merge_pr(
                    state, path, "o/r", 1, "squash", None, False, None
                )
                self.assertEqual("eligible", result["status"])
                with self.assertRaises(RuntimeError):
                    check.merge_pr(
                        state, path, "o/r", 1, "squash", "old", True, "authorized"
                    )
                mutation.assert_not_called()
            blocked = snapshot()
            blocked["reactions"] = [{"content": "EYES", "users": {"totalCount": 1}}]
            with (
                patch.object(check, "collect", return_value=blocked),
                patch.object(check, "graphql") as mutation,
            ):
                result = check.merge_pr(
                    state, path, "o/r", 1, "squash", "abc", True, "authorized"
                )
                self.assertEqual("blocked", result["status"])
                mutation.assert_not_called()
            merged = snapshot()
            merged["pr"]["state"] = "MERGED"
            with (
                patch.object(
                    check, "collect", side_effect=[snapshot(), merged, merged]
                ),
                patch.object(
                    check, "graphql", side_effect=RuntimeError("Response lost")
                ) as mutation,
            ):
                result = check.merge_pr(
                    state, path, "o/r", 1, "squash", "abc", True, "authorized"
                )
                self.assertEqual("merged", result["status"])
                self.assertEqual("abc", mutation.call_args.kwargs["head"])
                self.assertEqual("SQUASH", mutation.call_args.kwargs["method"])
                repeated = check.merge_pr(
                    json.loads(path.read_text()),
                    path,
                    "o/r",
                    1,
                    "squash",
                    "abc",
                    True,
                    "authorized",
                )
                self.assertTrue(repeated["alreadyMerged"])
                self.assertEqual(1, mutation.call_count)

    def test_merge_refresh_does_not_ignore_new_comments(self):
        data = snapshot()
        data["comments"] = [{"id": "new", "updatedAt": "now", "body": "please fix"}]
        with (
            tempfile.TemporaryDirectory() as directory,
            patch.object(check, "collect", return_value=data),
            patch.object(check, "graphql") as mutation,
        ):
            state = check.update({}, snapshot())
            result = check.merge_pr(
                state,
                Path(directory) / "state.json",
                "o/r",
                1,
                "merge",
                "abc",
                True,
                "authorized",
            )
            self.assertIn("pending_comment", result["blockingReasons"])
            mutation.assert_not_called()

    def test_notification_uncertainty_persists_across_checks_and_pr_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            data = snapshot()
            data["pr"]["state"] = "MERGED"
            state = check.update({}, data)
            actions = check.plan_actions(state, monitor_status="PAUSED")
            notify = next(action for action in actions if action["type"] == "notify")
            state["plannedActions"] = {action["id"]: action for action in actions}
            result = check.prepare_notification(state, path, notify["id"])
            self.assertEqual("dispatch", result["status"])
            state = json.loads(path.read_text())
            self.assertEqual(
                "delivery_unknown",
                check.prepare_notification(state, path, notify["id"])["status"],
            )
            state = check.update(state, data)
            self.assertEqual(
                "reconcile_notification", check.plan_actions(state, monitor_status="PAUSED")[0]["type"]
            )
            self.assertEqual(notify["id"], check.plan_actions(state, monitor_status="PAUSED")[0]["id"])
            data["pr"]["headRefOid"] = "different"
            state = check.update(state, data)
            self.assertEqual(notify["id"], check.plan_actions(state, monitor_status="PAUSED")[0]["id"])
            check.record_notification(
                state, path, notify["id"], "unknown", "no delivery evidence"
            )
            self.assertEqual(
                "delivery_unknown",
                check.prepare_notification(state, path, notify["id"])["status"],
            )
            check.record_notification(
                state,
                path,
                notify["id"],
                "not_sent",
                "confirmed absent from destination",
            )
            self.assertEqual(
                "dispatch",
                check.prepare_notification(state, path, notify["id"])["status"],
            )
            check.record_notification(
                state, path, notify["id"], "succeeded", "destination message id"
            )
            self.assertEqual(
                "completed",
                check.prepare_notification(state, path, notify["id"])["status"],
            )
            self.assertFalse(
                any(
                    action["id"] == notify["id"] for action in check.plan_actions(state, monitor_status="PAUSED")
                )
            )
            with self.assertRaises(RuntimeError):
                check.record_notification(
                    state, path, notify["id"], "not_sent", "reset"
                )

    def test_notification_success_acks_only_its_event(self):
        data = snapshot()
        state = check.update({}, data)
        state["pending"] = {
            "event": {"id": "event", "kind": "codex_passed", "head": "abc"}
        }
        actions = check.plan_actions(state, current_interval=1)
        notify = next(action for action in actions if action["type"] == "notify")
        state["plannedActions"] = {action["id"]: action for action in actions}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "state.json"
            check.prepare_notification(state, path, notify["id"])
            self.assertIn("event", state["pending"])
            check.record_notification(
                state, path, notify["id"], "succeeded", "message-id"
            )
            self.assertNotIn("event", state["pending"])
            self.assertEqual("message-id", state["acknowledged"]["event"])

    def test_cleanup_state_preserves_unconfirmed_notifications_and_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "o--r-1.json"
            state = check.update({}, snapshot())
            state["pending"] = {}
            state["notificationDeliveries"] = {"action": {"status": "started"}}
            check.save(path, state)
            argv = [
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
            with (
                patch.object(sys, "argv", argv),
                patch.object(check, "gh") as api,
                patch("builtins.print") as output,
            ):
                self.assertEqual(0, check.main())
                self.assertEqual(
                    "notification_delivery_unknown",
                    json.loads(output.call_args.args[0])["reason"],
                )
                api.assert_not_called()
            self.assertTrue(path.exists())
            state["notificationDeliveries"] = {}
            state["worktreeCleanups"] = {"path": {"completed": False}}
            check.save(path, state)
            with patch.object(sys, "argv", argv), patch("builtins.print") as output:
                self.assertEqual(0, check.main())
                self.assertEqual(
                    "worktree_cleanup_incomplete",
                    json.loads(output.call_args.args[0])["reason"],
                )
            self.assertTrue(path.exists())

    def test_ack_replay_and_missing_notification_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "o--r-1.json"
            state = {"pending": {"event": {"kind": "comment"}}, "acknowledged": {}}
            check.save(path, state)
            argv = [
                "check.py",
                "ack",
                "--repo",
                "o/r",
                "--pr",
                "1",
                "--state-dir",
                directory,
                "--event",
                "event",
                "--reason",
                "handled",
            ]
            with patch.object(sys, "argv", argv), patch("builtins.print"):
                self.assertEqual(0, check.main())
                self.assertEqual(0, check.main())
            self.assertEqual(
                "handled", json.loads(path.read_text())["acknowledged"]["event"]
            )
            with self.assertRaises(RuntimeError):
                check.record_notification(
                    state, path, "unknown-action", "succeeded", "guess"
                )


class CleanupTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.repository = self.root / "repository"
        self.repository.mkdir()
        worktree_cleanup.git(self.repository, "init", "--initial-branch=main")
        worktree_cleanup.git(self.repository, "config", "user.name", "Test")
        worktree_cleanup.git(
            self.repository, "config", "user.email", "test@example.com"
        )
        worktree_cleanup.git(
            self.repository, "commit", "--allow-empty", "-m", "Initial"
        )
        worktree_cleanup.git(
            self.repository, "remote", "add", "origin", "https://github.com/o/r.git"
        )
        self.worktree = self.root / "worktree"
        self.branch = "codex/example"
        worktree_cleanup.git(
            self.repository, "worktree", "add", "-b", self.branch, str(self.worktree)
        )
        worktree_cleanup.git(self.worktree, "commit", "--allow-empty", "-m", "PR")
        self.head = worktree_cleanup.git(self.worktree, "rev-parse", "HEAD")
        self.ownership = self.root / "ownership.json"
        self.evidence = {
            "worktree": str(self.worktree),
            "observedAt": datetime.now(timezone.utc).isoformat(),
            "shared": False,
            "pinned": False,
            "inUse": False,
            "managed": False,
        }
        self.write_evidence()
        self.state = {}
        self.state_path = self.root / "state.json"
        self.pr = {
            "state": "MERGED",
            "headRefOid": self.head,
            "headRefName": self.branch,
        }
        self.processes = patch.object(
            worktree_cleanup, "process_blockers", return_value=[]
        )
        self.processes.start()
        self.addCleanup(self.processes.stop)

    def write_evidence(self):
        self.ownership.write_text(json.dumps(self.evidence))

    def cleanup(self, apply=True):
        return worktree_cleanup.cleanup_worktree(
            self.state,
            self.state_path,
            "o/r",
            1,
            self.repository,
            self.worktree,
            self.branch,
            self.ownership,
            apply,
            lambda *args: self.pr,
            check.save,
        )

    def test_preview_cleanup_and_repeat(self):
        self.assertEqual("eligible", self.cleanup(False)["status"])
        self.assertTrue(self.worktree.exists())
        self.assertEqual("completed", self.cleanup()["status"])
        self.assertFalse(self.worktree.exists())
        self.assertEqual(
            "",
            worktree_cleanup.git(
                self.repository,
                "for-each-ref",
                "--format=%(objectname)",
                "refs/heads/" + self.branch,
            ),
        )
        self.assertEqual("completed", self.cleanup()["status"])

    def test_cleanup_recovers_after_removal_response_loss(self):
        original_git = worktree_cleanup.git

        def fail_after_removal(repository, *args):
            result = original_git(repository, *args)
            if args[:2] == ("worktree", "remove"):
                raise RuntimeError("Interrupted after removal")
            return result

        with (
            patch.object(worktree_cleanup, "git", side_effect=fail_after_removal),
            self.assertRaises(RuntimeError),
        ):
            self.cleanup()
        self.state = json.loads(self.state_path.read_text())
        self.assertFalse(self.worktree.exists())
        self.assertEqual("completed", self.cleanup()["status"])

    def test_dirty_ignored_and_protected_worktrees_are_preserved(self):
        (self.worktree / "untracked").write_text("keep")
        self.assertIn("local_files_present", self.cleanup()["blockingReasons"])
        (self.worktree / "untracked").unlink()
        worktree_cleanup.git(
            self.worktree, "config", "core.excludesFile", str(self.root / "ignore")
        )
        (self.root / "ignore").write_text("ignored\n")
        (self.worktree / "ignored").write_text("keep ignored data")
        self.assertIn("local_files_present", self.cleanup()["blockingReasons"])
        (self.worktree / "ignored").unlink()
        self.evidence["shared"] = True
        self.write_evidence()
        self.assertIn("worktree_shared", self.cleanup()["blockingReasons"])
        self.evidence["shared"] = False
        self.evidence["observedAt"] = (
            datetime.now(timezone.utc) - timedelta(seconds=61)
        ).isoformat()
        self.write_evidence()
        self.assertIn("ownership_evidence_stale", self.cleanup()["blockingReasons"])
        self.assertTrue(self.worktree.exists())

    def test_managed_archive_handoff_and_confirmation(self):
        self.evidence["managed"] = True
        self.write_evidence()
        result = self.cleanup()
        self.assertEqual("archive_required", result["status"])
        self.assertTrue(self.worktree.exists())
        worktree_cleanup.git(self.repository, "worktree", "remove", str(self.worktree))
        self.assertEqual("completed", self.cleanup()["status"])

    def test_unmerged_head_changes_and_active_processes_block_cleanup(self):
        self.pr["state"] = "OPEN"
        self.assertIn("pr_not_merged", self.cleanup()["blockingReasons"])
        self.pr["state"] = "MERGED"
        with patch.object(
            worktree_cleanup, "process_blockers", return_value=["active_processes"]
        ):
            self.assertIn("active_processes", self.cleanup()["blockingReasons"])
        worktree_cleanup.git(
            self.worktree, "commit", "--allow-empty", "-m", "Unpushed work"
        )
        reasons = self.cleanup()["blockingReasons"]
        self.assertIn("worktree_head_changed", reasons)
        self.assertIn("branch_head_changed", reasons)
        self.assertTrue(self.worktree.exists())

    def test_locked_and_ownership_unknown_worktrees_are_preserved(self):
        worktree_cleanup.git(self.repository, "worktree", "lock", str(self.worktree))
        self.assertIn("locked_or_prunable", self.cleanup()["blockingReasons"])
        worktree_cleanup.git(self.repository, "worktree", "unlock", str(self.worktree))
        self.ownership = None
        self.assertIn("ownership_unknown", self.cleanup()["blockingReasons"])
        self.assertTrue(self.worktree.exists())

    def test_branch_deletion_uses_compare_and_swap(self):
        original_git = worktree_cleanup.git
        raced_head = None

        def race(repository, *args):
            nonlocal raced_head
            if args[:2] == ("update-ref", "-d"):
                tree = original_git(repository, "rev-parse", "HEAD^{tree}")
                raced_head = original_git(
                    repository,
                    "commit-tree",
                    tree,
                    "-p",
                    self.head,
                    "-m",
                    "Concurrent commit",
                )
                original_git(
                    repository, "update-ref", "refs/heads/" + self.branch, raced_head
                )
            return original_git(repository, *args)

        with (
            patch.object(worktree_cleanup, "git", side_effect=race),
            self.assertRaises(RuntimeError),
        ):
            self.cleanup()
        self.assertFalse(self.worktree.exists())
        self.assertEqual(
            raced_head, original_git(self.repository, "rev-parse", self.branch)
        )
        self.assertIn("branch_head_changed", self.cleanup()["blockingReasons"])

    def test_recreated_targets_are_not_deleted(self):
        self.cleanup()
        worktree_cleanup.git(self.repository, "branch", self.branch, self.head)
        self.assertIn("cleanup_target_recreated", self.cleanup()["blockingReasons"])
        self.assertEqual(
            self.head, worktree_cleanup.git(self.repository, "rev-parse", self.branch)
        )


if __name__ == "__main__":
    unittest.main()
