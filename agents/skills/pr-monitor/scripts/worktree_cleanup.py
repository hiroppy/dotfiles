"""Validate and resume cleanup of one merged PR worktree without force-removing files."""

import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

SHARED_MOUNT_PROCESS = (
    "/System/Library/Frameworks/Virtualization.framework/Versions/A/XPCServices/"
    "com.apple.Virtualization.VirtualMachine.xpc/Contents/MacOS/"
    "com.apple.Virtualization.VirtualMachine"
)


def git(repository, *args):
    result = subprocess.run(
        ["git", "-C", str(repository), *args],
        capture_output=True,
        text=True,
        timeout=120,
        check=False,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Git operation failed")
    return result.stdout.strip()


def worktrees(repository):
    output = git(repository, "worktree", "list", "--porcelain", "-z")
    result = []
    for record in output.split("\0\0"):
        fields = {}
        for line in record.split("\0"):
            key, _, value = line.partition(" ")
            if key:
                fields[key] = value
        if "worktree" in fields:
            result.append(fields)
    return result


def process_blockers(worktree):
    try:
        result = subprocess.run(
            ["lsof", "-Fpfa", "+D", str(worktree)],
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ["process_state_unknown"]
    if result.stderr.strip() or result.returncode not in {0, 1}:
        return ["process_state_unknown"]
    processes = {}
    files = None
    for line in result.stdout.splitlines():
        field, value = line[:1], line[1:]
        if field == "p":
            if not value.isdigit():
                return ["process_state_unknown"]
            files = processes.setdefault(value, [])
        elif field == "f":
            if files is None:
                return ["process_state_unknown"]
            files.append({"descriptor": value, "access": None})
        elif field == "a":
            if not files:
                return ["process_state_unknown"]
            files[-1]["access"] = value
    if result.stdout.strip() and not processes:
        return ["process_state_unknown"]
    for pid, files in processes.items():
        try:
            process = subprocess.run(
                ["ps", "-p", pid, "-o", "comm="],
                capture_output=True,
                text=True,
                timeout=10,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            return ["process_state_unknown"]
        if process.returncode or process.stderr.strip() or not process.stdout.strip():
            return ["process_state_unknown"]
        # The host VM keeps shared directories open even with no guest workload.
        # Actual container/task use is checked separately through inUse evidence.
        if process.stdout.strip() != SHARED_MOUNT_PROCESS:
            return ["active_processes"]
        if not files:
            return ["process_state_unknown"]
        if any(
            not re.fullmatch(r"\*?\d+", file["descriptor"]) or file["access"] != "r"
            for file in files
        ):
            return ["active_processes"]
    return []


def ownership_blockers(worktree, ownership_file):
    if not ownership_file:
        return ["ownership_unknown"], False
    evidence = json.loads(ownership_file.read_text())
    if Path(evidence["worktree"]).resolve() != worktree:
        raise RuntimeError("Ownership evidence names another worktree")
    observed = datetime.fromisoformat(evidence["observedAt"])
    if observed.tzinfo is None:
        raise RuntimeError("Ownership observation requires a timezone")
    age = (datetime.now(timezone.utc) - observed).total_seconds()
    blockers = []
    if age < 0 or age > 60:
        blockers.append("ownership_evidence_stale")
    for field in ("shared", "inUse"):
        if evidence.get(field) is not False:
            blockers.append("worktree_" + field)
    if evidence.get("pinned") is True:
        blockers.append("worktree_pinned")
    # Missing app metadata is not evidence of an app-protected worktree.
    return blockers, evidence.get("managed")


def cleanup_worktree(
    state,
    state_path,
    repo,
    number,
    repository,
    worktree,
    branch,
    ownership_file,
    apply,
    gh,
    save,
):
    repository = repository.resolve()
    if worktree.is_symlink():
        raise RuntimeError("Refusing a symlink worktree path")
    worktree = worktree.resolve()
    if repository == worktree or repository.is_relative_to(worktree):
        raise RuntimeError("Cleanup must run through a separate repository checkout")
    remote = git(repository, "remote", "get-url", "origin")
    if not re.search(
        r"[:/]" + re.escape(repo) + r"(?:\.git)?/?$", remote, re.IGNORECASE
    ):
        raise RuntimeError("Repository remote does not match the PR")
    pr = gh(
        "pr",
        "view",
        str(number),
        "--repo",
        repo,
        "--json",
        "state,headRefOid,headRefName",
    )
    if pr["state"] != "MERGED":
        return {"status": "retained", "blockingReasons": ["pr_not_merged"]}
    if branch != pr["headRefName"] or branch in {"main", "master"}:
        raise RuntimeError("Cleanup branch does not match the merged PR branch")
    default = git(
        repository, "for-each-ref", "--format=%(symref)", "refs/remotes/origin/HEAD"
    )
    if default == "refs/remotes/origin/" + branch:
        raise RuntimeError("Refusing cleanup of the remote default branch")
    receipts = state.setdefault("worktreeCleanups", {})
    key = str(worktree)
    receipt = receipts.get(key)
    binding = {
        "repository": str(repository),
        "worktree": key,
        "branch": branch,
        "head": pr["headRefOid"],
    }
    if receipt and any(receipt[field] != value for field, value in binding.items()):
        raise RuntimeError("Cleanup retry target changed")
    entries = worktrees(repository)
    target = next(
        (entry for entry in entries if Path(entry["worktree"]).resolve() == worktree),
        None,
    )
    if entries and Path(entries[0]["worktree"]).resolve() == worktree:
        raise RuntimeError("Refusing cleanup of the primary worktree")
    blockers, managed = ownership_blockers(worktree, ownership_file)
    if Path.cwd().resolve().is_relative_to(worktree):
        blockers.append("current_worktree")
    if target:
        if "locked" in target or "prunable" in target:
            blockers.append("locked_or_prunable")
        if (
            target.get("branch") != "refs/heads/" + branch
            or target.get("HEAD") != pr["headRefOid"]
        ):
            blockers.append("worktree_head_changed")
        if git(worktree, "status", "--porcelain", "--untracked-files=all", "--ignored"):
            blockers.append("local_files_present")
        blockers.extend(process_blockers(worktree))
        common = git(
            worktree, "rev-parse", "--path-format=absolute", "--git-common-dir"
        )
        if common != git(
            repository, "rev-parse", "--path-format=absolute", "--git-common-dir"
        ):
            raise RuntimeError("Worktree belongs to another repository")
    elif worktree.exists():
        blockers.append("unregistered_path_present")
    elif not receipt:
        # Without a saved binding, an absent path is not evidence of prior cleanup.
        blockers.append("cleanup_binding_missing")
    branch_tip = git(
        repository, "for-each-ref", "--format=%(objectname)", "refs/heads/" + branch
    )
    if branch_tip and branch_tip != pr["headRefOid"]:
        blockers.append("branch_head_changed")
    if any(
        entry.get("branch") == "refs/heads/" + branch and entry is not target
        for entry in entries
    ):
        blockers.append("branch_in_use")
    if blockers:
        return {"status": "retained", "blockingReasons": sorted(set(blockers))}
    if receipt and receipt.get("completed") and (target or branch_tip):
        return {"status": "retained", "blockingReasons": ["cleanup_target_recreated"]}
    if not apply:
        return {"status": "eligible", **binding, "managed": managed}
    # Process/Git checks may take time; do not act on the earlier cached evidence.
    blockers, managed = ownership_blockers(worktree, ownership_file)
    if blockers:
        return {"status": "retained", "blockingReasons": sorted(set(blockers))}
    receipt = receipts.setdefault(key, binding)
    save(state_path, state)
    if target and managed is True:
        return {
            "status": "archive_required",
            "worktree": key,
            "operation": "archive_worktree",
        }
    if target:
        git(repository, "worktree", "remove", str(worktree))
    if worktree.exists() or any(
        Path(entry["worktree"]).resolve() == worktree for entry in worktrees(repository)
    ):
        raise RuntimeError("Worktree removal not confirmed")
    # Recheck the branch after removal before deleting it, including after interrupted cleanup.
    tip = git(
        repository, "for-each-ref", "--format=%(objectname)", "refs/heads/" + branch
    )
    if tip:
        if tip != receipt["head"] or any(
            entry.get("branch") == "refs/heads/" + branch
            for entry in worktrees(repository)
        ):
            raise RuntimeError("Branch changed or is in use after worktree removal")
        # PR merge + exact pushed HEAD establish safety even for squash merges.
        git(repository, "update-ref", "-d", "refs/heads/" + branch, receipt["head"])
    if git(
        repository, "for-each-ref", "--format=%(objectname)", "refs/heads/" + branch
    ):
        raise RuntimeError("Branch deletion not confirmed")
    receipt["completed"] = True
    save(state_path, state)
    return {"status": "completed", "worktree": key, "branch": branch}
