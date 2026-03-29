function notify -d "Send notification (ntfy over SSH, osascript locally)"
    argparse 't/title=' 's/sound=' -- $argv

    set -l title "通知"
    if set -q _flag_title
        set title $_flag_title
    end

    set -l sound "Hero"
    if set -q _flag_sound
        set sound $_flag_sound
    end

    set -l msg (string join " " $argv)
    if test -z "$msg"
        set msg "完了しました"
    end

    if set -q SSH_CONNECTION; and set -q NTFY_TOKEN; and set -q NTFY_TOPIC
        curl -s -H "Authorization: Bearer $NTFY_TOKEN" -H "Title: $title" -d "$msg" "ntfy.sh/$NTFY_TOPIC" &
    else
        osascript -e "display notification \"$msg\" with title \"$title\" sound name \"$sound\""
    end
end
