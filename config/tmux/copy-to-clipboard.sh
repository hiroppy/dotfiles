#!/bin/bash
# tmux copy-pipe 用クリップボードスクリプト
# ローカル: pbcopy、SSH: OSC 52 経由でホスト側クリップボードへ

buf=$(cat)

if [ -z "$SSH_CONNECTION" ]; then
    printf '%s' "$buf" | pbcopy
else
    encoded=$(printf '%s' "$buf" | base64 | tr -d '\n')
    # popup内ではメインクライアントのTTYを探して直接 OSC 52 を送る
    my_tty=$(tmux display-message -p '#{client_tty}')
    main_tty=$(tmux list-clients -F '#{client_tty}' | grep -v "$my_tty" | head -1)
    if [ -n "$main_tty" ]; then
        printf '\e]52;c;%s\a' "$encoded" > "$main_tty"
    else
        # popup外（通常pane）の場合はそのまま送る
        printf '\e]52;c;%s\a' "$encoded" > /dev/tty
    fi
fi
