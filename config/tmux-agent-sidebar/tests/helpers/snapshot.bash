#!/bin/bash
# Snapshot testing helper for bats
# Compares render output (ANSI-stripped) against .expected files in snapshots/

SNAPSHOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../shell-snapshots" && pwd)"

strip_ansi() {
    sed $'s/\033[[][0-9;]*m//g' | sed $'s/\033[[]K//g' | sed $'s/\033[[][0-9;]*H//g' | sed $'s/\033[[]J//g' | sed $'s/\033[[]?[0-9]*[hl]//g'
}

# Compare output against a snapshot file
# Usage: assert_snapshot "snapshot_name" "$output"
# On first run (no snapshot file), creates the snapshot and passes.
# On subsequent runs, diffs against saved snapshot.
assert_snapshot() {
    local name="$1"
    local actual="$2"
    local snapshot_file="$SNAPSHOT_DIR/${name}.expected"

    # Strip ANSI, normalize paths, and trim trailing whitespace
    local cleaned
    cleaned="$(printf '%s' "$actual" | strip_ansi | sed "s|$HOME|~|g" | sed 's/[[:space:]]*$//')"

    if [ ! -f "$snapshot_file" ]; then
        printf '%s\n' "$cleaned" > "$snapshot_file"
        echo "Snapshot created: $snapshot_file"
        return 0
    fi

    local expected
    expected="$(cat "$snapshot_file")"

    if [ "$cleaned" != "$expected" ]; then
        echo "Snapshot mismatch: $name"
        echo "--- expected ---"
        printf '%s\n' "$expected"
        echo "--- actual ---"
        printf '%s\n' "$cleaned"
        echo "--- diff ---"
        diff <(printf '%s\n' "$expected") <(printf '%s\n' "$cleaned") || true
        return 1
    fi

    return 0
}
