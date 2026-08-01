#!/usr/bin/env bash
set -e

# ====================
# Defaults
# ====================
DRY_RUN=false

ZSH_DIR="$HOME/.zsh"
ZSHRC="$HOME/.zshrc"
ZSHRC_LOCAL="$HOME/.zshrc.local"
BACKUP_DIR="$HOME/.dotfiles-uninstall-backup-$(date +%s)"

# ====================
# Logging
# ====================
log_info()  { echo -e "\n[\033[34mINFO\033[0m] $* "; }
log_warn()  { echo -e "[\033[33mWARN\033[0m] $*"; }
log_error() { echo -e "\n[ERROR] $*" >&2; }

run() {
  if $DRY_RUN; then
    log_info "[dry-run] $*"
  else
    "$@"
  fi
}

# ====================
# Help
# ====================
print_help() {
  cat << 'EOF'
Dotfiles uninstaller (zsh-focused)

Usage:
  ./uninstall.sh [options]

Options:
  --dry-run   Show actions without making changes
  --help      Show this help and exit

What this does:
  • Backs up your current zsh dotfiles to a timestamped backup directory
  • Removes the config files/symlinks installed by install.sh
  • Restores a minimal ~/.zshrc so your shell keeps working
  • Leaves Oh My Zsh itself, its plugins, and other tool configs untouched

Examples:
  ./uninstall.sh
  ./uninstall.sh --dry-run
EOF
}

# ====================
# Argument parsing
# ====================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
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
}

# ====================
# Backup existing files
# ====================
backup_existing() {
  log_info "Backup directory: $BACKUP_DIR"
  run mkdir -p "$BACKUP_DIR"

  local file
  for file in "$ZSHRC" "$ZSHRC_LOCAL"; do
    if [ -e "$file" ]; then
      log_info "Backing up $(basename "$file")"
      run cp -a "$file" "$BACKUP_DIR/"
    fi
  done

  if [ -d "$ZSH_DIR" ]; then
    log_info "Backing up ~/.zsh directory"
    run cp -a "$ZSH_DIR" "$BACKUP_DIR/"
  fi
}

# ====================
# Remove zsh config files
# ====================
remove_configs() {
  log_info "Removing zsh config files installed by dotfiles"

  # Remove main zshrc (symlink or copied file)
  if [ -e "$ZSHRC" ]; then
    run rm -f "$ZSHRC"
  fi

  # Remove local theme config
  run rm -f "$ZSHRC_LOCAL"

  # Remove managed ~/.zsh files
  if [ -d "$ZSH_DIR" ]; then
    run rm -f \
      "$ZSH_DIR/keybindings.zsh" \
      "$ZSH_DIR/history.zsh" \
      "$ZSH_DIR/fzf.zsh" \
      "$ZSH_DIR/plugins.zsh" \
      "$ZSH_DIR/nvm.zsh" \
      "$ZSH_DIR/aliases.zsh"

    # Remove directory if empty
    if $DRY_RUN; then
      log_info "[dry-run] would remove $ZSH_DIR if empty"
    else
      rmdir "$ZSH_DIR" 2>/dev/null || true
    fi
  fi
}

# ====================
# Restore a minimal .zshrc
# ====================
restore_minimal_zshrc() {
  log_info "Restoring minimal ~/.zshrc"

  if $DRY_RUN; then
    log_info "[dry-run] would write a minimal ~/.zshrc to $ZSHRC"
    return
  fi

  cat << 'EOF' > "$ZSHRC"
# Minimal .zshrc restored after dotfiles uninstall

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git)

source "$ZSH/oh-my-zsh.sh"
EOF
}

# ====================
# Final message
# ====================
print_completion_message() {
  echo ""
  log_info "Uninstall complete"

  if $DRY_RUN; then
    log_warn "Dry-run mode enabled — no changes were made"
    return
  fi

  echo ""
  echo "What happened:"
  echo "  • Dotfiles-managed zsh config was removed"
  echo "  • A minimal ~/.zshrc was restored so your shell still works"
  echo "  • Your previous files were backed up to: $BACKUP_DIR"
  echo ""
  echo "To apply the changes, do ONE of the following:"
  echo "  1) Open a new terminal window"
  echo "  2) Or run:  exec zsh"
  echo ""
  echo "Want your old setup back? Just copy the files from the backup directory above."
}

# ====================
# Main
# ====================
main() {
  parse_args "$@"

  log_info "Starting dotfiles uninstall"

  backup_existing
  remove_configs
  restore_minimal_zshrc
  print_completion_message
}

main "$@"
