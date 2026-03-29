# delete the greeting message
set fish_greeting

# done: notify after long commands (10s)
set -g __done_min_cmd_duration 10000

# fix for ghostty terminal type (only over SSH)
if set -q SSH_CONNECTION
    set -gx TERM xterm-256color
end

# paths
fish_add_path /opt/homebrew/bin
fish_add_path /usr/local/bin
fish_add_path /usr/local/php5/bin
fish_add_path $HOME/Library/Android/sdk/platform-tools
fish_add_path $HOME/go/bin
fish_add_path $HOME/.deno/bin
fish_add_path $HOME/.cargo/bin
if command -q aqua
    fish_add_path (aqua root-dir)
end

# set empty defaults to avoid .npmrc errors when .env is missing
set -gx NPM_TOKEN ""
set -gx GITHUB_TOKEN ""

envsource ~/.env

# init
# don't move before paths
init

# alias

alias ..="cd .."
alias g=git
alias d=docker
alias dc="docker compose"
alias vi=nvim
alias vim=nvim
alias cat=bat
alias top=btop
alias ps=procs
alias a="./a.out"
alias bc="bc -l"
alias open="open ."
alias localip="ipconfig getifaddr en0"
# Show active network interfaces
alias ifactive="ifconfig | pcregrep -M -o '^[^\t:]+:([^\n]|\n\t)*status: active'"
# for presentation
alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"
alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
# reftesh LaunchPad
alias refresh-launchpad="defaults write com.apple.dock ResetLaunchPad -bool true && killall Dock"
alias repo="gh browse"
alias q="exit"
alias find=fd
alias grep=rg
alias ping=gping
alias bandwhich="sudo bandwhich"
set -gx EZA_CONFIG_DIR ~/.config/eza

# fzf.fish (PatrickF1/fzf.fish)
set fzf_preview_dir_cmd eza --all --color=always --icons
set fzf_diff_highlighter delta --paging=never --width=20
alias ls="eza --icons"
alias ll="eza --icons -l"
alias la="eza --icons -la"
alias tree="eza --icons --tree"


function ts
    if test (count $argv) -eq 0
        set -f name (basename $PWD)
    else
        set -f name $argv[1]
    end
    if set -q SSH_CONNECTION
        # SSH時は main セッション内でwindowとして管理
        if set -q TMUX
            tmux new-window -n $name -c $PWD
        else if tmux has-session -t main 2>/dev/null
            tmux attach -t main \; new-window -n $name -c $PWD
        else
            tmux new -s main -n $name -c $PWD
        end
    else
        if tmux has-session -t $name 2>/dev/null
            tmux attach -t $name
        else
            tmux new -s $name
        end
    end
end
function __tmux_auto_attach --on-variable PWD
    if set -q TMUX
        return
    end
    if set -q SSH_CONNECTION
        # SSH時: mainセッションがあればattach
        if tmux has-session -t main 2>/dev/null
            tmux attach -t main
        end
    else
        # ローカル: 同名セッションがあればattach
        set -l name (basename $PWD)
        if tmux has-session -t $name 2>/dev/null
            tmux attach -t $name
        end
    end
end
# SSH時に自動でmainセッションに入る
if set -q SSH_CONNECTION; and not set -q TMUX; and status is-interactive
    if tmux has-session -t main 2>/dev/null
        exec tmux attach -t main
    else
        exec tmux new -s main
    end
end


alias tls="tmux ls"
alias td="tmux detach"
alias tks="tmux kill-server"

# git

set __fish_git_prompt_showdirtystate yes
set __fish_git_prompt_showuntrackedfiles yes
set __fish_git_prompt_showupstream informative
set __fish_git_prompt_showstashstate yes
set __fish_git_prompt_describe_style branch
set __fish_git_prompt_show_informative_status
set __fish_git_prompt_showcolorhints

set __fish_git_prompt_color_branch 83A9FB
set __fish_git_prompt_color_merging yellow

set __fish_git_prompt_char_stateseparator '|'

set __fish_git_prompt_char_cleanstate ' ✔ '
set __fish_git_prompt_color_cleanstate 62CB7D

set __fish_git_prompt_char_conflictedstate ' ✘ '
set __fish_git_prompt_color_conflictedstate A765AE

set __fish_git_prompt_char_dirtystate ' 🎃 '
set __fish_git_prompt_color_dirtystate ff9248

set __fish_git_prompt_char_invalidstate ' 🤮 '
set __fish_git_prompt_color_invalidstate red

set __fish_git_prompt_char_stagedstate ' 📮 '
set __fish_git_prompt_color_stagedstate yellow

set __fish_git_prompt_char_stashstate ' 📦 '

set __fish_git_prompt_char_untrackedfiles ' 🏷  '

set __fish_git_prompt_char_upstream_ahead ' 👆 '
set __fish_git_prompt_color_upstream_ahead green

set __fish_git_prompt_char_upstream_behind ' 👇 '
set __fish_git_prompt_color_upstream_behind red

set __fish_git_prompt_char_upstream_diverged ' 🚧 '

set __fish_git_prompt_char_upstream_equal ' 🤝 '

# overwrite settings that cannot be published
# need to create secret.fish to functions dir
# if test -e $fisher_path/functions/secret.fish
#     secret
# end

# pnpm
# set -gx PNPM_HOME $HOME/Library/pnpm
# if not string match -q -- $PNPM_HOME $PATH
#     set -gx PATH "$PNPM_HOME" $PATH
# end
# pnpm end

# bun
set -gx BUN_INSTALL "$HOME/.bun"
fish_add_path $BUN_INSTALL/bin

# aqua
if command -q aqua
    set -gx AQUA_GLOBAL_CONFIG $HOME/.config/aquaproj-aqua/aqua.yaml
end

# mise
/opt/homebrew/bin/mise activate fish | source

# LM Studio CLI (lms)
fish_add_path $HOME/.lmstudio/bin
