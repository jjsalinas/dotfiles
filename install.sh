#!/usr/bin/env bash
set -e

# ====================
# Defaults
# ====================
THEME="clean"
ADD_NVM=false
DRY_RUN=false
UPDATE_PLUGINS=false
CHECK=false

ZSH_DIR="$HOME/.zsh"
ZSHRC="$HOME/.zshrc"
ZSHRC_LOCAL="$HOME/.zshrc.local"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Populated by detect_dependencies()
PKG_INSTALL=""
# Populated by backup_zshrc() if a backup is made
ZSHRC_BACKUP=""
# Resolved in main() once we know we're not running piped
DOTFILES_DIR=""

# ====================
# Logging
# ====================
log_info()  { echo -e "\n[\033[34mINFO\033[0m] $* "; } # Blue
log_warn()  { echo -e "[\033[33mWARN\033[0m] $*"; }  # Yellow
log_ok()    { echo -e "[\033[32m OK \033[0m] $*"; }   # Green
log_fail()  { echo -e "[\033[31mFAIL\033[0m] $*"; } # Red
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
Dotfiles installer (zsh-focused)

Usage:
  ./install.sh [options]

Options:
  --theme <name>   Oh My Zsh theme to use (default: clean)
  --add-nvm        Enable Node Version Manager config
  --update         Update installed plugins (git pull)
  --check          Verify installation without making changes
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
  ./install.sh --update
  ./install.sh --check

One-line install:
  curl -fsSL https://raw.githubusercontent.com/jjsalinas/dotfiles/main/install.sh | bash
  curl -fsSL https://raw.githubusercontent.com/jjsalinas/dotfiles/main/install.sh | bash -s -- --theme clean --add-nvm
EOF
}

# ====================
# Piped install handling
# ====================
# Detects `curl ... | bash` style invocations (no local repo available),
# clones the repo, and re-execs the installer from the cloned copy.
handle_piped_install() {
  local piped=false
  if [ -z "$BASH_SOURCE" ] || [ "$BASH_SOURCE" = "bash" ] || [ "$0" = "bash" ]; then
    piped=true
  fi

  if $piped; then
    local repo_url="https://github.com/jjsalinas/dotfiles.git"
    local clone_dir="$HOME/.dotfiles"

    log_info "Piped install detected — cloning repo to $clone_dir"
    if [ -d "$clone_dir" ]; then
      log_info "Repo already exists, pulling latest"
      git -C "$clone_dir" pull --ff-only
    else
      git clone "$repo_url" "$clone_dir"
    fi

    log_info "Re-executing installer from cloned repo"
    exec bash "$clone_dir/install.sh" "$@"
  fi
}

# ====================
# Argument parsing
# ====================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --theme)
        THEME="$2"
        shift
        ;;
      --add-nvm)
        ADD_NVM=true
        ;;
      --update)
        UPDATE_PLUGINS=true
        ;;
      --check)
        CHECK=true
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
}

# ====================
# --check mode
# ====================
run_checks() {
  log_info "Running installation check..."
  local failures=0

  check_ok()   { log_ok "$1"; }
  check_fail() { log_fail "$1"; failures=$((failures + 1)); }

  # Commands
  command -v zsh >/dev/null 2>&1       && check_ok  "zsh is installed"          || check_fail "zsh not found"
  command -v git >/dev/null 2>&1       && check_ok  "git is installed"          || check_fail "git not found"
  command -v fzf >/dev/null 2>&1       && check_ok  "fzf is installed"          || check_fail "fzf not found"
  [ -d "$HOME/.oh-my-zsh" ]           && check_ok  "Oh My Zsh is installed"    || check_fail "Oh My Zsh not found at ~/.oh-my-zsh"

  # Plugins
  [ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] \
    && check_ok  "zsh-syntax-highlighting plugin exists" \
    || check_fail "zsh-syntax-highlighting plugin missing"

  [ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] \
    && check_ok  "zsh-autosuggestions plugin exists" \
    || check_fail "zsh-autosuggestions plugin missing"

  # Symlinks
  check_symlink() {
    local link="$1" target="$2"
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
      check_ok  "symlink OK: $link -> $target"
    elif [ -L "$link" ]; then
      check_fail "symlink wrong target: $link -> $(readlink "$link") (expected $target)"
    elif [ -e "$link" ]; then
      check_fail "exists but not a symlink: $link"
    else
      check_fail "symlink missing: $link"
    fi
  }

  check_symlink "$ZSHRC"                    "$DOTFILES_DIR/zsh/zshrc"
  check_symlink "$ZSH_DIR/keybindings.zsh"  "$DOTFILES_DIR/zsh/keybindings.zsh"
  check_symlink "$ZSH_DIR/history.zsh"      "$DOTFILES_DIR/zsh/history.zsh"
  check_symlink "$ZSH_DIR/fzf.zsh"          "$DOTFILES_DIR/zsh/fzf.zsh"
  check_symlink "$ZSH_DIR/plugins.zsh"      "$DOTFILES_DIR/zsh/plugins.zsh"

  # .zshrc.local
  [ -f "$ZSHRC_LOCAL" ] \
    && check_ok  ".zshrc.local exists" \
    || check_fail ".zshrc.local missing (theme not configured)"

  echo ""
  if [ "$failures" -eq 0 ]; then
    log_info "All checks passed."
    exit 0
  else
    log_error "$failures check(s) failed."
    exit 1
  fi
}

# ====================
# Preconditions
# ====================
check_preconditions() {
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log_error "Oh My Zsh is not installed. Install it first: https://ohmyz.sh"
    exit 1
  fi
}

