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
    def test_codex_pass_decision_table_and_once_per_head(self):
        data = snapshot()
        data["pr"]["headRefOid"] = "abcdef0123456789"
        reaction = {
            "id": 1, "content": "+1",
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
        data["comments"] = [{
            "id": "summary", "updatedAt": "now",
            "author": {"login": "chatgpt-codex-connector[bot]"},
            "body": "Review in progress for an old commit",
        }]
        self.assertTrue(check.codex_reaction_ids(data))
        state = check.update({}, data)
        self.assertEqual(1, state["recommendedIntervalMinutes"])
        self.assertFalse(any(
            e["kind"] == "codex_passed" for e in state["pending"].values()
        ))
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
        self.assertFalse(any(
            e["kind"] == "codex_passed" for e in state["pending"].values()
        ))
        data["prReactions"] = [dict(reaction, id=3)]
        state = check.update(state, data)
        self.assertEqual(1, state["recommendedIntervalMinutes"])
        self.assertTrue(any(
            e["kind"] == "codex_passed" for e in state["pending"].values()
        ))

    def test_reaction_after_head_change_and_pass_persistence(self):
        data = snapshot()
        started = datetime(2026, 10, 4, tzinfo=timezone.utc)
        state = check.update({}, data, now=started)
        self.assertEqual(1, state["recommendedIntervalMinutes"])
        data = copy.deepcopy(data)
        data["pr"]["headRefOid"] = "def"
        data["prReactions"] = [{
            "id": 3, "content": "+1",
            "user": {"login": "chatgpt-codex-connector[bot]"},
        }]
        state = check.update(state, data, now=started)
        self.assertEqual(1, state["recommendedIntervalMinutes"])
        self.assertIsNone(state["codexPassedHead"])
        data["prReactions"] = [dict(data["prReactions"][0], id=4)]
        approved_at = started + timedelta(seconds=30)
        state = check.update(state, data, now=approved_at)
        self.assertEqual("def", state["codexPassedHead"])
        state = check.update(state, data, now=approved_at + timedelta(minutes=9, seconds=59))
        self.assertEqual(1, state["recommendedIntervalMinutes"])
        state = check.update(state, data, now=approved_at + timedelta(minutes=10))
        self.assertEqual(20, state["recommendedIntervalMinutes"])
        data["prReactions"] = []
        state = check.update(state, data, now=approved_at + timedelta(minutes=11))
        self.assertEqual(20, state["recommendedIntervalMinutes"])

    def test_existing_state_does_not_reuse_old_reaction(self):
        data = snapshot()
        data["prReactions"] = [{
            "id": 7, "content": "+1",
            "user": {"login": "chatgpt-codex-connector[bot]"},
        }]
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
        for content, count, blocked in [
            ("EYES", 1, True), ("EYES", 0, False), ("THUMBS_UP", 1, False)
        ]:
            with self.subTest(content=content, count=count):
                data["reactions"] = [
                    {"content": content, "users": {"totalCount": count}}
                ]
                self.assertEqual(check.eyes(data), blocked)

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

    def test_cli_status_for_pending_events_and_lifecycle(self):
        cases = [
            ("ci", {"statusCheckRollup": [{"conclusion": "FAILURE"}]}),
            ("comment", {"comments": [thread()["comments"][0]]}),
            (
                "review",
                {"reviews": [{"id": "r1", "state": "CHANGES_REQUESTED", "body": "fix it"}]},
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

                def run():
                    fixture.write_text(json.dumps(data))
                    result = subprocess.run(base, capture_output=True, text=True)
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
                return json.loads(subprocess.check_output([
                    sys.executable, str(Path(check.__file__)), "check",
                    "--repo", "o/r", "--pr", "1", "--state-dir", directory,
                    "--fixture", str(fixture),
                ], text=True))

            first = run()
            self.assertEqual(1, first["recommendedIntervalMinutes"])
            self.assertFalse(first["codexReactionPresent"])
            reaction = {
                "id": 1, "content": "+1",
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
