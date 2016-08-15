export PATH=/usr/local/bin:$PATH
export PATH=/usr/local/php5/bin:$PATH
export PATH=$HOME/.nodebrew/current/bin:$PATH
export HOMEBREW_CASK_OPTS="--appdir=/Applications"
export PATH=$PATH:~/Library/Android/sdk/platform-tools
export GOPATH=$HOME/go
export GOROOT=/usr/local/opt/go/libexec
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH

# rbenv
eval "$(rbenv init -)"
export PATH="$HOME/.rbenv/shims:$PATH"

alias f="fg"
alias mongodd="mongod -dbpath /usr/local/var/mongodb/ --logpath /usr/local/var/log/mongodb/mongodb.log &"
alias a="./a.out"
alias bc="bc -l"
alias open="open ." # bugあり
alias hue="node ~/Programming/hue/index.js"
alias vps="ssh 153.121.57.47 -p 10022 -l about_hiroppy"
alias deploy-myvocabs="ansible-playbook $HOME/Programming/deploy2Server/deploy/myVocabs.yml -i $HOME/Programming/deploy2Server/hosts --ask-pass --ask-sudo-pass"
alias git=hub
alias dynamodb="/usr/local/bin/dynamodb-local"

# for hub
# compdef hub=git

alias postgres="postgres -D /usr/local/var/postgres"

setopt auto_menu
setopt complete_in_word      # 語の途中でもカーソル位置で補完
setopt always_last_prompt    # カーソル位置は保持したままファイル名一覧を順次その場で表示

bindkey "^L" backward-delete-word
 
############################################
function cdls() {
    # cdがaliasでループするので\をつける
    \cd $1;
    ls;
}
alias cd=cdls
############################################

## cd
## ディレクトリ名だけでcdする
setopt auto_cd
## cdで移動してもpushdと同じようにディレクトリスタックに追加する
setopt auto_pushd
## カレントディレクトリ中に指定されたディレクトリが見つからなかった場合に移動先を検索するリスト
cdpath=(~)
## ディレクトリが変わったらディレクトリスタックを表示
chpwd_functions=($chpwd_functions dirs)

## 補完時に大小文字を区別しない
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' menu select=1
## 補完候補に色を付ける。
zstyle ':completion:*:default' list-colors ""
autoload -U compinit && compinit
# 補完関数の表示を強化する
zstyle ':completion:*' verbose yes
zstyle ':completion:*' completer _expand _complete _match _prefix _approximate _list _history
zstyle ':completion:*:messages' format '%F{YELLOW}%d'$DEFAULT
zstyle ':completion:*:warnings' format '%F{RED}No matches for:''%F{YELLOW} %d'$DEFAULT
zstyle ':completion:*:descriptions' format '%F{YELLOW}completing %B%d%b'$DEFAULT
zstyle ':completion:*:options' description 'yes'
zstyle ':completion:*:descriptions' format '%F{yellow}Completing %B%d%b%f'$DEFAULT
# マッチ種別を別々に表示
zstyle ':completion:*' group-name ''
# セパレータを設定する
zstyle ':completion:*' list-separator '->'
zstyle ':completion:*:manuals' separate-sections true

# # 名前で色を付けるようにする
autoload colors
colors

# ファイル補完候補に色を付ける
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

## options
setopt BASH_AUTO_LIST
setopt LIST_AMBIGUOUS
setopt AUTO_PUSHD

## history
HISTFILE="$HOME/.zsh_history"
HISTSIZE=86000
SAVEHIST=86000
setopt hist_ignore_all_dups
setopt hist_reduce_blanks
setopt share_history
# 直前と同じコマンドラインはヒストリに追加しない
setopt hist_ignore_dups

#ls color
#01: ディレクトリ前景色
#02: ディレクトリ背景色
#03: シンボリックリンク前景色
#04: シンボリックリンク背景色
#05: ソケットファイル前景色
#06: ソケットファイル背景色
#07: FIFOファイル前景色
#08: FIFOファイル背景色
#09: 実行ファイル前景色
#10: 実行ファイル背景色
#11: ブロックスペシャルファイル前景色
#12: ブロックスペシャルファイル背景色
#13: キャラクタスペシャルファイル前景色
#14: キャラクタスペシャルファイル背景色
#15: setuidつき実行ファイル前景色
#16: setuidつき実行ファイル背景色
#17: setgidつき実行ファイル前景色
#18: setgidつき実行ファイル背景色
#19: スティッキビットありother書き込み権限つきディレクトリ前景色
#20: スティッキビットありother書き込み権限つきディレクトリ背景色
#21: スティッキビットなしother書き込み権限つきディレクトリ前景色
#22: スティッキビットなしother書き込み権限つきディレクトリ背景色

