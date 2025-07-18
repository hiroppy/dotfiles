DOTFILES_GITHUB   := 'git@github.com:hiroppy/dotfiles.git'
DOTFILES_EXCLUDES := .DS_Store .git .gitignore .editorconfig
DOTFILES_TARGET   := $(wildcard .??*)
DOTFILES_DIR      := $(PWD)
DOTFILES_FILES    := $(filter-out $(DOTFILES_EXCLUDES), $(DOTFILES_TARGET))

.PHONY: setup
setup: brew install fish mac

.PHONY: brew
brew:
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
	brew bundle
	sh mas.sh

.PHONY: install
install:
	echo 'Start deploy dotfiles current directory.'
	mkdir -p ~/.config
	ln -sfnv ~/dotfiles/config/mise ~/.config/mise
	ln -sfnv ~/dotfiles/config/fish ~/.config/fish
	ln -sfnv ~/dotfiles/config/nvim ~/.config/nvim
	mkdir -p ~/.claude
	ln -sfnv ~/dotfiles/config/claude/settings.json ~/.claude/settings.json
	# ssh with 1password
	mkdir -p ~/.ssh
	ln -sfnv ~/dotfiles/ssh/config ~/.ssh/config
	mkdir -p ~/.1password
	mkdir -p ~/.config/1Password/ssh
	ln -sfnv ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock ~/.1password/agent.sock
	ln -sfnv ~/dotfiles/config/1password/ssh/agent.toml ~/.config/1Password/ssh/agent.toml
	@$(foreach val, $(DOTFILES_FILES), ln -sfnv $(abspath $(val)) $(HOME)/$(val);)
	# docker
	mkdir -p ~/.config/fish/completions
	docker completion fish > ~/.config/fish/completions/docker.fish

.PHONY: fish
fish:
	fish -c "fisher update"

.PHONY: mac
mac:
	# dock
	defaults write com.apple.dock autohide -bool true
	defaults write com.apple.dock largesize 128
	defaults write com.apple.dock show-recents -bool false
	defaults write NSGlobalDomain AppleInterfaceStyle Dark
	killall Dock
	# bettertouchtool
	defaults write com.hegenberg.BetterTouchTool BTTNoNamedTriggerOnLeftRightClick YES
