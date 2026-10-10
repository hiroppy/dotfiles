"""Select and gate the next operation from the saved check plan."""


def pending_actions(state):
    for action in state.get("plannedActions", {}).values():
        if action["id"] in state.get("completedActions", {}):
            continue
        if action["type"] == "set_title" and action["id"] in state.get(
            "deferredTitles", {}
        ):
            continue
        if action["type"] == "handle_event" and action["eventId"] not in state.get(
            "pending", {}
        ):
            continue
        if state.get("once") and action["type"] == "set_interval":
            continue
        if state.get("executionMode") == "direct" and action["type"] in {
            "set_interval",
            "pause_monitor",
            "delete_monitor",
        }:
            continue
        delivery = state.get("notificationDeliveries", {}).get(action["id"])
        if action["type"] == "notify" and delivery and delivery["status"] != "not_sent":
            action = {**action, "type": "reconcile_notification"}
        yield action


def require_turn(state, action_id):
    if state.get("lastError"):
        raise RuntimeError("Last check failed; run check before continuing")
    action = next(pending_actions(state), None)
    if not action or action["id"] != action_id:
        raise RuntimeError("Operation is out of order; run next for the current step")
    return action


def require_type(state, action_type):
    if state.get("lastError"):
        raise RuntimeError("Last check failed; run check before continuing")
    # Legacy states without a saved plan retain their standalone command behavior.
    if "plannedActions" not in state:
        return
    if any(
        action["type"] == action_type
        and action["id"] in state.get("completedActions", {})
        for action in state["plannedActions"].values()
    ):
        return
    action = next(pending_actions(state), None)
    if not action or action["type"] != action_type:
        raise RuntimeError("Operation is out of order; run next for the current step")


def next_step(state, command):
    if "plannedActions" not in state or state.get("lastError"):
        return {
            "status": "check_required",
            "canEndTurn": False,
            "command": command("check"),
        }
    action = next(pending_actions(state), None)
    if action:
        return action_step(state, action, command)
    finished = bool(
        state["snapshot"]["pr"]["state"] != "OPEN"
        or state.get("monitorStatus") == "PAUSED"
        or state.get("stopRequested")
        or state.get("once")
    )
    minutes = state["recommendedIntervalMinutes"]
    return {
        "status": "finished" if finished else "continue_required",
        "canEndTurn": finished,
        "minutes": minutes,
        "waitSeconds": minutes * 60,
        "command": None if finished else command("check"),
        "instruction": None
        if finished
        else "Wait minutes and run command again; do not end the turn.",
    }


def action_step(state, action, command):
    kind = action["type"]
    result = {
        "status": "action_required",
        "canEndTurn": False,
        "action": action,
    }
    if kind in {"notify", "reconcile_notification"}:
        result.update(
            command=command("prepare-notification", "--action", action["id"]),
            outcomes={
                outcome: command(
                    "notification-result",
                    "--action",
                    action["id"],
                    "--outcome",
                    outcome,
                    "--reason",
                    "<delivery evidence>",
                )
                for outcome in ("succeeded", "not_sent", "unknown")
            },
            dispatchOnlyOn="dispatch",
            evidenceRequired=True,
            retry="Reconcile delivery_unknown; never resend without evidence of not_sent.",
        )
    elif kind == "cleanup_state":
        result["command"] = command("cleanup", "--apply")
        result["completeOn"] = ["deleted", "absent"]
    elif kind == "cleanup_worktree":
        result.update(
            command=command(
                "cleanup-worktree",
                "--repository",
                "<separate checkout>",
                "--worktree",
                "<associated worktree>",
                "--branch",
                "<PR branch>",
                "--ownership-file",
                "<evidence JSON>",
                "--apply",
            ),
            requiredEvidence={
                "worktree": "absolute path",
                "observedAt": "timezone-qualified ISO timestamp, at most 60 seconds old",
                "shared": False,
                "pinned": "observed boolean or null if app metadata is unavailable",
                "inUse": False,
                "managed": "true only when app-managed is confirmed; false or null otherwise",
            },
            retry="archive_required: archive through the owner, refresh evidence, retry the same target. retained/error: stop and report.",
            completeOn="completed",
            completion=command(
                "complete", "--action", action["id"], "--reason", "<cleanup result>"
            ),
        )
    elif kind == "handle_event":
        event = state["pending"][action["eventId"]]
        result.update(event=event, command=None)
        result["completion"] = command(
            "ack",
            "--event",
            event["id"],
            "--reason",
            "<verified outcome, unnecessary or hold reason>",
        )
        result["requirements"] = {
            "ci": [
                "Inspect failed logs",
                "Fix, simplify once, verify, commit/push",
                "Record each actual trial with attempt; stop on hold",
            ],
            "conflict": [
                "Fetch base and merge normally; never rebase/force push",
                "Verify and push, or abort and report uncertainty",
            ],
            "comment": [
                "Evaluate all authors including self",
                "Fix and verify, reply if needed, or record unnecessary/hold reason",
            ],
            "review": [
                "Evaluate review body and chronology",
                "Fix and verify, reply if needed, or record unnecessary/hold reason",
            ],
            "thread": [
                "Evaluate thread chronology",
                "After fixing and pushing, check for the current HEAD event",
                "Use finish-review to reply, resolve and ack; held/disputed threads must remain unresolved",
            ],
        }[event["kind"]]
        if event["kind"] == "thread":
            result["resolvedCompletion"] = command(
                "finish-review",
                "--event",
                event["id"],
                "--body-file",
                "<reply file>",
                "--reason",
                "<commit and verification>",
            )
        if "logArgs" in action:
            result["logCommand"] = action["logArgs"]
        result["retry"] = (
            "Reuse saved operation IDs and original inputs; reassess changed HEAD/comments. Stop after 3 failures or 2 rounds of deadlocked review."
        )
    else:
        result.update(
            command=None,
            executor="environment",
            evidenceRequired=True,
            completion=command(
                "complete",
                "--action",
                action["id"],
                "--reason",
                "<verified result or evidence that integration is unused>",
            ),
            retry="Read current integration state, apply the desired state, verify. If usage is unknown or execution fails, do not complete.",
        )
        if kind == "set_title":
            result["operation"] = "set_thread_title"
            result["optional"] = True
            result["onFailure"] = command(
                "defer-title",
                "--action",
                action["id"],
                "--reason",
                "<title sync failure or unavailable tool>",
            )
            result["retry"] = (
                "Try title synchronization once. If unavailable or failed, run onFailure and continue monitoring without user confirmation; retry on the next check."
            )
            result["requirements"] = [
                "Read the current chat title; change the chat, not the GitHub PR title.",
                "If titlePrefix is provided, remove repeated leading 👍 prefixes and apply titlePrefix to the remaining title.",
                "Use the environment's thread title tool (set_thread_title in Codex), then verify the title.",
                "A missing tool is not evidence that title integration is unused; investigate before completing or skipping.",
            ]
    return result
