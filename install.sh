#!/usr/bin/env bash
set -e

# ====================
# Defaults
# ====================
THEME="clean"
ADD_NVM=false
DRY_RUN=false

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
ZSH_DIR="$HOME/.zsh"
ZSHRC="$HOME/.zshrc"
ZSHRC_LOCAL="$HOME/.zshrc.local"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ====================
# Logging
# ====================
log_info()  { echo "[INFO] $*"; }
log_warn()  { echo "[WARN] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

run() {
  if $DRY_RUN; then
    log_info "[dry-run] $*"
  else
    eval "$@"
  fi
}

# ====================
# Help
# ====================
print_help() {
  cat << 'EOF'
Dotfiles installer (zsh-focused)

Usage:
  ./install.sh [options]

Options:
  --theme <name>   Oh My Zsh theme to use (default: clean)
  --add-nvm        Enable Node Version Manager config
  --dry-run        Show actions without making changes
  --help           Show this help and exit

What this does:
  • Symlinks zsh configuration from this repo
  • Installs required zsh plugins
  • Enables syntax highlighting (green/red commands)
  • Enables fzf history search
  • Adds ergonomic keybindings
  • Works on Ubuntu and Fedora

Examples:
  ./install.sh
  ./install.sh --theme robbyrussell
  ./install.sh --add-nvm
  ./install.sh --theme agnoster --add-nvm --dry-run
EOF
}

# ====================
# Argument parsing
# ====================
while [[ $# -gt 0 ]]; do
  case "$1" in
    --theme)
      THEME="$2"
      shift
      ;;
    --add-nvm)
      ADD_NVM=true
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    --help)
      print_help
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

# ====================
# Preconditions
# ====================
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  log_error "Oh My Zsh is not installed. Install it first."
  exit 1
fi

# ====================
# OS detection
# ====================
log_info "Detecting OS"
if command -v apt >/dev/null 2>&1; then
  PKG_INSTALL="sudo apt install -y"
elif command -v dnf >/dev/null 2>&1; then
  PKG_INSTALL="sudo dnf install -y"
else
  PKG_INSTALL=""
fi

# ====================
# Dependencies
# ====================
log_info "Installing dependencies"
if [ -n "$PKG_INSTALL" ]; then
  command -v git >/dev/null 2>&1 || run "$PKG_INSTALL git"
  command -v fzf >/dev/null 2>&1 || run "$PKG_INSTALL fzf"
fi

# ====================
# Plugins
# ====================
log_info "Installing zsh-syntax-highlighting"
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
  run "git clone https://github.com/zsh-users/zsh-syntax-highlighting \
    '$ZSH_CUSTOM/plugins/zsh-syntax-highlighting'"
else
  log_warn "zsh-syntax-highlighting already installed"
fi

log_info "Installing zsh-autosuggestions (disabled by default)"
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
  run "git clone https://github.com/zsh-users/zsh-autosuggestions \
    '$ZSH_CUSTOM/plugins/zsh-autosuggestions'"
else
  log_warn "zsh-autosuggestions already installed"
fi

# ====================
# Backup existing files
# ====================
if [ -f "$ZSHRC" ] && [ ! -L "$ZSHRC" ]; then
  log_info "Backing up existing .zshrc"
  run "cp '$ZSHRC' '$ZSHRC.backup.$(date +%s)'"
fi

# ====================
# Symlinks
# ====================
log_info "Creating zsh config directory"
run "mkdir -p '$ZSH_DIR'"

log_info "Linking zsh config files"
run "ln -sf '$DOTFILES_DIR/zsh/zshrc' '$ZSHRC'"
run "ln -sf '$DOTFILES_DIR/zsh/keybindings.zsh' '$ZSH_DIR/keybindings.zsh'"
run "ln -sf '$DOTFILES_DIR/zsh/history.zsh' '$ZSH_DIR/history.zsh'"
run "ln -sf '$DOTFILES_DIR/zsh/fzf.zsh' '$ZSH_DIR/fzf.zsh'"
run "ln -sf '$DOTFILES_DIR/zsh/plugins.zsh' '$ZSH_DIR/plugins.zsh'"

if $ADD_NVM; then
  log_info "Linking NVM config"
  run "ln -sf '$DOTFILES_DIR/zsh/nvm.zsh' '$ZSH_DIR/nvm.zsh'"
else
  run "rm -f '$ZSH_DIR/nvm.zsh' || true"
fi

# ====================
# Theme handling
# ====================
log_info "Setting theme: $THEME"
if ! $DRY_RUN; then
  cat << EOF > "$ZSHRC_LOCAL"
export ZSH_THEME="$THEME"
EOF
else
  log_info "[dry-run] would write ~/.zshrc.local with theme $THEME"
fi

# ====================
# Done
# ====================
log_info "Dotfiles installation complete"
log_info "Open a new terminal or run: exec zsh"
if $DRY_RUN; then
  log_warn "Dry-run mode enabled — no changes were made"
fi
