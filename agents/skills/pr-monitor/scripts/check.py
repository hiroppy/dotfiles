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
APPROVAL_GRACE_SECONDS = 10 * 60
IDLE_STOP_SECONDS = 20 * 60
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
    pages = gh(
        "api",
        f"repos/{repo}/issues/{number}/reactions?per_page=100",
        "--paginate",
        "--slurp",
    )
    data["prReactions"] = [reaction for page in pages for reaction in page]
    return data


def codex_author(author):
    return (author or {}).get("login", "").removesuffix(
        "[bot]"
    ) == "chatgpt-codex-connector"


def codex_reaction_ids(snapshot):
    return {
        str(reaction.get("id") or digest(reaction))
        for reaction in snapshot.get("prReactions", [])
        if reaction.get("content") == "+1" and codex_author(reaction.get("user"))
    }


def digest(value):
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, ensure_ascii=False).encode()
    ).hexdigest()[:24]


def events(snapshot, passed_for_head=False):
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
    if passed_for_head:
        add("codex_passed", head, {"head": head})
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
    items = [
        snapshot["pr"],
        *snapshot.get("comments", []),
        *snapshot.get("reviews", []),
    ]
    for thread in snapshot.get("reviewThreads", []):
        items.extend(thread["comments"])
    groups = list(snapshot.get("reactions", []))
    for item in items:
        groups.extend(item.get("reactionGroups", []))
    return any(
        "👀" in item.get(field, "") for item in items for field in ("body", "title")
    ) or any(
        group["content"] == "EYES" and group["users"]["totalCount"] > 0
        for group in groups
    )


def update(state, snapshot, now=None, interval_minutes=None):
    now = now or datetime.now(timezone.utc)
    head = snapshot["pr"]["headRefOid"]
    old_snapshot = state.get("snapshot")
    old_head = old_snapshot["pr"]["headRefOid"] if old_snapshot else None
    reaction_ids = codex_reaction_ids(snapshot)
    previous_reaction_ids = codex_reaction_ids(old_snapshot or {})
    if old_head != head or "codexReactionBaseline" not in state:
        baseline = previous_reaction_ids if old_snapshot else reaction_ids
    else:
        baseline = set(state.get("codexReactionBaseline", []))
    passed_for_head = state.get("codexPassedHead") == head or bool(
        reaction_ids - baseline
    )
    passed_at = (
        state.get("codexPassedAt") if state.get("codexPassedHead") == head else None
    )
    if passed_for_head and not passed_at:
        passed_at = now.isoformat()
    interval = 1
    if passed_at:
        approval_age = (now - datetime.fromisoformat(passed_at)).total_seconds()
        if approval_age >= APPROVAL_GRACE_SECONDS:
            interval = 20
    if snapshot["pr"]["isDraft"]:
        interval = 5
    if interval_minutes is not None:
        interval = interval_minutes
    current = events(snapshot, passed_for_head)
    previous = state.get("active", {})
    generation = dict(state.get("generation", {}))
    acknowledged = dict(state.get("acknowledged", {}))
    pending = {}
    for key, event in current.items():
        # Reopening a resolved thread or reappearing failure creates a new occurrence.
        if event["kind"] == "codex_passed":
            generation[key] = 1
        elif key not in previous:
            generation[key] = generation.get(key, 0) + 1
        occurrence = key + ":" + str(generation[key])
        event = dict(event, id=occurrence)
        if occurrence not in acknowledged:
            pending[occurrence] = event
    completed = state.get("completedActions", {})
    if old_snapshot and (
        old_head != head or old_snapshot["pr"]["state"] != snapshot["pr"]["state"]
    ):
        completed = {}
    checked_at = now.isoformat()
    fingerprint = digest(snapshot)
    idle_since = state.get("idleSince") or checked_at
    if (
        fingerprint != state.get("snapshotFingerprint")
        or state.get("lastError")
        or state.get("pending")
        or state.get("recommendedIntervalMinutes") != interval
    ):
        idle_since = checked_at
    eligible = interval == 1 and snapshot["pr"]["state"] == "OPEN" and not pending
    if not eligible:
        idle_since = None
    stop_requested = bool(
        eligible
        and idle_since
        and (now - datetime.fromisoformat(idle_since)).total_seconds()
        >= IDLE_STOP_SECONDS
    )
    return {
        **state,
        "version": 1,
        "snapshot": snapshot,
        "completedActions": completed,
        "snapshotFingerprint": fingerprint,
        "idleSince": idle_since,
        "stopRequested": stop_requested,
        "codexReactionBaseline": sorted(baseline),
        "codexReactionSeen": bool(
            reaction_ids or previous_reaction_ids or state.get("codexReactionSeen")
        ),
        "codexPassedHead": head if passed_for_head else None,
        "codexPassedAt": passed_at if passed_for_head else None,
        "recommendedIntervalMinutes": interval,
        "active": current,
        "generation": generation,
        "acknowledged": acknowledged,
        "pending": pending,
        "lastSuccessAt": checked_at,
        "lastAttemptAt": checked_at,
        "lastError": None,
    }


