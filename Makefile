DOTFILES_GITHUB   := "git@github.com:hiroppy/dotfiles.git"
DOTFILES_EXCLUDES := .DS_Store .git .gitignore .editorconfig
DOTFILES_TARGET   := $(wildcard .??*)
DOTFILES_DIR      := $(PWD)
DOTFILES_FILES    := $(filter-out $(DOTFILES_EXCLUDES), $(DOTFILES_TARGET))

install:
	@echo 'Start deploy dotfiles current directory.'
	@mkdir -p ~/.config
	@ln -sfnv ~/dotfiles/config/nvim ~/.config/nvim
	@ln -sfnv ~/dotfiles/config/fish ~/.config/fish
	@$(foreach val, $(DOTFILES_FILES), ln -sfnv $(abspath $(val)) $(HOME)/$(val);)
