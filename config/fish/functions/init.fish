function init
  eval (pyenv init - | source)

  if not functions -q fisher
      set -q XDG_CONFIG_HOME; or set XDG_CONFIG_HOME ~/.config
      curl https://git.io/fisher --create-dirs -sLo $XDG_CONFIG_HOME/fish/functions/fisher.fish
      fish -c fisher
  end

  if [ -f $HOME/google-cloud-sdk/path.fish.inc ]
    source $HOME/google-cloud-sdk/path.fish.inc
  end

  if [ -f $HOME/google-cloud-sdk/completion.fish.inc ]
    source $HOME/google-cloud-sdk/completion.fish.inc
  end
end
