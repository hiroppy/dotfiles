function h
    set -l brewfile ~/dotfiles/Brewfile
    set -l config ~/dotfiles/config/fish/config.fish
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
                if test "$alias_keys[$i]" = "$target"
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

    # Makefile (make tools) からcargoツールを先に収集
    set -l makefile ~/dotfiles/Makefile
    set -l cargo_categories
    set -l cargo_tools
    set -l cargo_descs
    set -l mk_category ""

    while read -l line
        set -l cat_match (string match -r '# \[(.+)\]' $line)
        if test (count $cat_match) -ge 2
            set mk_category $cat_match[2]
            continue
        end
        set -l tool_match (string match -r 'cargo install --git .+/([^/]+)\.git\s+# (.+)' $line)
        if test (count $tool_match) -ge 3
            set -a cargo_categories $mk_category
            set -a cargo_tools $tool_match[2]
            set -a cargo_descs $tool_match[3]
        end
    end < $makefile

    # Brewfile をパースして表示（カテゴリ切り替え時にcargoツールも統合）
    set -l current_category ""
    set -l skip false

    # カテゴリ終了時にcargoツールを出力する関数的処理のため、
    # 全行を読んでからカテゴリ単位で処理
    while read -l line
        # カテゴリ行
        set -l cat_match (string match -r '# \[(.+)\]' $line)
        if test (count $cat_match) -ge 2
            # 前のカテゴリのcargoツールを出力
            if test -n "$current_category" -a "$skip" = false
                for i in (seq 1 (count $cargo_categories))
                    if test "$cargo_categories[$i]" = "$current_category"
                        set_color yellow
                        printf "    %-28s" $cargo_tools[$i]
                        set_color normal
                        printf "%s" $cargo_descs[$i]
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

        # cask セクションに到達したら最後のカテゴリのcargoツールを出力して終了
        if string match -q '# --- cask ---' $line
            if test -n "$current_category" -a "$skip" = false
                for i in (seq 1 (count $cargo_categories))
                    if test "$cargo_categories[$i]" = "$current_category"
                        set_color yellow
                        printf "    %-28s" $cargo_tools[$i]
                        set_color normal
                        printf "%s" $cargo_descs[$i]
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
                if test "$pkg_map_keys[$i]" = "$tool"
                    set cmd $pkg_map_values[$i]
                    break
                end
            end

            # alias を探す
            set -l alias_str ""
            for i in (seq (count $alias_keys))
                if test "$alias_keys[$i]" = "$cmd"
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