def plan_actions(state, title=None, current_interval=None, monitor_status="ACTIVE"):
    """Return external operations without performing or acknowledging them."""
    snapshot = state["snapshot"]
    pr = snapshot["pr"]
    actions = []
    if title is not None:
        plain_title = title
        while plain_title.startswith("👍 "):
            plain_title = plain_title.removeprefix("👍 ")
        desired_title = ("👍 " if codex_reaction_ids(snapshot) else "") + plain_title
        if desired_title != title:
            actions.append({"type": "set_title", "title": desired_title})
    elif pr["state"] == "OPEN" and state.get("codexReactionSeen"):
        actions.append(
            {
                "type": "set_title",
                "titlePrefix": "👍 " if codex_reaction_ids(snapshot) else "",
            }
        )
    if pr["state"] != "OPEN":
        if pr["state"] == "MERGED":
            actions.append({"type": "cleanup_worktree"})
        actions.extend(
            [
                {"type": "notify", "message": f"{pr['url']}: {pr['state']}"},
                {"type": "delete_monitor"},
                {"type": "cleanup_state"},
            ]
        )
        return action_receipts(state, actions)
    if monitor_status == "ACTIVE":
        if state["stopRequested"]:
            actions.extend(
                [
                    {"type": "pause_monitor"},
                    {
                        "type": "notify",
                        "message": f"{pr['url']}: 20分間変化なしで監視停止",
                    },
                ]
            )
        elif current_interval != state["recommendedIntervalMinutes"]:
            interval = state["recommendedIntervalMinutes"]
            actions.append(
                {
                    "type": "set_interval",
                    "minutes": interval,
                    "rrule": f"FREQ=MINUTELY;INTERVAL={interval}",
                }
            )
    if monitor_status == "PAUSED" and state["stopRequested"]:
        actions.append(
            {"type": "notify", "message": f"{pr['url']}: 20分間変化なしで監視停止"}
        )
    for event in state["pending"].values():
        if event["kind"] == "codex_passed":
            actions.append(
                {
                    "type": "notify",
                    "message": f"Codexの 👍: {pr['url']} HEAD {event['head']}",
                    "eventId": event["id"],
                }
            )
        else:
            action = {"type": "handle_event", "eventId": event["id"]}
            if event["kind"] == "ci":
                url = (
                    event["check"].get("detailsUrl")
                    or event["check"].get("targetUrl")
                    or ""
                )
                match = re.search(r"/actions/runs/(\d+)", url)
                if match:
                    action["runId"] = int(match[1])
                    action["logArgs"] = ["gh", "run", "view", match[1], "--log-failed"]
            actions.append(action)
    return action_receipts(state, actions)


def action_receipts(state, actions):
    completed = state.get("completedActions", {})
    context = [
        state["snapshot"]["pr"]["headRefOid"],
        state["idleSince"],
        state["snapshot"]["pr"]["state"],
    ]
    result = []
    for action in actions:
        action = dict(action, id=digest([context, action]))
        if (
            action["type"]
            not in {"set_title", "set_interval", "pause_monitor", "handle_event"}
            and action["id"] in completed
        ):
            continue
        result.append(action)
    return result


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