# ====================
# Dependencies
# ====================
# Detects the OS package manager and installs anything that's missing.
detect_dependencies() {
  log_info "Detecting OS / package manager"

  if command -v apt >/dev/null 2>&1; then
    PKG_INSTALL="sudo apt install -y"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_INSTALL="sudo dnf install -y"
  elif command -v brew >/dev/null 2>&1; then
    PKG_INSTALL="brew install"
  else
    PKG_INSTALL=""
    log_warn "No supported package manager found (apt/dnf/brew)"
  fi

  log_info "Checking dependencies"

  local deps=(git fzf)
  local dep
  for dep in "${deps[@]}"; do
    if command -v "$dep" >/dev/null 2>&1; then
      log_ok "$dep is already installed"
    elif [ -n "$PKG_INSTALL" ]; then
      log_info "Installing $dep"
      run $PKG_INSTALL "$dep"
    else
      log_error "$dep is missing and no package manager is available to install it"
    fi
  done
}

# ====================
# Plugins
# ====================
install_or_update_plugin() {
  local name="$1"
  local url="$2"
  local dest="$ZSH_CUSTOM/plugins/$name"

  if [ -d "$dest" ]; then
    if $UPDATE_PLUGINS; then
      log_info "Updating $name"
      run git -C "$dest" pull --ff-only
    else
      log_warn "$name already installed (use --update to pull latest)"
    fi
  else
    log_info "Installing $name"
    run git clone "$url" "$dest"
  fi
}

install_plugins() {
  install_or_update_plugin "zsh-syntax-highlighting" \
    "https://github.com/zsh-users/zsh-syntax-highlighting"

  install_or_update_plugin "zsh-autosuggestions" \
    "https://github.com/zsh-users/zsh-autosuggestions"
}

# ====================
# Backup existing .zshrc
# ====================
backup_zshrc() {
  if [ -f "$ZSHRC" ] && [ ! -L "$ZSHRC" ]; then
    log_info "Backing up existing .zshrc"
    ZSHRC_BACKUP="$ZSHRC.backup.$(date +%s)"
    run cp "$ZSHRC" "$ZSHRC_BACKUP"
  fi
}

# ====================
# Symlinks
# ====================
create_symlinks() {
  log_info "Creating zsh config directory"
  run mkdir -p "$ZSH_DIR"

  log_info "Linking zsh config files"
  run ln -sf "$DOTFILES_DIR/zsh/zshrc"          "$ZSHRC"
  run ln -sf "$DOTFILES_DIR/zsh/keybindings.zsh" "$ZSH_DIR/keybindings.zsh"
  run ln -sf "$DOTFILES_DIR/zsh/history.zsh"     "$ZSH_DIR/history.zsh"
  run ln -sf "$DOTFILES_DIR/zsh/fzf.zsh"         "$ZSH_DIR/fzf.zsh"
  run ln -sf "$DOTFILES_DIR/zsh/plugins.zsh"     "$ZSH_DIR/plugins.zsh"
}

# ====================
# NVM
# ====================
handle_nvm() {
  if $ADD_NVM; then
    log_info "Linking NVM config"
    run ln -sf "$DOTFILES_DIR/zsh/nvm.zsh" "$ZSH_DIR/nvm.zsh"
  else
    run rm -f "$ZSH_DIR/nvm.zsh"
  fi
}

# ====================
# Theme handling
# ====================
# Uses `sed` to update only the ZSH_THEME line in-place, so any other
# settings someone has added to ~/.zshrc.local are left untouched.
set_theme() {
  local theme="$1"

  log_info "Setting theme: $theme"

  if $DRY_RUN; then
    log_info "[dry-run] would ensure ZSH_THEME=\"$theme\" in $ZSHRC_LOCAL"
    return
  fi

  touch "$ZSHRC_LOCAL"

  local current_theme=""
  if grep -q '^export ZSH_THEME=' "$ZSHRC_LOCAL"; then
    current_theme=$(grep -oP '(?<=ZSH_THEME=")[^"]+' "$ZSHRC_LOCAL" 2>/dev/null || true)
  fi

  if [ "$current_theme" = "$theme" ]; then
    log_warn ".zshrc.local already has theme '$theme', skipping"
    return
  fi

  if grep -q '^export ZSH_THEME=' "$ZSHRC_LOCAL"; then
    sed -i "s/^export ZSH_THEME=.*/export ZSH_THEME=\"$theme\"/" "$ZSHRC_LOCAL"
  else
    printf '\nexport ZSH_THEME="%s"\n' "$theme" >> "$ZSHRC_LOCAL"
  fi

  log_info "Theme set to: $theme"
}

# ====================
# Final message
# ====================
print_completion_message() {
  echo ""
  log_info "Dotfiles installation complete"

  if $DRY_RUN; then
    log_warn "Dry-run mode enabled — no changes were made"
    return
  fi

  echo ""
  echo "To apply the changes, do ONE of the following:"
  echo "  1) Open a new terminal window"
  echo "  2) Or run:  exec zsh"
  echo ""
  echo "Useful follow-ups:"
  echo "  • Verify everything is set up correctly:  ./install.sh --check"
  echo "  • Switch themes any time:                 ./install.sh --theme <name>"
  echo "  • Pull the latest plugin versions:        ./install.sh --update"

  if [ -n "$ZSHRC_BACKUP" ]; then
    echo ""
    log_info "Your previous .zshrc was backed up to: $ZSHRC_BACKUP"
  fi
}

# ====================
# Main
# ====================
main() {
  handle_piped_install "$@"

  # Running from a local clone - resolve DOTFILES_DIR normally
  DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

  parse_args "$@"

  if $CHECK; then
    run_checks
    exit $?
  fi

  check_preconditions
  detect_dependencies
  install_plugins
  backup_zshrc
  create_symlinks
  handle_nvm
  set_theme "$THEME"
  print_completion_message
}

main "$@"
