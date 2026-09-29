#!/usr/bin/env python3
"""Fetch one PR, retain unacknowledged events, and print only actionable changes."""

import argparse
import fcntl
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

PAGE = "pageInfo { hasNextPage endCursor }"
REACTIONS = "reactionGroups { content users { totalCount } }"
COMMENT = "id body url updatedAt author { login } " + REACTIONS
FIELDS = {
    "comments": COMMENT,
    "reviews": "id body url state submittedAt lastEditedAt author { login } commit { oid }",
    "reviewThreads": "id isResolved path line comments(first:100) { nodes { "
    + COMMENT
    + " } "
    + PAGE
    + " }",
}


def gh(*args):
    result = subprocess.run(
        ["gh", *args], capture_output=True, text=True, timeout=120, check=False
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "gh failed")
    return json.loads(result.stdout)


def graphql(query, **variables):
    args = ["api", "graphql", "-f", "query=" + query]
    for key, value in variables.items():
        if value is not None:
            args += ["-F" if isinstance(value, int) else "-f", f"{key}={value}"]
    result = gh(*args)
    if result.get("errors"):
        raise RuntimeError(json.dumps(result["errors"]))
    return result["data"]


def connection(fetch):
    nodes, cursor = [], None
    while True:
        page = fetch(cursor)
        nodes.extend(page["nodes"])
        info = page["pageInfo"]
        if not info["hasNextPage"]:
            return nodes
        next_cursor = info["endCursor"]
        if not next_cursor or next_cursor == cursor:
            raise RuntimeError("Invalid pagination cursor")
        cursor = next_cursor


def collect(repo, number):
    owner, name = repo.split("/")
    pr = gh(
        "pr",
        "view",
        str(number),
        "--repo",
        repo,
        "--json",
        "state,mergedAt,isDraft,headRefOid,baseRefOid,mergeable,mergeStateStatus,url,body,title,statusCheckRollup",
    )
    if pr["state"] != "OPEN" or pr["isDraft"]:
        return {
            "pr": pr,
            "comments": [],
            "reviews": [],
            "reviewThreads": [],
            "reactions": [],
        }
    data = {"pr": pr}
    for field, fields in FIELDS.items():
        query = (
            "query($owner:String!,$repo:String!,$number:Int!,$cursor:String) {"
            "repository(owner:$owner,name:$repo) { pullRequest(number:$number) {"
            + field
            + "(first:100,after:$cursor) { nodes { "
            + fields
            + " } "
            + PAGE
            + " } } } }"
        )

        def fetch(cursor, query=query, field=field):
            return graphql(query, owner=owner, repo=name, number=number, cursor=cursor)[
                "repository"
            ]["pullRequest"][field]

        data[field] = connection(fetch)
    for thread in data["reviewThreads"]:
        first = thread["comments"]
        query = (
            "query($id:ID!,$cursor:String) { node(id:$id) { ... on PullRequestReviewThread {"
            "comments(first:100,after:$cursor) { nodes { "
            + COMMENT
            + " } "
            + PAGE
            + " } } } }"
        )

        def fetch_comments(cursor, first=first, query=query, thread_id=thread["id"]):
            if cursor is None:
                return first
            return graphql(query, id=thread_id, cursor=cursor)["node"]["comments"]

        thread["comments"] = connection(fetch_comments)
    query = (
        "query($owner:String!,$repo:String!,$number:Int!) { repository(owner:$owner,name:$repo) {"
        "pullRequest(number:$number) { " + REACTIONS + " } } }"
    )
    data["reactions"] = graphql(query, owner=owner, repo=name, number=number)[
        "repository"
    ]["pullRequest"]["reactionGroups"]
    return data


def digest(value):
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, ensure_ascii=False).encode()
    ).hexdigest()[:24]


def events(snapshot):
    pr = snapshot["pr"]
    found = {}

    def add(kind, identity, payload):
        key = kind + ":" + digest(identity)
        found[key] = {"id": key, "kind": kind, **payload}

    if pr["state"] != "OPEN":
        add(
            "terminal",
            [pr["state"], pr.get("mergedAt")],
            {"state": pr["state"], "mergedAt": pr.get("mergedAt")},
        )
        return found
    if pr["isDraft"]:
        return found
    head = pr["headRefOid"]
    for check in pr.get("statusCheckRollup") or []:
        outcome = check.get("conclusion") or check.get("state")
        if outcome in {
            "FAILURE",
            "ERROR",
            "TIMED_OUT",
            "CANCELLED",
            "ACTION_REQUIRED",
            "STARTUP_FAILURE",
        }:
            add(
                "ci",
                [
                    head,
                    {
                        k: check.get(k)
                        for k in (
                            "databaseId",
                            "detailsUrl",
                            "targetUrl",
                            "name",
                            "context",
                            "startedAt",
                            "completedAt",
                            "conclusion",
                            "state",
                        )
                    },
                ],
                {"head": head, "check": check},
            )
    if pr["mergeable"] == "CONFLICTING" or pr["mergeStateStatus"] == "DIRTY":
        add(
            "conflict",
            [head, pr.get("baseRefOid")],
            {"head": head, "base": pr.get("baseRefOid")},
        )
    for comment in snapshot["comments"]:
        add(
            "comment",
            [comment["id"], comment["updatedAt"], comment["body"]],
            {"comment": comment},
        )
    for review in snapshot["reviews"]:
        if review["state"] == "CHANGES_REQUESTED" or review["body"]:
            add("review", review, {"review": review})
    for thread in snapshot["reviewThreads"]:
        if not thread["isResolved"]:
            add(
                "thread",
                [
                    thread["id"],
                    [
                        {k: c.get(k) for k in ("id", "updatedAt", "body")}
                        for c in thread["comments"]
                    ],
                ],
                {"thread": thread},
            )
    return found