def record_attempt(state, problem, attempt_id, outcome, reason):
    receipts = state.setdefault("attemptReceipts", {}).setdefault(problem, {})
    inputs = {"outcome": outcome, "reason": reason}
    receipt = receipts.get(attempt_id)
    if receipt is not None and receipt != inputs:
        raise ValueError(
            "Attempt ID already recorded with a different outcome or reason"
        )
    attempts = state.setdefault("attempts", {})
    if receipt is None:
        count = attempts.get(problem, {}).get("failures", 0)
        count = count + 1 if outcome == "failed" else 0
        attempts[problem] = {"failures": count, "reason": reason}
        receipts[attempt_id] = inputs
    count = attempts[problem]["failures"]
    return {"status": "hold" if count >= 3 else "continue", "failures": count}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command",
        choices=[
            "check",
            "ack",
            "status",
            "cleanup",
            "complete",
            "attempt",
            "reply",
            "resolve",
        ],
    )
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
    parser.add_argument(
        "--interval-minutes", type=int, help="Actual heartbeat interval"
    )
    parser.add_argument(
        "--reset-idle", action="store_true", help="Reset idle timer on resume"
    )
    parser.add_argument("--title", help="Current chat title")
    parser.add_argument(
        "--current-interval", type=int, help="Current heartbeat interval"
    )
    parser.add_argument(
        "--monitor-status", choices=["ACTIVE", "PAUSED"], default="ACTIVE"
    )
    parser.add_argument(
        "--apply", action="store_true", help="Delete eligible state with cleanup"
    )
    parser.add_argument("--action", help="Action ID returned by check")
    parser.add_argument("--problem", help="Stable problem ID across retries")
    parser.add_argument(
        "--attempt-id", help="Unique trial ID; reuse for command retries"
    )
    parser.add_argument("--outcome", choices=["failed", "succeeded", "reset"])
    parser.add_argument("--body-file", type=Path, help="Review reply text")
    args = parser.parse_args()
    if args.interval_minutes is not None and args.interval_minutes < 1:
        parser.error("Interval must be positive")
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
        if args.command == "complete":
            action = state.get("plannedActions", {}).get(args.action)
            if not action or not args.reason:
                parser.error("complete requires a planned --action and --reason")
            state.setdefault("completedActions", {})[args.action] = args.reason
            event_id = action.get("eventId")
            if event_id and action["type"] == "notify":
                state.setdefault("acknowledged", {})[event_id] = args.reason
                state.get("pending", {}).pop(event_id, None)
            save(path, state)
            print(json.dumps({"status": "completed"}))
            return 0
        if args.command == "attempt":
            if (
                not args.problem
                or not args.attempt_id
                or not args.attempt_id.strip()
                or not args.outcome
                or not args.reason
            ):
                parser.error(
                    "attempt requires --problem, --attempt-id, --outcome and --reason"
                )
            try:
                result = record_attempt(
                    state, args.problem, args.attempt_id, args.outcome, args.reason
                )
            except ValueError as error:
                parser.error(str(error))
            save(path, state)
            print(json.dumps(result))
            return 0
        if args.command in {"reply", "resolve"}:
            event = (
                state.get("pending", {}).get(args.event[0])
                if len(args.event) == 1
                else None
            )
            if not event or event["kind"] != "thread":
                parser.error("reply/resolve requires one pending thread --event")
            thread_id = event["thread"]["id"]
            if args.command == "reply":
                if not args.body_file:
                    parser.error("reply requires --body-file")
                body = args.body_file.read_text()
                result = graphql(
                    "mutation($id:ID!,$body:String!) { addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$id,body:$body}) { comment { id url } } }",
                    id=thread_id,
                    body=body,
                )
            else:
                result = graphql(
                    "mutation($id:ID!) { resolveReviewThread(input:{threadId:$id}) { thread { id isResolved } } }",
                    id=thread_id,
                )
                if not result["resolveReviewThread"]["thread"]["isResolved"]:
                    raise RuntimeError("Thread resolution not confirmed")
            print(json.dumps(result))
            return 0
        if args.command == "cleanup":
            if not path.exists():
                print(json.dumps({"status": "absent", "stateFile": str(path)}))
                return 0
            pending = state.get("pending", {}).values()
            if any(event["kind"] != "terminal" for event in pending):
                print(json.dumps({"status": "retained", "reason": "pending_events"}))
                return 0
            try:
                pr = gh(
                    "pr", "view", str(args.pr), "--repo", args.repo, "--json", "state"
                )
            except (
                RuntimeError,
                subprocess.TimeoutExpired,
                ValueError,
                OSError,
            ) as error:
                print(json.dumps({"status": "error", "error": str(error)}))
                return 1
            if pr.get("state") not in {"MERGED", "CLOSED"}:
                print(
                    json.dumps({"status": "retained", "reason": "pr_open_or_unknown"})
                )
                return 0
            if args.apply:
                path.unlink()
            print(
                json.dumps(
                    {
                        "status": "deleted" if args.apply else "eligible",
                        "stateFile": str(path),
                    }
                )
            )
            return 0
        if args.command == "status":
            print(
                json.dumps(
                    {
                        "stateFile": str(path),
                        "lastSuccessAt": state.get("lastSuccessAt"),
                        "lastError": state.get("lastError"),
                        "pendingCount": len(state.get("pending", {})),
                        "recommendedIntervalMinutes": state.get(
                            "recommendedIntervalMinutes", 1
                        ),
                        "codexReactionPresent": bool(
                            codex_reaction_ids(state.get("snapshot", {}))
                        ),
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
            old_head = state.get("snapshot", {}).get("pr", {}).get("headRefOid")
            if args.reset_idle:
                state["idleSince"] = None
                state["snapshotFingerprint"] = None
            state = update(state, snapshot, interval_minutes=args.interval_minutes)
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
                idleSince=None,
                stopRequested=False,
            )
            save(path, state)
            print(
                json.dumps(
                    {"status": "error", "error": str(error), "stateFile": str(path)}
                )
            )
            return 1
        actions = plan_actions(
            state, args.title, args.current_interval, args.monitor_status
        )
        state["plannedActions"] = {action["id"]: action for action in actions}
        save(path, state)
        pr = snapshot["pr"]
        if pr["state"] != "OPEN":
            status = "terminal"
        elif pr["isDraft"]:
            status = "draft"
        elif state["pending"]:
            status = "action_required"
        else:
            status = "ok"
        print(
            json.dumps(
                {
                    "status": status,
                    "actions": actions,
                    "stopRequested": state["stopRequested"],
                    "head": pr["headRefOid"],
                    "headChanged": bool(old_head and old_head != pr["headRefOid"]),
                    "recommendedIntervalMinutes": state["recommendedIntervalMinutes"],
                    "codexReactionPresent": bool(codex_reaction_ids(snapshot)),
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
