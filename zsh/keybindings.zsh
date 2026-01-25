bindkey -e

# Ctrl + Arrow
bindkey "^[[1;5D" backward-word
bindkey "^[[1;5C" forward-word

# Ctrl + Backspace / Delete
bindkey '^H' backward-kill-word
bindkey '^[[3;5~' kill-word

# Alt + Delete
bindkey -M emacs '^[[3;3~' kill-word
bindkey "^[[3~" delete-char
