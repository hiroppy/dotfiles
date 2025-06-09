function wt
    set -l cmd $argv[1]
    
    if test -z "$cmd"
        # Show worktree list with fzf
        set -l selected (git worktree list | fzf \
            --preview-window="right:70%:wrap" \
            --preview='
                worktree_path=$(echo {} | awk "{print \$1}")
                branch=$(echo {} | sed "s/.*\[//" | sed "s/\]//")
                
                echo "┌──────────────────────────────────────────────────┐"
                echo "│ 🌳 Branch: $branch"
                echo "└──────────────────────────────────────────────────┘"
                echo ""
                echo "📁 Path: $worktree_path"
                echo ""
                echo "📝 Changed files:"
                echo "───────────────────────────────────────────────────"
                changes=$(git -C "$worktree_path" status --porcelain 2>/dev/null)
                if [ -z "$changes" ]; then
                    echo "  ✨ Working tree clean"
                else
                    echo "$changes" | head -10 | while read line; do
                        file_status=$(echo "$line" | cut -c1-2)
                        file_name=$(echo "$line" | cut -c4-)
                        case "$file_status" in
                            "M "*) echo "  🔧 Modified: $file_name";;
                            "A "*) echo "  ➕ Added: $file_name";;
                            "D "*) echo "  ➖ Deleted: $file_name";;
                            "??"*) echo "  ❓ Untracked: $file_name";;
                            *) echo "  📄 $line";;
                        esac
                    done
                fi
                echo ""
                echo "📜 Recent commits:"
                echo "───────────────────────────────────────────────────"
                git -C "$worktree_path" log --oneline --color=always -10 2>/dev/null | sed "s/^/  /"
            ' \
            --header="🌲 Git Worktree Manager | Press Enter to navigate" \
            --border \
            --height=80% \
            --layout=reverse \
            --prompt="🔍 " | awk '{print $1}'
        )
        
        if test -n "$selected"
            cd $selected
        end
        
    else if test "$cmd" = "add"
        set -l branch_name $argv[2]
        
        if test -z "$branch_name"
            echo "Usage: wt add <branch_name>"
            return 1
        end
        
        # Get git directory
        set -l git_dir (git rev-parse --git-dir 2>/dev/null)
        if test -z "$git_dir"
            echo "Not in a git repository"
            return 1
        end
        
        # Create tmp_worktrees directory if it doesn't exist
        set -l tmp_worktrees_dir "$git_dir/tmp_worktrees"
        if not test -d "$tmp_worktrees_dir"
            mkdir -p "$tmp_worktrees_dir"
        end
        
        # Generate directory name with timestamp
        set -l timestamp (date +"%Y%m%d_%H%M%S")
        set -l dir_name "$timestamp"_"$branch_name"
        set -l worktree_path "$tmp_worktrees_dir/$dir_name"
        
        # Create new branch and worktree
        git worktree add -b "$branch_name" "$worktree_path"
        
        if test $status -eq 0
            echo "Created worktree at: $worktree_path"
            echo "Branch: $branch_name"
            cd "$worktree_path"
        end
        
    else if test "$cmd" = "remove"
        set -l branch_name $argv[2]
        
        if test -z "$branch_name"
            echo "Usage: wt remove <branch_name>"
            return 1
        end
        
        # Find worktree path by branch name
        set -l worktree_info (git worktree list | grep "\[$branch_name\]")
        
        if test -z "$worktree_info"
            echo "No worktree found for branch: $branch_name"
            return 1
        end
        
        set -l worktree_path (echo $worktree_info | awk '{print $1}')
        
        # Remove worktree
        git worktree remove --force "$worktree_path"
        
        if test $status -eq 0
            # Delete branch
            git branch -D "$branch_name"
            echo "Removed worktree and branch: $branch_name"
        end
        
    else
        echo "Unknown command: $cmd"
        echo "Usage:"
        echo "  wt              - Show worktree list with fzf"
        echo "  wt add <branch> - Create new branch and worktree"
        echo "  wt remove <branch> - Remove worktree and branch"
        return 1
    end
end