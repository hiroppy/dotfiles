## Requirement

- homebrew
- 1password

## Setup

```sh
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
$ curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
$ brew install --cask 1password
$ git clone https://github.com/hiroppy/dotfiles
$ cd dotfiles
$ make setup
```

## Setting Secret Envs

```sh
# secret variables
$ touch ~/.env
```
