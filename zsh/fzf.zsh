if [ -f /usr/share/fzf/shell/key-bindings.zsh ]; then
  source /usr/share/fzf/shell/key-bindings.zsh
elif [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
elif [ -f ~/.fzf/shell/key-bindings.zsh ]; then
  source ~/.fzf/shell/key-bindings.zsh
fi
