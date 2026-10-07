import copy
import json
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

import check


def snapshot():
    return {
        "pr": {
            "id": "PR1",
            "state": "OPEN",
            "mergedAt": None,
            "isDraft": False,
            "headRefOid": "abc",
            "baseRefOid": "base",
            "mergeable": "MERGEABLE",
            "mergeStateStatus": "CLEAN",
            "url": "https://github.com/o/r/pull/1",
            "statusCheckRollup": [],
        },
        "comments": [],
        "reviews": [],
        "reviewThreads": [],
        "reactions": [],
    }


def thread():
    return {
        "id": "thread1",
        "isResolved": False,
        "path": "a.py",
        "line": 1,
        "comments": [
            {
                "id": "c1",
                "updatedAt": "now",
                "body": "fix it",
                "author": {"login": "reviewer"},
                "reactionGroups": [],
            }
        ],
    }


class MonitorTests(unittest.TestCase):
    def test_action_receipts_and_attempt_cli(self):
        data = snapshot()
        data["pr"]["state"] = "MERGED"
        state = check.update({}, data)
        actions = check.plan_actions(state, monitor_status="PAUSED")
        state["completedActions"] = {actions[0]["id"]: "done"}
        self.assertEqual(
            ["notify", "delete_monitor", "cleanup_state"],
            [a["type"] for a in check.plan_actions(state, monitor_status="PAUSED")],
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "o--r-1.json"
            state["plannedActions"] = {a["id"]: a for a in actions}
            check.save(path, state)
            check.prepare_notification(state, path, actions[1]["id"])
            base = ["check.py", "--repo", "o/r", "--pr", "1", "--state-dir", directory]
            with (
                patch.object(
                    sys,
                    "argv",
                    base
                    + [
                        "complete",
                        "--action",
                        actions[1]["id"],
                        "--reason",
                        "notified",
                    ],
                ),
                patch("builtins.print"),
            ):
                self.assertEqual(0, check.main())
            self.assertEqual(
                ["delete_monitor", "cleanup_state"],
                [
                    a["type"]
                    for a in check.plan_actions(
                        json.loads(path.read_text()), monitor_status="PAUSED"
                    )
                ],
            )
            for count in range(1, 4):
                with (
                    patch.object(
                        sys,
                        "argv",
                        base
                        + [
                            "attempt",
                            "--problem",
                            "ci:test",
                            "--attempt-id",
                            str(count),
                            "--outcome",
                            "failed",
                            "--reason",
                            "failure",
                        ],
                    ),
                    patch("builtins.print") as output,
                ):
                    self.assertEqual(0, check.main())
                    result = json.loads(output.call_args.args[0])
                    self.assertEqual(count, result["failures"])
                    self.assertEqual(
                        "hold" if count == 3 else "continue", result["status"]
                    )

    def test_review_reply_and_resolve_cli(self):
        with tempfile.TemporaryDirectory() as directory:
            data = snapshot()
            data["reviewThreads"] = [thread()]
            state = check.update({}, data)
            key = next(iter(state["pending"]))
            path = Path(directory) / "o--r-1.json"
            check.save(path, state)
            body = Path(directory) / "reply.txt"
            body.write_text("Fixed.\nTests passed.")
            live = thread()
            live["pullRequest"] = {
                "number": 1,
                "headRefOid": "abc",
                "repository": {"nameWithOwner": "o/r"},
            }
            calls = []

            def mutate(query, **variables):
                if "addPullRequestReviewThreadReply" in query:
                    calls.append("reply")
                    live["comments"].append(
                        {
                            "id": "reply",
                            "url": "url",
                            "body": variables["body"],
                            "author": {"login": "me"},
                        }
                    )
                else:
                    calls.append("resolve")
                    live["isResolved"] = True
                return {}

            base = [
                "check.py",
                "--repo",
                "o/r",
                "--pr",
                "1",
                "--state-dir",
                directory,
                "--event",
                key,
            ]
            with (
                patch.object(
                    check,
                    "read_review_thread",
                    side_effect=lambda _: (copy.deepcopy(live), "me"),
                ),
                patch.object(check, "graphql", side_effect=mutate),
                patch("builtins.print"),
            ):
                for command in [["reply", "--body-file", str(body)]] * 2 + [
                    ["resolve"]
                ] * 2:
                    with patch.object(sys, "argv", base + command):
                        self.assertEqual(0, check.main())
            self.assertEqual(["reply", "resolve"], calls)
            self.assertIn(key, json.loads(path.read_text())["pending"])

    def test_finish_review_recovers_from_remote_success_and_lost_response(self):
        for fail_at in (None, "reply", "resolve"):
            with (
                self.subTest(fail_at=fail_at),
                tempfile.TemporaryDirectory() as directory,
            ):
                data = snapshot()
                data["reviewThreads"] = [thread()]
                state = check.update({}, data)
                event_id = next(iter(state["pending"]))
                path = Path(directory) / "state.json"
                check.save(path, state)
                live = thread()
                live["pullRequest"] = {
                    "number": 1,
                    "headRefOid": "abc",
                    "repository": {"nameWithOwner": "o/r"},
                }
                calls = []

                def mutate(query, live=live, calls=calls, fail_at=fail_at, **variables):
                    operation = (
                        "reply"
                        if "addPullRequestReviewThreadReply" in query
                        else "resolve"
                    )
                    calls.append(operation)
                    if operation == "reply":
                        live["comments"].append(
                            {
                                "id": "reply1",
                                "url": "reply-url",
                                "updatedAt": "later",
                                "body": variables["body"],
                                "author": {"login": "me"},
                            }
                        )
                    else:
                        live["isResolved"] = True
                    if operation == fail_at:
                        raise RuntimeError("Response lost after successful mutation")
                    return {}

                with (
                    patch.object(
                        check,
                        "read_review_thread",
                        side_effect=lambda _, live=live: (copy.deepcopy(live), "me"),
                    ),
                    patch.object(check, "graphql", side_effect=mutate),
                ):
                    if fail_at:
                        with self.assertRaises(RuntimeError):
                            check.finish_review(
                                state, path, event_id, "Fixed", "tested", "o/r", 1
                            )
                        state = json.loads(path.read_text())
                        self.assertIn(event_id, state["pending"])
                        self.assertNotIn(event_id, state["acknowledged"])
                    result = check.finish_review(
                        state, path, event_id, "Fixed", "tested", "o/r", 1
                    )
                    repeated = check.finish_review(
                        json.loads(path.read_text()),
                        path,
                        event_id,
                        "Fixed",
                        "tested",
                        "o/r",
                        1,
                    )
                self.assertEqual(result, repeated)
                self.assertEqual(["reply", "resolve"], calls)
                stored = json.loads(path.read_text())
                self.assertNotIn(event_id, stored["pending"])
                self.assertEqual("tested", stored["acknowledged"][event_id])

    def test_finish_review_blocks_changes_and_unconfirmed_resolution(self):
        for change in (
            "head",
            "comment",
            "extra_comment",
            "wrong_pr",
            "resolve_failure",
            "reopened",
        ):
            with (
                self.subTest(change=change),
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
                if change == "head":
                    live["pullRequest"]["headRefOid"] = "new"
                elif change == "comment":
                    live["comments"][0]["body"] = "edited"
                elif change == "extra_comment":
                    live["comments"].append({"id": "new", "body": "another issue"})
                elif change == "wrong_pr":
                    live["pullRequest"]["number"] = 2

                def mutate(query, live=live, change=change, **variables):
                    if "addPullRequestReviewThreadReply" in query:
                        live["comments"].append(
                            {
                                "id": "reply1",
                                "url": "url",
                                "body": variables["body"],
                                "author": {"login": "me"},
                            }
                        )
                    elif change == "reopened":
                        live["isResolved"] = True
                    return {}

                with (
                    patch.object(
                        check,
                        "read_review_thread",
                        side_effect=lambda _, live=live: (copy.deepcopy(live), "me"),
                    ),
                    patch.object(check, "graphql", side_effect=mutate) as api,
                ):
                    if change == "reopened":
                        check.finish_review(
                            state, path, event_id, "Fixed", "tested", "o/r", 1
                        )
                        live["isResolved"] = False
                    with self.assertRaises(RuntimeError):
                        check.finish_review(
                            state, path, event_id, "Fixed", "tested", "o/r", 1
                        )
                    if change not in {"resolve_failure", "reopened"}:
                        api.assert_not_called()
                    if change != "reopened":
                        self.assertIn(event_id, json.loads(path.read_text())["pending"])

    def test_head_change_creates_new_review_event(self):
        data = snapshot()
        data["reviewThreads"] = [thread()]
        state = check.update({}, data)
        old_id = next(iter(state["pending"]))
        data["pr"]["headRefOid"] = "new"
        state = check.update(state, data)
        self.assertNotIn(old_id, state["pending"])
        self.assertTrue(
            any(event["kind"] == "thread" for event in state["pending"].values())
        )

    def test_review_thread_fetch_paginates_comments(self):
        first = thread()
        first["comments"] = {
            "nodes": [{"id": "first"}],
            "pageInfo": {"hasNextPage": True, "endCursor": "cursor1"},
        }
        second = {
            "comments": {
                "nodes": [{"id": "second"}],
                "pageInfo": {"hasNextPage": False, "endCursor": None},
            },
        }
        with patch.object(
            check,
            "graphql",
            side_effect=[
                {"node": first, "viewer": {"login": "me"}},
                {"node": second},
            ],
        ) as api:
            result, login = check.read_review_thread("thread1")
        self.assertEqual("me", login)
        self.assertEqual([{"id": "first"}, {"id": "second"}], result["comments"])
        self.assertEqual("cursor1", api.call_args.kwargs["cursor"])

    def test_ci_run_hint(self):
        data = snapshot()
        data["pr"]["statusCheckRollup"] = [
            {
                "conclusion": "FAILURE",
                "detailsUrl": "https://github.com/o/r/actions/runs/123/job/456",
            }
        ]
        action = check.plan_actions(check.update({}, data), current_interval=1)[0]
        self.assertEqual(123, action["runId"])
        self.assertEqual(
            ["gh", "run", "view", "123", "--log-failed"], action["logArgs"]
        )

    def test_cleanup_retention_preview_and_delete(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "o--r-1.json"
            args = [
                "check.py",
                "cleanup",
                "--repo",
                "o/r",
                "--pr",
                "1",
                "--state-dir",
                directory,
            ]
            for pr_state in ("OPEN", "UNKNOWN", "CLOSED", "MERGED"):
                check.save(path, check.update({}, snapshot()))
                with (
                    patch.object(sys, "argv", args),
                    patch.object(check, "gh", return_value={"state": pr_state}),
                    patch("builtins.print"),
                ):
                    self.assertEqual(0, check.main())
                    self.assertTrue(path.exists())
                with (
                    patch.object(sys, "argv", args + ["--apply"]),
                    patch.object(check, "gh", return_value={"state": pr_state}),
                    patch("builtins.print"),
                ):
                    self.assertEqual(0, check.main())
                    self.assertEqual(pr_state in {"OPEN", "UNKNOWN"}, path.exists())
            data = snapshot()
            data["reviewThreads"] = [thread()]
            check.save(path, check.update({}, data))
            with (
                patch.object(sys, "argv", args + ["--apply"]),
                patch.object(check, "gh") as api,
                patch("builtins.print"),
            ):
                self.assertEqual(0, check.main())
                api.assert_not_called()
                self.assertTrue(path.exists())
            check.save(path, check.update({}, snapshot()))
            with (
                patch.object(sys, "argv", args + ["--apply"]),
                patch.object(check, "gh", side_effect=RuntimeError("API down")),
                patch("builtins.print"),
            ):
                self.assertEqual(1, check.main())
                self.assertTrue(path.exists())
            path.unlink()
            with (
                patch.object(sys, "argv", args + ["--apply"]),
                patch.object(check, "gh") as api,
                patch("builtins.print"),
            ):
                self.assertEqual(0, check.main())
                api.assert_not_called()

    def test_action_plan_interval_stop_and_paused(self):
        state = check.update({}, snapshot())
        self.assertEqual([], check.plan_actions(state, current_interval=1))
        action = check.plan_actions(state, current_interval=20)[0]
        self.assertEqual("FREQ=MINUTELY;INTERVAL=1", action["rrule"])
        state["stopRequested"] = True
        actions = check.plan_actions(state, current_interval=1)
        self.assertEqual(["pause_monitor", "notify"], [a["type"] for a in actions])
        self.assertEqual(
            ["notify"],
            [a["type"] for a in check.plan_actions(state, monitor_status="PAUSED")],
        )

    def test_action_plan_title_notification_and_terminal(self):
        data = snapshot()
        state = check.update({}, data)
        self.assertEqual(
            [{"type": "set_title", "title": "Chat"}],
            [
                {k: v for k, v in a.items() if k != "id"}
                for a in check.plan_actions(
                    state, title="👍 👍 Chat", current_interval=1
                )
            ],
        )
        data["prReactions"] = [
            {"id": 1, "content": "+1", "user": {"login": "chatgpt-codex-connector"}}
        ]
        state = check.update(state, data)
        actions = check.plan_actions(state, title="Chat", current_interval=1)
        self.assertEqual("👍 Chat", actions[0]["title"])
        self.assertEqual("notify", actions[1]["type"])
        key = actions[1]["eventId"]
        state["acknowledged"][key] = "notified"
        state = check.update(state, data)
        self.assertEqual(
            [], check.plan_actions(state, title="👍 Chat", current_interval=1)
        )
        for status, merged in [("MERGED", True), ("CLOSED", False)]:
            data["pr"]["state"] = status
            state = check.update(state, data)
            expected = ["pause_monitor"] + (["cleanup_worktree"] if merged else []) + [
                "notify",
                "delete_monitor",
                "cleanup_state",
            ]
            self.assertEqual(expected, [a["type"] for a in check.plan_actions(state)])

    def test_terminal_monitor_stops_before_fallible_actions(self):
        for status in ("MERGED", "CLOSED"):
            with self.subTest(status=status):
                data = snapshot()
                data["pr"]["state"] = status
                state = check.update({}, data)
                actions = check.plan_actions(state, title="👍 Chat")
                self.assertEqual("pause_monitor", actions[0]["type"])
                state["notificationDeliveries"] = {
                    "old-delivery": {
                        "status": "unknown",
                        "action": {
                            "id": "old-delivery", "type": "notify", "message": "old"
                        },
                    }
                }
                actions = check.plan_actions(state, title="👍 Chat")
                self.assertEqual("pause_monitor", actions[0]["type"])
                self.assertEqual("reconcile_notification", actions[1]["type"])
                # A paused retry must still offer unfinished terminal cleanup.
                paused = check.plan_actions(state, monitor_status="PAUSED")
                self.assertNotIn("pause_monitor", [a["type"] for a in paused])
                self.assertIn("delete_monitor", [a["type"] for a in paused])

    def test_idle_stop_boundary_and_changes(self):
        data = snapshot()
        start = datetime(2026, 10, 6, tzinfo=timezone.utc)
        state = check.update({}, data, now=start)
        self.assertFalse(state["stopRequested"])
        state = check.update(state, data, now=start + timedelta(minutes=19, seconds=59))
        self.assertFalse(state["stopRequested"])
        state = check.update(state, data, now=start + timedelta(minutes=20))
        self.assertTrue(state["stopRequested"])
        for field, value in [("headRefOid", "new"), ("mergeStateStatus", "BLOCKED")]:
            changed = copy.deepcopy(data)
            changed["pr"][field] = value
            self.assertFalse(
                check.update(state, changed, now=start + timedelta(minutes=21))[
                    "stopRequested"
                ]
            )

    def test_idle_stop_exclusions_and_reset(self):
        start = datetime(2026, 10, 6, tzinfo=timezone.utc)
        later = start + timedelta(minutes=30)
        data = snapshot()
        state = check.update({}, data, now=start)
        for interval in (5, 20):
            self.assertFalse(
                check.update(state, data, now=later, interval_minutes=interval)[
                    "stopRequested"
                ]
            )
        for changes in ({"isDraft": True}, {"state": "CLOSED"}):
            changed = copy.deepcopy(data)
            changed["pr"].update(changes)
            self.assertFalse(check.update(state, changed, now=later)["stopRequested"])
        for changes in (
            {"lastError": "API down"},
            {"pending": {"event": {}}},
            {"snapshotFingerprint": None},
        ):
            self.assertFalse(
                check.update({**state, **changes}, data, now=later)["stopRequested"]
            )
        data["comments"] = [thread()["comments"][0]]
        pending = check.update(state, data, now=later)
        self.assertIsNone(pending["idleSince"])
        self.assertFalse(
            check.update(pending, data, now=later + timedelta(minutes=30))[
                "stopRequested"
            ]
        )

    def test_codex_pass_decision_table_and_once_per_head(self):
        data = snapshot()
        data["pr"]["headRefOid"] = "abcdef0123456789"
        reaction = {
            "id": 1,
            "content": "+1",
            "user": {"login": "chatgpt-codex-connector[bot]"},
        }
        self.assertFalse(check.codex_reaction_ids(data))
        data["prReactions"] = [reaction]
        self.assertTrue(check.codex_reaction_ids(data))
        for login in ("someone", "chatgpt-codex-connector-fake", ""):
            with self.subTest(login=login):
                reaction["user"]["login"] = login
                self.assertFalse(check.codex_reaction_ids(data))
        reaction["user"]["login"] = "chatgpt-codex-connector"
        self.assertTrue(check.codex_reaction_ids(data))
        data["comments"] = [
            {
                "id": "summary",
                "updatedAt": "now",
                "author": {"login": "chatgpt-codex-connector[bot]"},
                "body": "Review in progress for an old commit",
            }
        ]
        self.assertTrue(check.codex_reaction_ids(data))
        state = check.update({}, data)
        self.assertEqual(1, state["recommendedIntervalMinutes"])
        self.assertFalse(
            any(e["kind"] == "codex_passed" for e in state["pending"].values())
        )
        data["prReactions"] = [dict(reaction, id=2)]
        state = check.update(state, data)
        key = next(
            k for k, e in state["pending"].items() if e["kind"] == "codex_passed"
        )
        self.assertIn(key, check.update(state, data)["pending"])
        state["acknowledged"][key] = "notified"
        data["prReactions"] = []
        state = check.update(state, data)
        data["prReactions"] = [dict(reaction, id=2)]
        state = check.update(state, data)
        self.assertFalse(
            any(e["kind"] == "codex_passed" for e in state["pending"].values())
        )
        data = copy.deepcopy(data)
        data["pr"]["headRefOid"] = "123456789abcdef0"
        self.assertTrue(check.codex_reaction_ids(data))
        state = check.update(state, data)
        self.assertEqual(1, state["recommendedIntervalMinutes"])
        self.assertFalse(
            any(e["kind"] == "codex_passed" for e in state["pending"].values())
        )
        data["prReactions"] = [dict(reaction, id=3)]
        state = check.update(state, data)
        self.assertEqual(1, state["recommendedIntervalMinutes"])
        self.assertTrue(
            any(e["kind"] == "codex_passed" for e in state["pending"].values())
        )

    def test_reaction_after_head_change_and_pass_persistence(self):
        data = snapshot()
        started = datetime(2026, 10, 4, tzinfo=timezone.utc)
        state = check.update({}, data, now=started)
        self.assertEqual(1, state["recommendedIntervalMinutes"])
        data = copy.deepcopy(data)
        data["pr"]["headRefOid"] = "def"
        data["prReactions"] = [
            {
                "id": 3,
                "content": "+1",
                "user": {"login": "chatgpt-codex-connector[bot]"},
            }
        ]
        state = check.update(state, data, now=started)
        self.assertEqual(1, state["recommendedIntervalMinutes"])
        self.assertEqual("def", state["codexPassedHead"])
        actions = check.plan_actions(state, title="Chat", current_interval=1)
        self.assertEqual("👍 Chat", actions[0]["title"])
        self.assertTrue(any(a["type"] == "notify" for a in actions))
        self.assertEqual(
            {"type": "set_title", "titlePrefix": "👍 "},
            {k: v for k, v in check.plan_actions(state)[0].items() if k != "id"},
        )
        data["prReactions"] = [dict(data["prReactions"][0], id=4)]
        approved_at = started
        state = check.update(state, data, now=approved_at)
        self.assertEqual("def", state["codexPassedHead"])
        state = check.update(
            state, data, now=approved_at + timedelta(minutes=9, seconds=59)
        )
        self.assertEqual(1, state["recommendedIntervalMinutes"])
        state = check.update(state, data, now=approved_at + timedelta(minutes=10))
        self.assertEqual(20, state["recommendedIntervalMinutes"])
        data["prReactions"] = []
        state = check.update(state, data, now=approved_at + timedelta(minutes=11))
        self.assertEqual(20, state["recommendedIntervalMinutes"])

    def test_title_prefix_removed_when_reaction_changes_to_eyes(self):
        data = snapshot()
        state = check.update({}, data)
        data["prReactions"] = [
            {
                "id": 1,
                "content": "+1",
                "user": {"login": "chatgpt-codex-connector[bot]"},
            }
        ]
        state = check.update(state, data)
        self.assertEqual("👍 ", check.plan_actions(state)[0]["titlePrefix"])
        data = copy.deepcopy(data)
        data["pr"]["headRefOid"] = "new-head"
        data["prReactions"] = []
        data["reactions"] = [{"content": "EYES", "users": {"totalCount": 1}}]
        state = check.update(state, data)
        self.assertTrue(check.eyes(data))
        self.assertEqual("", check.plan_actions(state)[0]["titlePrefix"])
        self.assertEqual("Chat", check.plan_actions(state, title="👍 Chat")[0]["title"])
        # Keep requesting removal if the caller failed to apply it on the first poll.
        state = check.update(state, data)
        self.assertEqual("", check.plan_actions(state)[0]["titlePrefix"])
        self.assertFalse(
            any(e["kind"] == "codex_passed" for e in state["pending"].values())
        )

    def test_existing_state_does_not_reuse_old_reaction(self):
        data = snapshot()
        data["prReactions"] = [
            {
                "id": 7,
                "content": "+1",
                "user": {"login": "chatgpt-codex-connector[bot]"},
            }
        ]
        legacy = {"snapshot": copy.deepcopy(data)}
        state = check.update(legacy, data)
        self.assertEqual(1, state["recommendedIntervalMinutes"])
        data["prReactions"] = [dict(data["prReactions"][0], id=8)]
        self.assertEqual(1, check.update(state, data)["recommendedIntervalMinutes"])

    def test_ci_ack_retry_and_head(self):
        data = snapshot()
        self.assertFalse(check.update({}, data)["pending"])
        data["pr"]["statusCheckRollup"] = [
            {"name": "test", "conclusion": "FAILURE", "detailsUrl": "/runs/1"}
        ]
        state = check.update({}, data)
        key = next(iter(state["pending"]))
        self.assertIn(key, check.update(state, data)["pending"])
        state["acknowledged"][key] = "fixed"
        self.assertFalse(check.update(state, data)["pending"])
        data["pr"]["statusCheckRollup"][0]["detailsUrl"] = "/runs/2"
        self.assertTrue(check.update(state, data)["pending"])
        data["pr"]["headRefOid"] = "def"
        self.assertNotEqual(key, next(iter(check.update(state, data)["pending"])))

    def test_thread_edits_reactions_resolve_and_reopen(self):
        data = snapshot()
        data["reviewThreads"] = [thread()]
        state = check.update({}, data)
        key = next(iter(state["pending"]))
        state["acknowledged"][key] = "responded"
        data["reviewThreads"][0]["comments"][0]["reactionGroups"] = [
            {"content": "EYES", "users": {"totalCount": 1}}
        ]
        self.assertFalse(check.update(state, data)["pending"])
        self.assertFalse(check.eyes(data))
        data["reviewThreads"][0]["comments"][0]["body"] = "follow up"
        self.assertTrue(check.update(state, data)["pending"])
        data["reviewThreads"][0]["isResolved"] = True
        state = check.update(state, data)
        self.assertFalse(state["pending"])
        data["reviewThreads"][0]["isResolved"] = False
        self.assertTrue(check.update(state, data)["pending"])

    def test_eyes_only_checks_pr_reactions(self):
        data = snapshot()
        reaction = {"content": "EYES", "users": {"totalCount": 1}}
        data["pr"].update(title="👀", body="👀")
        data["comments"] = [{"body": "👀", "reactionGroups": [reaction]}]
        data["reviews"] = [{"body": "👀", "reactionGroups": [reaction]}]
        data["reviewThreads"] = [thread()]
        data["reviewThreads"][0]["comments"][0].update(
            body="👀", reactionGroups=[reaction]
        )
        self.assertFalse(check.eyes(data))
        data = snapshot()
        for content, count, blocked in [
            ("EYES", 1, True),
            ("EYES", 0, False),
            ("THUMBS_UP", 1, False),
        ]:
            with self.subTest(content=content, count=count):
                data["reactions"] = [
                    {"content": content, "users": {"totalCount": count}}
                ]
                self.assertEqual(check.eyes(data), blocked)

    def test_merge_blocking_conditions(self):
        cases = [
            ({"state": "CLOSED"}, "not_open"),
            ({"isDraft": True}, "draft"),
            ({"mergeable": "CONFLICTING"}, "conflict"),
            ({"mergeable": "UNKNOWN"}, "mergeability_unknown"),
            ({"mergeStateStatus": "DIRTY"}, "conflict"),
            ({"mergeStateStatus": "BLOCKED"}, "merge_state_blocked"),
            ({"mergeStateStatus": "UNKNOWN"}, "merge_state_unknown"),
            ({"reviewDecision": "CHANGES_REQUESTED"}, "review_changes_requested"),
            ({"reviewDecision": "REVIEW_REQUIRED"}, "review_review_required"),
        ]
        for fields, reason in cases:
            with self.subTest(fields=fields):
                data = snapshot()
                data["pr"].update(fields)
                result = check.merge_decision(data, {})
                self.assertFalse(result["canMerge"])
                self.assertIn(reason, result["blockingReasons"])
        for outcome, reason in [
            ("FAILURE", "ci_failed"),
            ("CANCELLED", "ci_failed"),
            ("PENDING", "ci_pending"),
            (None, "ci_pending"),
            ("UNRECOGNIZED", "ci_failed"),
            ("SUCCESS", None),
            ("NEUTRAL", None),
            ("SKIPPED", None),
        ]:
            with self.subTest(outcome=outcome):
                data = snapshot()
                data["pr"]["statusCheckRollup"] = [{"conclusion": outcome}]
                result = check.merge_decision(data, {})
                self.assertEqual(result["canMerge"], reason is None)
                if reason:
                    self.assertIn(reason, result["blockingReasons"])
        for failures in (2, 3, 4):
            result = check.merge_decision(
                snapshot(), {"attempts": {"problem": {"failures": failures}}}
            )
            self.assertEqual(result["canMerge"], failures < 3)

    def test_merge_decision_after_ack_and_resolution(self):
        data = snapshot()
        data["comments"] = [{"id": "c", "updatedAt": "now", "body": "FYI 👀"}]
        state = check.update({}, data)
        self.assertIn(
            "pending_comment", check.merge_decision(data, state)["blockingReasons"]
        )
        for key in state["pending"]:
            state["acknowledged"][key] = "informational"
        state = check.update(state, data)
        self.assertTrue(check.merge_decision(data, state)["canMerge"])
        data["reviewThreads"] = [thread()]
        state = check.update(state, data)
        for key in state["pending"]:
            state["acknowledged"][key] = "handled"
        state = check.update(state, data)
        self.assertIn(
            "unresolved_threads", check.merge_decision(data, state)["blockingReasons"]
        )
        data["reviewThreads"][0]["isResolved"] = True
        state = check.update(state, data)
        self.assertTrue(check.merge_decision(data, state)["canMerge"])
        data["reactions"] = [{"content": "EYES", "users": {"totalCount": 1}}]
        self.assertIn(
            "eyes_reaction", check.merge_decision(data, state)["blockingReasons"]
        )
        data["reactions"] = []
        data["pr"]["statusCheckRollup"] = [{"status": "IN_PROGRESS"}]
        self.assertFalse(check.merge_decision(data, state)["canMerge"])
        data["pr"]["statusCheckRollup"] = [{"conclusion": "SUCCESS"}]
        result = check.merge_decision(data, state)
        self.assertTrue(result["canMerge"])
        self.assertEqual(
            result, check.merge_decision(copy.deepcopy(data), copy.deepcopy(state))
        )

    def test_terminal_suppresses_work(self):
        data = snapshot()
        data["reviewThreads"] = [thread()]
        data["pr"]["state"] = "MERGED"
        self.assertEqual(
            ["terminal"],
            [e["kind"] for e in check.update({}, data)["pending"].values()],
        )
        data["pr"]["state"] = "OPEN"
        data["pr"]["isDraft"] = True
        self.assertFalse(check.update({}, data)["pending"])

    def test_pagination_and_bad_cursor(self):
        pages = {
            None: {"nodes": [1], "pageInfo": {"hasNextPage": True, "endCursor": "a"}},
            "a": {"nodes": [2], "pageInfo": {"hasNextPage": False, "endCursor": None}},
        }
        self.assertEqual([1, 2], check.connection(pages.__getitem__))
        pages["a"]["pageInfo"] = {"hasNextPage": True, "endCursor": "a"}
        with self.assertRaises(RuntimeError):
            check.connection(pages.__getitem__)

    def test_nested_comments_pagination(self):
        pr = snapshot()["pr"]
        first = thread()["comments"][0]
        second = dict(first, id="c2", body="follow up")

        def api(query, **variables):
            if "node(id:" in query:
                return {
                    "node": {
                        "comments": {
                            "nodes": [second],
                            "pageInfo": {"hasNextPage": False, "endCursor": None},
                        }
                    }
                }
            if "reviewThreads(first:" in query:
                value = dict(
                    thread(),
                    comments={
                        "nodes": [first],
                        "pageInfo": {"hasNextPage": True, "endCursor": "next"},
                    },
                )
                return {
                    "repository": {
                        "pullRequest": {
                            "reviewThreads": {
                                "nodes": [value],
                                "pageInfo": {"hasNextPage": False, "endCursor": None},
                            }
                        }
                    }
                }
            if "comments(first:" in query:
                field = "comments"
            elif "reviews(first:" in query:
                field = "reviews"
            else:
                return {"repository": {"pullRequest": {"reactionGroups": []}}}
            return {
                "repository": {
                    "pullRequest": {
                        field: {
                            "nodes": [],
                            "pageInfo": {"hasNextPage": False, "endCursor": None},
                        }
                    }
                }
            }

        with (
            patch.object(check, "gh", side_effect=[pr, [[], []]]),
            patch.object(check, "graphql", side_effect=api),
        ):
            result = check.collect("o/r", 1)
        self.assertEqual(
            ["c1", "c2"], [c["id"] for c in result["reviewThreads"][0]["comments"]]
        )

    def test_failed_fetch_retains_snapshot_and_pending(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "o--r-1.json"
            data = snapshot()
            data["reviewThreads"] = [thread()]
            initial = check.update({}, data)
            check.save(path, initial)
            with (
                patch.object(
                    sys,
                    "argv",
                    [
                        "check.py",
                        "check",
                        "--repo",
                        "o/r",
                        "--pr",
                        "1",
                        "--state-dir",
                        directory,
                    ],
                ),
                patch.object(check, "collect", side_effect=RuntimeError("API down")),
                patch("builtins.print"),
            ):
                self.assertEqual(1, check.main())
            after = json.loads(path.read_text())
            self.assertEqual(initial["snapshot"], after["snapshot"])
            self.assertEqual(initial["pending"], after["pending"])
            self.assertEqual(initial["lastSuccessAt"], after["lastSuccessAt"])
            self.assertEqual("API down", after["lastError"])
            self.assertIsNone(after["idleSince"])
            self.assertFalse(after["stopRequested"])

    def test_cli_status_for_pending_events_and_lifecycle(self):
        cases = [
            ("ci", {"statusCheckRollup": [{"conclusion": "FAILURE"}]}),
            ("comment", {"comments": [thread()["comments"][0]]}),
            (
                "review",
                {
                    "reviews": [
                        {"id": "r1", "state": "CHANGES_REQUESTED", "body": "fix it"}
                    ]
                },
            ),
            ("thread", {"reviewThreads": [thread()]}),
        ]
        for kind, changes in cases:
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as directory:
                data = snapshot()
                if kind == "ci":
                    data["pr"].update(changes)
                else:
                    data.update(changes)
                fixture = Path(directory) / "fixture.json"
                base = [
                    sys.executable,
                    str(Path(check.__file__)),
                    "check",
                    "--repo",
                    "o/r",
                    "--pr",
                    "1",
                    "--state-dir",
                    directory,
                    "--fixture",
                    str(fixture),
                ]

                def run(fixture=fixture, data=data, base=base):
                    fixture.write_text(json.dumps(data))
                    result = subprocess.run(
                        base, capture_output=True, text=True, check=False
                    )
                    self.assertEqual(0, result.returncode, result.stderr)
                    return json.loads(result.stdout)

                first = run()
                self.assertEqual("action_required", first["status"])
                self.assertEqual([kind], [event["kind"] for event in first["events"]])
                repeated = run()
                self.assertEqual(first["events"], repeated["events"])
                self.assertEqual("action_required", repeated["status"])
                data["pr"]["isDraft"] = True
                self.assertEqual("draft", run()["status"])
                data["pr"]["state"] = "MERGED"
                self.assertEqual("terminal", run()["status"])

    def test_cli_fixture_ack_and_status(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "fixture.json"
            data = snapshot()
            data["reviewThreads"] = [thread()]
            fixture.write_text(json.dumps(data))
            base = [
                sys.executable,
                str(Path(check.__file__)),
                "--repo",
                "o/r",
                "--pr",
                "1",
                "--state-dir",
                directory,
            ]

            def run(*args):
                return json.loads(subprocess.check_output(base + list(args), text=True))

            first = run("check", "--fixture", str(fixture))
            self.assertEqual("action_required", first["status"])
            key = first["events"][0]["id"]
            self.assertEqual(
                1, run("ack", "--event", key, "--reason", "fixed")["count"]
            )
            after = run("check", "--fixture", str(fixture))
            self.assertEqual("ok", after["status"])
            self.assertFalse(after["events"])
            self.assertEqual(0, run("status")["pendingCount"])

    def test_cli_cadence_transitions(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "fixture.json"
            data = snapshot()

            def run():
                fixture.write_text(json.dumps(data))
                return json.loads(
                    subprocess.check_output(
                        [
                            sys.executable,
                            str(Path(check.__file__)),
                            "check",
                            "--repo",
                            "o/r",
                            "--pr",
                            "1",
                            "--state-dir",
                            directory,
                            "--fixture",
                            str(fixture),
                        ],
                        text=True,
                    )
                )

            first = run()
            self.assertEqual(1, first["recommendedIntervalMinutes"])
            self.assertFalse(first["codexReactionPresent"])
            reaction = {
                "id": 1,
                "content": "+1",
                "user": {"login": "chatgpt-codex-connector[bot]"},
            }
            data["prReactions"] = [reaction]
            approved = run()
            self.assertEqual(1, approved["recommendedIntervalMinutes"])
            self.assertTrue(approved["codexReactionPresent"])
            data["pr"]["headRefOid"] = "def"
            result = run()
            self.assertTrue(result["headChanged"])
            self.assertEqual(1, result["recommendedIntervalMinutes"])
            data["prReactions"] = []
            self.assertFalse(run()["codexReactionPresent"])
            data["prReactions"] = [dict(reaction, id=2)]
            self.assertTrue(run()["codexReactionPresent"])


if __name__ == "__main__":
    unittest.main()
