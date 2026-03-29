function h
    set -l brewfile ~/dotfiles/Brewfile
    set -l config ~/dotfiles/config/fish/config.fish
    set -l toolsconf ~/dotfiles/config/fish/tools.conf
    set -l skip_categories Build Misc

    # パッケージ名 -> コマンド名のマッピング (異なるもののみ)
    set -l pkg_map_keys   neovim    ripgrep git-delta
    set -l pkg_map_values nvim      rg      delta

    # alias マップを構築: tool名 -> alias名のリスト
    # "alias cat=bat" -> bat: cat
    # "alias ls=\"eza --icons\"" -> eza: ls
    set -l alias_keys
    set -l alias_values

    for line in (string match -r '^alias \S+=.+' < $config)
        set -l name (string replace -r '^alias (\S+)=.*' '$1' $line)
        set -l target (string replace -r '^alias \S+=["\']?(\S+).*' '$1' $line)
        # sudo 付きの場合
        set target (string replace -r '^sudo ' '' $target)

        set -l found false
        set -l cnt (count $alias_keys)
        if test $cnt -gt 0
            for i in (seq 1 $cnt)
                set -l akey $alias_keys[$i]
                if test "$akey" = "$target"
                    set alias_values[$i] "$alias_values[$i], $name"
                    set found true
                    break
                end
            end
        end
        if test "$found" = false
            set -a alias_keys $target
            set -a alias_values $name
        end
    end

    # tools.conf から追加ツールを読み込み
    set -l extra_categories
    set -l extra_tools
    set -l extra_descs
    if test -f $toolsconf
        while read -l line
            # コメントと空行をスキップ
            if string match -qr '^\s*#|^\s*$' $line
                continue
            end
            set -l parts (string split \t $line)
            if test (count $parts) -ge 2
                set -a extra_categories $parts[1]
                # org/repo からリポジトリ名を取得
                set -a extra_tools (string split '/' $parts[2])[-1]
                if test (count $parts) -ge 3
                    set -a extra_descs $parts[3]
                else
                    set -a extra_descs ""
                end
            end
        end < $toolsconf
    end

    # Brewfile をパースして表示
    set -l current_category ""
    set -l skip false

    while read -l line
        # カテゴリ行
        set -l cat_match (string match -r '# \[(.+)\]' $line)
        if test (count $cat_match) -ge 2
            # 前のカテゴリの追加ツールを出力
            if test -n "$current_category" -a "$skip" = false -a (count $extra_categories) -gt 0
                for i in (seq 1 (count $extra_categories))
                    set -l ecat $extra_categories[$i]
                    if test "$ecat" = "$current_category"
                        set_color yellow
                        printf "    %-28s" $extra_tools[$i]
                        set_color normal
                        printf "%s" $extra_descs[$i]
                        printf "\n"
                    end
                end
            end
            set current_category $cat_match[2]
            set skip false
            for sc in $skip_categories
                if test "$current_category" = "$sc"
                    set skip true
                    break
                end
            end
            if test "$skip" = false
                set_color --bold cyan
                printf "\n  %s:\n" $current_category
                set_color normal
            end
            continue
        end

        # cask セクションに到達したら最後のカテゴリの追加ツールを出力して終了
        if string match -q '# --- cask ---' $line
            if test -n "$current_category" -a "$skip" = false -a (count $extra_categories) -gt 0
                for i in (seq 1 (count $extra_categories))
                    set -l ecat $extra_categories[$i]
                    if test "$ecat" = "$current_category"
                        set_color yellow
                        printf "    %-28s" $extra_tools[$i]
                        set_color normal
                        printf "%s" $extra_descs[$i]
                        printf "\n"
                    end
                end
            end
            break
        end

        if test "$skip" = true
            continue
        end

        # brew行からツール名と説明を抽出
        set -l tool_match (string match -r 'brew "([^"]+)"(?:\s+# (.+))?' $line)
        if test (count $tool_match) -ge 2
            set -l tool $tool_match[2]
            set -l desc ""
            if test (count $tool_match) -ge 3
                set desc $tool_match[3]
            end
            # パス付きの場合は最後の部分を取る (hashicorp/tap/terraform -> terraform)
            set tool (string split '/' $tool)[-1]

            # パッケージ名をコマンド名に変換
            set -l cmd $tool
            for i in (seq 1 (count $pkg_map_keys))
                set -l pkey $pkg_map_keys[$i]
                if test "$pkey" = "$tool"
                    set cmd $pkg_map_values[$i]
                    break
                end
            end

            # alias を探す
            set -l alias_str ""
            for i in (seq (count $alias_keys))
                set -l akey $alias_keys[$i]
                if test "$akey" = "$cmd"
                    set alias_str $alias_values[$i]
                    break
                end
            end

            set_color yellow
            printf "    %-28s" $tool
            set_color normal
            if test -n "$desc"
                printf "%s" $desc
            end
            if test -n "$alias_str"
                set_color --dim
                printf " (alias: %s)" $alias_str
                set_color normal
            end
            printf "\n"
        end
    end < $brewfile
end
