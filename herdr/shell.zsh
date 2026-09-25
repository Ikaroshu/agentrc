typeset -U path
path=("$HOME/.local/bin" $path)

for herdr_hook in "$HOME"/.config/herdr/plugins/github/herdr-automatic-rename-*/shell/hook.zsh(N); do
  source "$herdr_hook"
  break
done
unset herdr_hook
