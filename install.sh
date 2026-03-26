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

# Detect if we're being piped from curl (no local repo available)
PIPED_INSTALL=false
if [ -z "$BASH_SOURCE" ] || [ "$BASH_SOURCE" = "bash" ] || [ "$0" = "bash" ]; then
  PIPED_INSTALL=true
fi

# If piped, we need to clone the repo first and re-exec from there
if $PIPED_INSTALL; then
  REPO_URL="https://github.com/jjsalinas/dotfiles.git"
  CLONE_DIR="$HOME/.dotfiles"

  echo "[INFO] Piped install detected — cloning repo to $CLONE_DIR"
  if [ -d "$CLONE_DIR" ]; then
    echo "[INFO] Repo already exists, pulling latest"
    git -C "$CLONE_DIR" pull --ff-only
  else
    git clone "$REPO_URL" "$CLONE_DIR"
  fi

  echo "[INFO] Re-executing installer from cloned repo"
  exec bash "$CLONE_DIR/install.sh" "$@"
fi

# Running from a local clone — resolve DOTFILES_DIR normally
DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# ====================
# Logging
# ====================
log_info()  { echo "[INFO]  $*"; }
log_warn()  { echo "[WARN]  $*"; }
log_ok()    { echo "[OK]    $*"; }
log_fail()  { echo "[FAIL]  $*"; }
log_error() { echo "[ERROR] $*" >&2; }

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

# ====================
# --check mode
# ====================
if $CHECK; then
  log_info "Running installation check..."
  FAILURES=0

  check_ok()   { log_ok "$1"; }
  check_fail() { log_fail "$1"; FAILURES=$((FAILURES + 1)); }

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
  if [ "$FAILURES" -eq 0 ]; then
    log_info "All checks passed."
    exit 0
  else
    log_error "$FAILURES check(s) failed."
    exit 1
  fi
fi

# ====================
# Preconditions
# ====================
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  log_error "Oh My Zsh is not installed. Install it first: https://ohmyz.sh"
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
elif command -v brew >/dev/null 2>&1; then
  PKG_INSTALL="brew install"
else
  PKG_INSTALL=""
fi

# ====================
# Dependencies
# ====================
log_info "Installing dependencies"
if [ -n "$PKG_INSTALL" ]; then
  command -v git >/dev/null 2>&1 || run $PKG_INSTALL git
  command -v fzf >/dev/null 2>&1 || run $PKG_INSTALL fzf
fi

# ====================
# Plugin install/update helper
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

# ====================
# Plugins
# ====================
install_or_update_plugin "zsh-syntax-highlighting" \
  "https://github.com/zsh-users/zsh-syntax-highlighting"

install_or_update_plugin "zsh-autosuggestions" \
  "https://github.com/zsh-users/zsh-autosuggestions"

# ====================
# Backup existing files
# ====================
if [ -f "$ZSHRC" ] && [ ! -L "$ZSHRC" ]; then
  log_info "Backing up existing .zshrc"
  run cp "$ZSHRC" "$ZSHRC.backup.$(date +%s)"
fi

# ====================
# Symlinks
# ====================
log_info "Creating zsh config directory"
run mkdir -p "$ZSH_DIR"

log_info "Linking zsh config files"
run ln -sf "$DOTFILES_DIR/zsh/zshrc"          "$ZSHRC"
run ln -sf "$DOTFILES_DIR/zsh/keybindings.zsh" "$ZSH_DIR/keybindings.zsh"
run ln -sf "$DOTFILES_DIR/zsh/history.zsh"     "$ZSH_DIR/history.zsh"
run ln -sf "$DOTFILES_DIR/zsh/fzf.zsh"         "$ZSH_DIR/fzf.zsh"
run ln -sf "$DOTFILES_DIR/zsh/plugins.zsh"     "$ZSH_DIR/plugins.zsh"

if $ADD_NVM; then
  log_info "Linking NVM config"
  run ln -sf "$DOTFILES_DIR/zsh/nvm.zsh" "$ZSH_DIR/nvm.zsh"
else
  run rm -f "$ZSH_DIR/nvm.zsh"
fi

# ====================
# Theme handling
# ====================
log_info "Setting theme: $THEME"
if ! $DRY_RUN; then
  # Only write .zshrc.local if theme has changed (or file doesn't exist)
  current_theme=""
  if [ -f "$ZSHRC_LOCAL" ]; then
    current_theme=$(grep -oP '(?<=ZSH_THEME=")[^"]+' "$ZSHRC_LOCAL" 2>/dev/null || true)
  fi

  if [ "$current_theme" != "$THEME" ]; then
    cat << EOF > "$ZSHRC_LOCAL"
export ZSH_THEME="$THEME"
EOF
    log_info "Theme set to: $THEME"
  else
    log_warn ".zshrc.local already has theme '$THEME', skipping"
  fi
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
