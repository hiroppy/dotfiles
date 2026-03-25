#!/bin/bash
# tmux.confから自分が設定したキーバインドを見やすく表示する

TMUX_CONF="${HOME}/.config/tmux/tmux.conf"

printf "\033[1;36m%-20s %-10s %s\033[0m\n" "Key" "Mode" "Description"
printf "%-20s %-10s %s\n" "--------------------" "----------" "----------------------------------------"

prev_comment=""
while IFS= read -r line; do
  stripped=$(echo "$line" | sed 's/^[[:space:]]*//')

  # コメント行を記憶
  if echo "$stripped" | grep -q '^#'; then
    prev_comment=$(echo "$stripped" | sed 's/^#[[:space:]]*//')
    continue
  fi

  # bind行以外はスキップ
  if ! echo "$stripped" | grep -q '^bind'; then
    prev_comment=""
    continue
  fi

  # bind-key -> bind に正規化して解析
  normalized=$(echo "$stripped" | sed 's/^bind-key/bind/')

  key=""
  mode=""
  action=""

  if echo "$normalized" | grep -q -- '-T copy-mode-vi'; then
    mode="copy-vi"
    rest=$(echo "$normalized" | sed 's/.*-T copy-mode-vi //')
    key=$(echo "$rest" | awk '{print $1}')
    action=$(echo "$rest" | awk '{$1=""; print $0}' | sed 's/^[[:space:]]*//')
  elif echo "$normalized" | grep -q -- '-T copy-mode '; then
    mode="copy"
    rest=$(echo "$normalized" | sed 's/.*-T copy-mode //')
    key=$(echo "$rest" | awk '{print $1}')
    action=$(echo "$rest" | awk '{$1=""; print $0}' | sed 's/^[[:space:]]*//')
  elif echo "$normalized" | grep -q -- 'bind -n '; then
    mode="root"
    rest=$(echo "$normalized" | sed 's/.*bind -n //')
    key=$(echo "$rest" | awk '{print $1}')
    action=$(echo "$rest" | awk '{$1=""; print $0}' | sed 's/^[[:space:]]*//')
  else
    mode="prefix"
    rest=$(echo "$normalized" | sed 's/^bind \(-r \)*//')
    key=$(echo "$rest" | awk '{print $1}')
    action=$(echo "$rest" | awk '{$1=""; print $0}' | sed 's/^[[:space:]]*//')
  fi

  # コメントがあればそれを説明として使う
  if [ -n "$prev_comment" ]; then
    desc="$prev_comment"
  else
    desc="$action"
  fi

  printf "%-20s %-10s %s\n" "$key" "$mode" "$desc"
  prev_comment=""
done < "$TMUX_CONF"
