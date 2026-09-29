import json
import subprocess
import sys
import tempfile
import unittest
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
        self.assertTrue(check.eyes(data))
        data["reviewThreads"][0]["comments"][0]["body"] = "follow up"
        self.assertTrue(check.update(state, data)["pending"])
        data["reviewThreads"][0]["isResolved"] = True
        state = check.update(state, data)
        self.assertFalse(state["pending"])
        data["reviewThreads"][0]["isResolved"] = False
        self.assertTrue(check.update(state, data)["pending"])

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
            patch.object(check, "gh", return_value=pr),
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
            key = first["events"][0]["id"]
            self.assertEqual(
                1, run("ack", "--event", key, "--reason", "fixed")["count"]
            )
            self.assertFalse(run("check", "--fixture", str(fixture))["events"])
            self.assertEqual(0, run("status")["pendingCount"])


if __name__ == "__main__":
    unittest.main()