def eyes(snapshot):
    groups = list(snapshot.get("reactions", []))
    texts = [snapshot["pr"].get("body", ""), snapshot["pr"].get("title", "")]
    for item in snapshot["comments"] + snapshot["reviews"]:
        groups.extend(item.get("reactionGroups", []))
        texts.append(item.get("body", ""))
    for thread in snapshot["reviewThreads"]:
        for item in thread["comments"]:
            groups.extend(item.get("reactionGroups", []))
            texts.append(item["body"])
    return any(
        g["content"] == "EYES" and g["users"]["totalCount"] > 0 for g in groups
    ) or any("👀" in t for t in texts)


def update(state, snapshot):
    current = events(snapshot)
    previous = state.get("active", {})
    generation = dict(state.get("generation", {}))
    acknowledged = dict(state.get("acknowledged", {}))
    pending = {}
    for key, event in current.items():
        # Reopening a resolved thread or reappearing failure creates a new occurrence.
        if key not in previous:
            generation[key] = generation.get(key, 0) + 1
        occurrence = key + ":" + str(generation[key])
        event = dict(event, id=occurrence)
        if occurrence not in acknowledged:
            pending[occurrence] = event
    now = datetime.now(timezone.utc).isoformat()
    return {
        **state,
        "version": 1,
        "snapshot": snapshot,
        "active": current,
        "generation": generation,
        "acknowledged": acknowledged,
        "pending": pending,
        "lastSuccessAt": now,
        "lastAttemptAt": now,
        "lastError": None,
    }


def save(path, state):
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix=".monitor-")
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(state, handle, ensure_ascii=False)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["check", "ack", "status"])
    parser.add_argument("--repo", required=True, help="owner/repo")
    parser.add_argument("--pr", type=int, required=True)
    parser.add_argument(
        "--state-dir", type=Path, default=Path.home() / ".codex/pr-monitor"
    )
    parser.add_argument(
        "--event", action="append", default=[], help="Exact event ID to acknowledge"
    )
    parser.add_argument("--reason", help="Outcome/reason for acknowledgment")
    parser.add_argument(
        "--fixture", type=Path, help="Use a saved snapshot instead of GitHub"
    )
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repo) or args.pr < 1:
        parser.error("Invalid repository or PR number")
    args.state_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = args.state_dir / (
        args.repo.replace("/", "--") + "-" + str(args.pr) + ".json"
    )
    with path.with_suffix(".lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print(json.dumps({"status": "busy"}))
            return 0
        state = json.loads(path.read_text()) if path.exists() else {}
        if args.command == "status":
            print(
                json.dumps(
                    {
                        "stateFile": str(path),
                        "lastSuccessAt": state.get("lastSuccessAt"),
                        "lastError": state.get("lastError"),
                        "pendingCount": len(state.get("pending", {})),
                    }
                )
            )
            return 0
        if args.command == "ack":
            if not args.event or not args.reason:
                parser.error("ack requires --event and --reason")
            if any(key not in state.get("pending", {}) for key in args.event):
                parser.error("Unknown or stale event ID; run check again")
            for key in args.event:
                state.setdefault("acknowledged", {})[key] = args.reason
                del state["pending"][key]
            save(path, state)
            print(json.dumps({"status": "acknowledged", "count": len(args.event)}))
            return 0
        try:
            snapshot = (
                json.loads(args.fixture.read_text())
                if args.fixture
                else collect(args.repo, args.pr)
            )
            state = update(state, snapshot)
        except (
            RuntimeError,
            subprocess.TimeoutExpired,
            KeyError,
            ValueError,
            OSError,
        ) as error:
            state.update(
                lastAttemptAt=datetime.now(timezone.utc).isoformat(),
                lastError=str(error),
            )
            save(path, state)
            print(
                json.dumps(
                    {"status": "error", "error": str(error), "stateFile": str(path)}
                )
            )
            return 1
        save(path, state)
        pr = snapshot["pr"]
        print(
            json.dumps(
                {
                    "status": "terminal"
                    if pr["state"] != "OPEN"
                    else "draft"
                    if pr["isDraft"]
                    else "ok",
                    "head": pr["headRefOid"],
                    "url": pr["url"],
                    "mergeable": pr["mergeable"],
                    "mergeBlockedByEyes": eyes(snapshot),
                    "stateFile": str(path),
                    "events": list(state["pending"].values()),
                },
                ensure_ascii=False,
            )
        )
        return 0


if __name__ == "__main__":
    sys.exit(main())
