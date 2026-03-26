#!/bin/bash
# tmux copy-pipe 用クリップボードスクリプト
# ローカル: pbcopy、SSH: OSC 52 経由でホスト側クリップボードへ

buf=$(cat)

if [ -z "$SSH_CONNECTION" ]; then
    printf '%s' "$buf" | pbcopy
else
    encoded=$(printf '%s' "$buf" | base64 | tr -d '\n')
    # DCS passthrough で tmux を通過させて Ghostty に OSC 52 を届ける
    printf '\ePtmux;\e\e]52;c;%s\a\e\\' "$encoded" > /dev/tty
fi
