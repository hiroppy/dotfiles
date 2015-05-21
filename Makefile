DOTFILES_GITHUB   := "git@github.com:abouthiroppy/dotfiles.git"
DOTFILES_EXCLUDES := .DS_Store .git .gitmodules .travis.yml
DOTFILES_TARGET   := $(wildcard .??*) bin
DOTFILES_DIR      := $(PWD)
DOTFILES_FILES    := $(filter-out $(DOTFILES_EXCLUDES), $(DOTFILES_TARGET))

all: install

list:
	@$(foreach val, $(DOTFILES_FILES), ls -dF $(val);)

update:
	git pull origin master
	git submodule init
	git submodule update
	git submodule foreach git pull origin master

deploy:
	@echo 'Start deploy dotfiles current directory.'
	@echo 'If this is "dotdir", curretly it is ignored and copy your hand.'
	@echo ''
	@ln -sfnv ~/dotfiles/custom.zsh ~/dotfiles/.oh-my-zsh/custom/custom.zsh
	@ln -sfnv ~/dotfiles/bluehigh.zsh-theme/bluehigh.zsh-theme ~/.oh-my-zsh/themes/bluehigh.zsh-theme
	@ln -sfnv ~/dotfiles/bluehigh.zsh-theme/bluehigh-components ~/.oh-my-zsh/themes/bluehigh-components

	@$(foreach val, $(DOTFILES_FILES), ln -sfnv $(abspath $(val)) $(HOME)/$(val);)

init:
	@$(foreach val, $(wildcard ./etc/init/*.sh), bash $(val);)
	@sh ./oh-my-zsh/tools/install.sh

install: update deploy init
	@exec $$SHELL

clean:
	@echo 'Remove dot files in your home directory...'
	@-$(foreach val, $(DOTFILES_FILES), rm -vrf $(HOME)/$(val);)
	-rm -rf $(DOTFILES_DIR)
