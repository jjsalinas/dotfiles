#!/usr/bin/env bash
set -e

# ====================
# Logging
# ====================
log_info()  { echo "[INFO] $*"; }
log_warn()  { echo "[WARN] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

ZSH_DIR="$HOME/.zsh"
ZSHRC="$HOME/.zshrc"
ZSHRC_LOCAL="$HOME/.zshrc.local"
BACKUP_DIR="$HOME/.dotfiles-uninstall-backup-$(date +%s)"

log_info "Starting dotfiles uninstall"
log_info "Backup directory: $BACKUP_DIR"

mkdir -p "$BACKUP_DIR"

# ====================
# Backup existing files
# ====================
for file in "$ZSHRC" "$ZSHRC_LOCAL"; do
  if [ -e "$file" ]; then
    log_info "Backing up $(basename "$file")"
    cp -a "$file" "$BACKUP_DIR/"
  fi
done

if [ -d "$ZSH_DIR" ]; then
  log_info "Backing up ~/.zsh directory"
  cp -a "$ZSH_DIR" "$BACKUP_DIR/"
fi

# ====================
# Remove zsh config files
# ====================
log_info "Removing zsh config files installed by dotfiles"

# Remove main zshrc (symlink or copied file)
if [ -e "$ZSHRC" ]; then
  rm -f "$ZSHRC"
fi

# Remove local theme config
rm -f "$ZSHRC_LOCAL"

# Remove managed ~/.zsh files
if [ -d "$ZSH_DIR" ]; then
  rm -f \
    "$ZSH_DIR/keybindings.zsh" \
    "$ZSH_DIR/history.zsh" \
    "$ZSH_DIR/fzf.zsh" \
    "$ZSH_DIR/plugins.zsh" \
    "$ZSH_DIR/nvm.zsh"

  # Remove directory if empty
  rmdir "$ZSH_DIR" 2>/dev/null || true
fi

# ====================
# Restore a minimal .zshrc
# ====================
log_info "Restoring minimal ~/.zshrc"

cat << 'EOF' > "$ZSHRC"
# Minimal .zshrc restored after dotfiles uninstall

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git)

source "$ZSH/oh-my-zsh.sh"
EOF

# ====================
# Done
# ====================
log_info "Uninstall complete"
log_info "Backups saved in: $BACKUP_DIR"
log_info "Restart your shell or run: exec zsh"