#color
#a: 黒
#b: 赤
#c: 緑
#d: 茶
#e: 青
#f: マゼンタ
#g: シアン
#h: 白
#A: 黒(太字)
#B: 赤(太字)
#C: 緑(太字)
#D: 茶(太字)
#E: 青(太字)
#F: マゼンタ(太字)
#G: シアン(太字)
#H: 白(太字)
#x: デフォルト色

# export CLICOLOR=1
# export LSCOLORS=DxGxcxdxCxegedabagacad
 export LSCOLORS=dxgxcxdxcxegedabagacad
#export LSCOLORS=gxfxcxdxbxegedabagacad
# export LSCOLORS=ExFxBxDxCxegedabagacad
# export LSCOLORS=exfxbxdxcxegedabagacad
#TITLE
case "${TERM}" in
kterm*|xterm*|terminal*)
 precmd() {
  echo -ne "\033]0;${USER}@${HOST%%.*}:${PWD}\007"
 }
 ;;
esac
## jobsでプロセスIDも出力する。
setopt long_list_jobs

## 実行したプロセスの消費時間が3秒以上かかったら
## 自動的に消費時間の統計情報を表示する。
REPORTTIME=3
## 実行中のコマンドとユーザ名とホスト名とカレントディレクトリを表示。
update_title() {
    local command_line=
    typeset -a command_line
    command_line=${(z)2}
    local command=
    if [ ${(t)command_line} = "array-local" ]; then
        command="$command_line[1]"
    else
        command="$2"
    fi
    print -n -P "\e]2;"
    echo -n "(${command})"
    print -n -P "%n@%m:%~\a"
}

## X環境上でだけウィンドウタイトルを変える。
if [ -n "$DISPLAY" ]; then
    preexec_functions=($preexec_functions update_title)
fi

# autoload colors
#左プロンプトcolor
#export PS1="%B%{%}%/#%{%}%b "
# export PS1="%B%{%}%aabout_hiroppy:%{%}%b"
#^[[31m/Users/about_hiroppy#^[[m

#右プロンプト
# %F{～}は色指定、%fでリセット
# %nはログインユーザ名、%~はカレントディレクトリ
# "%(?..%F{red}-%?-)" は終了コードが0以外なら赤色で表示
# "%1(v|%F{yellow}%1v%F{green} |)" の部分がVCS情報 (psvarの長さが1以上なら黄色で表示)
# RPROMPT="%(?..%F{red}-%?-)%F{red}[%1(v|%F{yellow}%1v%F{green} |)%n:%~]%f"
# RPROMPT=$'\U26C5  '%*

#gitブランチ名表示
# autoload -Uz vcs_info
# zstyle ':vcs_info:*' enable git
# zstyle ':vcs_info:git:*' formats '%c%u%b'
# zstyle ':vcs_info:git:*' actionformats '%c%u%b|%a'

#カレントディレクトリ/コマンド記録
local _cmd=''
local _lastdir=''
preexec() {
  _cmd="$1"
  _lastdir="$PWD"
}

#git情報更新
# update_vcs_info() {
#   psvar=()
#   LANG=en_US.UTF-8 vcs_info
#   [[ -n "$vcs_info_msg_0_" ]] && psvar[1]="$vcs_info_msg_0_"
# }

#カレントディレクトリ変更時/git関連コマンド実行時に情報更新
# precmd() {
#   _r=$?
#   case "${_cmd}" in
#     git*|stg*) update_vcs_info ;;
#     *) [ "${_lastdir}" != "$PWD" ] && update_vcs_info ;;
#   esac
#   return $_r
# }

zshaddhistory(){
  local line=${1%%$'\n'}
  local cmd=${line%% *}
   
  [[ ${cmd} != (f) ]]
}

setopt no_beep
setopt no_tify
setopt nonomatch
