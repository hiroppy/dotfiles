#!/bin/bash
# tmux mock for bats tests
# Stores pane options in a temp directory as flat files.

export TMUX_MOCK_DIR=""

mock_setup() {
    TMUX_MOCK_DIR="$(mktemp -d)"
    export TMUX_MOCK_DIR
    export TMUX_PANE="%0"
    # Put mock tmux ahead of real tmux in PATH
    mkdir -p "$TMUX_MOCK_DIR/bin"
    cat > "$TMUX_MOCK_DIR/bin/tmux" <<'MOCK'
#!/bin/bash
set -euo pipefail

STORE="$TMUX_MOCK_DIR/store"
mkdir -p "$STORE"

pane_file() {
    local pane="${1:-$TMUX_PANE}"
    echo "$STORE/${pane//%/_}"
}

do_set() {
    local target="$TMUX_PANE" unset_flag=false key="" value=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -t) shift; target="$1" ;;
            -p) ;;
            -u) unset_flag=true ;;
            @*) key="$1" ;;
            *)  value="$1" ;;
        esac
        shift
    done
    local file
    file="$(pane_file "$target")"
    if $unset_flag; then
        if [ -f "$file" ]; then
            local tmp
            tmp="$(grep -v "^${key}=" "$file" 2>/dev/null || true)"
            printf '%s\n' "$tmp" > "$file"
        fi
    else
        if [ -f "$file" ]; then
            local tmp
            tmp="$(grep -v "^${key}=" "$file" 2>/dev/null || true)"
            printf '%s\n' "$tmp" > "$file"
        fi
        echo "${key}=${value}" >> "$file"
    fi
}

do_display_message() {
    local target="$TMUX_PANE" format=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -t) shift; target="$1" ;;
            -p) ;;
            *)  format="$1" ;;
        esac
        shift
    done
    local file
    file="$(pane_file "$target")"
    if [ -f "$file" ]; then
        local result="$format"
        while IFS='=' read -r k v; do
            [ -z "$k" ] && continue
            result="${result//\#\{$k\}/$v}"
        done < "$file"
        printf '%s' "$result"
    else
        printf '%s' "$format"
    fi
}

do_show() {
    local target="$TMUX_PANE" key=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -t) shift; target="$1" ;;
            -p|-pv) ;;
            @*) key="$1" ;;
            *)  ;;
        esac
        shift
    done
    local file
    file="$(pane_file "$target")"
    if [ -f "$file" ] && [ -n "$key" ]; then
        grep "^${key}=" "$file" 2>/dev/null | head -1 | cut -d= -f2- || true
    fi
}

cmd="$1"; shift

case "$cmd" in
    set) do_set "$@" ;;
    display-message) do_display_message "$@" ;;
    show) do_show "$@" ;;
    list-panes)
        [ -n "${TMUX_MOCK_LIST_PANES:-}" ] && printf '%s\n' "$TMUX_MOCK_LIST_PANES"
        ;;
    list-sessions)
        [ -n "${TMUX_MOCK_LIST_SESSIONS:-}" ] && printf '%s\n' "$TMUX_MOCK_LIST_SESSIONS"
        ;;
    list-windows)
        [ -n "${TMUX_MOCK_LIST_WINDOWS:-}" ] && printf '%s\n' "$TMUX_MOCK_LIST_WINDOWS"
        ;;
    *) ;;
esac
MOCK
    chmod +x "$TMUX_MOCK_DIR/bin/tmux"
    export PATH="$TMUX_MOCK_DIR/bin:$PATH"
}

mock_teardown() {
    [ -n "$TMUX_MOCK_DIR" ] && rm -rf "$TMUX_MOCK_DIR"
}

# Read a pane option from the mock store
mock_get_option() {
    local pane="${1:-$TMUX_PANE}"
    local key="$2"
    local file="$TMUX_MOCK_DIR/store/${pane//%/_}"
    [ -f "$file" ] || return 0
    grep "^${key}=" "$file" 2>/dev/null | head -1 | cut -d= -f2-
}

# Check a pane option is unset in the mock store
mock_option_unset() {
    local pane="${1:-$TMUX_PANE}"
    local key="$2"
    local file="$TMUX_MOCK_DIR/store/${pane//%/_}"
    [ ! -f "$file" ] && return 0
    ! grep -q "^${key}=" "$file" 2>/dev/null
}
