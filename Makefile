DOTFILES_GITHUB   := "git@github.com:hiroppy/dotfiles.git"
DOTFILES_EXCLUDES := .DS_Store .git .gitignore .editorconfig
DOTFILES_TARGET   := $(wildcard .??*) bin
DOTFILES_DIR      := $(PWD)
DOTFILES_FILES    := $(filter-out $(DOTFILES_EXCLUDES), $(DOTFILES_TARGET))

install:
	@echo 'Start deploy dotfiles current directory.'
	@echo ''
	@mkdir -p ~/.config
	@ln -sfnv ~/dotfiles/config/nvim ~/.config/nvim
	@$(foreach val, $(DOTFILES_FILES), ln -sfnv $(abspath $(val)) $(HOME)/$(val);)

clean:
	@echo 'Remove dot files in your home directory...'
	@-$(foreach val, $(DOTFILES_FILES), rm -vrf $(HOME)/$(val);)
	-rm -rf $(DOTFILES_DIR)
