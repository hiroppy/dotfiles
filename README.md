## Setup

### Clone

```sh
git clone https://github.com/hiroppy/dotfiles
cd dotfiles
```

### brew

```sh
make brew
```

After this, you have 1password so you can sign in Apple.

### Apps in Apple

```sh
make apple
```

### fish

```sh
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
```

### Settings

```sh
make mac
```

## Setting Secret Envs

```sh
# secret variables
$ touch ~/.env
```
