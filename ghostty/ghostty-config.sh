#!/usr/bin/env bash
set -e

# ====================
# Defaults
# ====================
THEME="Subliminal"
DRY_RUN=false
CHECK=false

GHOSTTY_CONFIG_DIR="$HOME/.config/ghostty"
GHOSTTY_CONFIG="$GHOSTTY_CONFIG_DIR/config"

THEMES_URL="https://raw.githubusercontent.com/jjsalinas/dotfiles/main/ghostty/themes.zip"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_THEMES_ZIP="$SCRIPT_DIR/themes.zip"

# Populated by backup_config() if a backup is made
CONFIG_BACKUP=""

# ====================
# Logging
# ====================
log_info()  { echo -e "\n[\033[34mINFO\033[0m] $* "; }
log_warn()  { echo -e "[\033[33mWARN\033[0m] $*"; }
log_ok()    { echo -e "[\033[32m OK \033[0m] $*"; }
log_fail()  { echo -e "[\033[31mFAIL\033[0m] $*"; }
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
Ghostty terminal setup

Usage:
  ./ghostty-config.sh [options]

Options:
  --theme <name>   Ghostty color theme to use (default: Subliminal)
  --check          Verify installation without making changes
  --dry-run        Show actions without making changes
  --help           Show this help and exit

What this does:
  • Writes ghostty config directly to ~/.config/ghostty/config
  • Backs up any existing config before overwriting
  • Downloads and installs themes from your dotfiles repo
  • Works on Ubuntu and Fedora

Themes:
  Themes are sourced from https://github.com/anhsirk0/ghostty-themes
  Pass any theme name with --theme (e.g. --theme Sakura)

Examples:
  ./ghostty-config.sh
  ./ghostty-config.sh --theme Sakura
  ./ghostty-config.sh --theme Nord --dry-run
  ./ghostty-config.sh --check
EOF
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
  log_info "Running ghostty installation check..."
  local failures=0

  check_ok()   { log_ok "$1"; }
  check_fail() { log_fail "$1"; failures=$((failures + 1)); }

  # Config dir
  [ -d "$GHOSTTY_CONFIG_DIR" ] \
    && check_ok  "ghostty config dir exists: $GHOSTTY_CONFIG_DIR" \
    || check_fail "ghostty config dir missing: $GHOSTTY_CONFIG_DIR"

  # Config file
  [ -f "$GHOSTTY_CONFIG" ] \
    && check_ok  "ghostty config exists: $GHOSTTY_CONFIG" \
    || check_fail "ghostty config missing: $GHOSTTY_CONFIG"

  # Theme
  if [ -f "$GHOSTTY_CONFIG" ]; then
    local current_theme
    current_theme=$(grep -oP '(?<=^theme = )\S+' "$GHOSTTY_CONFIG" 2>/dev/null || true)
    [ -n "$current_theme" ] \
      && check_ok  "theme is set: $current_theme" \
      || check_fail "theme not found in config"
  fi

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
# Backup existing config
# ====================
backup_config() {
  if [ -f "$GHOSTTY_CONFIG" ]; then
    log_info "Backing up existing ghostty config"
    CONFIG_BACKUP="$GHOSTTY_CONFIG.backup.$(date +%s)"
    run cp "$GHOSTTY_CONFIG" "$CONFIG_BACKUP"
  fi
}

# ====================
# Write config
# ====================
write_config() {
  log_info "Creating ghostty config directory"
  run mkdir -p "$GHOSTTY_CONFIG_DIR"

  log_info "Writing ghostty config to $GHOSTTY_CONFIG"
  if $DRY_RUN; then
    log_info "[dry-run] would write $GHOSTTY_CONFIG with theme $THEME"
    return
  fi

  cat << EOF > "$GHOSTTY_CONFIG"
# ~/.config/ghostty/config
# Managed by config.sh

### Font ###
font-family = Fira Mono
font-size = 12
font-thicken = true

### Window ###
window-width = 120
window-height = 33
window-padding-x = 12
window-padding-y = 10
# If on GNOME/KDE with client-side decorations use:
window-decoration = true
# If using a tiling WM (i3, Sway, Hyprland, etc.), set this:
# window-decoration = false
window-title-font-family = Fira Mono

### Theme / Colors ###
# Themes: https://github.com/anhsirk0/ghostty-themes
theme = $THEME

### Cursor ###
cursor-style = bar
cursor-style-blink = false

### Shell ###
shell-integration = zsh
shell-integration-features = cursor,sudo,title

### Behavior ###
confirm-close-surface = false
mouse-hide-while-typing = true
copy-on-select = false
scrollback-limit = 10000

### Keybinds (Linux) ###
keybind = ctrl+shift+t=new_tab
keybind = ctrl+shift+w=close_surface
# keybind = ctrl+shift+d=new_split:right
# keybind = ctrl+shift+shift+d=new_split:down
EOF

  log_info "Config written with theme: $THEME"
}

# ====================
# Install themes
# ====================
install_themes() {
  if $DRY_RUN; then
    if [ -f "$LOCAL_THEMES_ZIP" ]; then
      log_info "[dry-run] would install themes from local $LOCAL_THEMES_ZIP"
    else
      log_info "[dry-run] would download $THEMES_URL and extract to $GHOSTTY_CONFIG_DIR"
    fi
    return
  fi

  if [ -f "$LOCAL_THEMES_ZIP" ]; then
    log_info "Found local themes.zip, installing from $LOCAL_THEMES_ZIP"
    run unzip -qo "$LOCAL_THEMES_ZIP" -d "$GHOSTTY_CONFIG_DIR"
    log_ok "Themes installed"
    return
  fi

  log_info "No local themes.zip found, downloading from $THEMES_URL"
  local themes_tmp
  themes_tmp="$(mktemp /tmp/ghostty-themes-XXXXXX.zip)"

  if curl -fsSL "$THEMES_URL" -o "$themes_tmp"; then
    run unzip -qo "$themes_tmp" -d "$GHOSTTY_CONFIG_DIR"
    rm -f "$themes_tmp"
    log_ok "Themes installed"
  else
    log_warn "Could not download themes — skipping (theme name must still be valid)"
    rm -f "$themes_tmp"
  fi
}

# ====================
# Final message
# ====================
print_completion_message() {
  echo ""
  log_info "Ghostty setup complete"

  if $DRY_RUN; then
    log_warn "Dry-run mode enabled — no changes were made"
    return
  fi

  echo ""
  echo "To apply the changes, do ONE of the following:"
  echo "  1) Restart Ghostty"
  echo "  2) Or reload the config with:  ctrl+shift+,"
  echo ""
  echo "Useful follow-ups:"
  echo "  • Verify everything is set up correctly:  ./config.sh --check"
  echo "  • Switch themes any time:                 ./config.sh --theme <name>"

  if [ -n "$CONFIG_BACKUP" ]; then
    echo ""
    log_info "Your previous config was backed up to: $CONFIG_BACKUP"
  fi
}

# ====================
# Main
# ====================
main() {
  parse_args "$@"

  if $CHECK; then
    run_checks
    exit $?
  fi

  backup_config
  write_config
  install_themes
  print_completion_message
}

main "$@"
