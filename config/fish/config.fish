# delete the greeting message
set fish_greeting

# paths
# don't use fish_user_paths
# if you use fish_user_paths, fish_variables will be overwritten

set PATH \
    /usr/sbin \
    /usr/local/bin \
    /usr/local/php5/bin \
    $HOME/.nodebrew/current/bin \
    $HOME/Library/Android/sdk/platform-tools \
    $HOME/go \
    $HOME/.deno/bin \
    $HOME/.rbenv/shims \
    $HOME/.pyenv/shims \
    $PATH

# init
# don't move before paths

init

# alias

alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias g=git
alias d=docker
alias dc=docker-compose
alias vi=nvim
alias vim=nvim
alias a="./a.out"
alias bc="bc -l"
alias open="open ."
alias git=hub
alias tfind="find ./ -type f -print | xargs grep"
alias localip="ipconfig getifaddr en0"
# Show active network interfaces
alias ifactive="ifconfig | pcregrep -M -o '^[^\t:]+:([^\n]|\n\t)*status: active'"
# for presentation
alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"
alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
# reftesh LaunchPad
alias refresh-launchpad="defaults write com.apple.dock ResetLaunchPad -bool true && killall Dock"

# git

set __fish_git_prompt_showdirtystate 'yes'
set __fish_git_prompt_showuntrackedfiles 'yes'
set __fish_git_prompt_showupstream 'informative'
set __fish_git_prompt_showstashstate 'yes'
set __fish_git_prompt_describe_style 'branch'
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
secret
