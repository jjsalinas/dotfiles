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
Ghostty terminal setup

Usage:
  ./config.sh [options]

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
  ./config.sh
  ./config.sh --theme Sakura
  ./config.sh --theme Nord --dry-run
  ./config.sh --check
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
  log_info "Running ghostty installation check..."
  FAILURES=0

  check_ok()   { log_ok "$1"; }
  check_fail() { log_fail "$1"; FAILURES=$((FAILURES + 1)); }

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
    current_theme=$(grep -oP '(?<=^theme = )\S+' "$GHOSTTY_CONFIG" 2>/dev/null || true)
    [ -n "$current_theme" ] \
      && check_ok  "theme is set: $current_theme" \
      || check_fail "theme not found in config"
  fi

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
# Backup existing config
# ====================
if [ -f "$GHOSTTY_CONFIG" ]; then
  log_info "Backing up existing ghostty config"
  run cp "$GHOSTTY_CONFIG" "$GHOSTTY_CONFIG.backup.$(date +%s)"
fi

# ====================
# Write config
# ====================
log_info "Creating ghostty config directory"
run mkdir -p "$GHOSTTY_CONFIG_DIR"

log_info "Writing ghostty config to $GHOSTTY_CONFIG"
if ! $DRY_RUN; then
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
else
  log_info "[dry-run] would write $GHOSTTY_CONFIG with theme $THEME"
fi

# ====================
# Install themes
# ====================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_THEMES_ZIP="$SCRIPT_DIR/themes.zip"

if ! $DRY_RUN; then
  if [ -f "$LOCAL_THEMES_ZIP" ]; then
    log_info "Found local themes.zip, installing from $LOCAL_THEMES_ZIP"
    unzip -qo "$LOCAL_THEMES_ZIP" -d "$GHOSTTY_CONFIG_DIR"
    log_ok "Themes installed"
  else
    log_info "No local themes.zip found, downloading from $THEMES_URL"
    THEMES_TMP="$(mktemp /tmp/ghostty-themes-XXXXXX.zip)"
    if curl -fsSL "$THEMES_URL" -o "$THEMES_TMP"; then
      unzip -qo "$THEMES_TMP" -d "$GHOSTTY_CONFIG_DIR"
      rm -f "$THEMES_TMP"
      log_ok "Themes installed"
    else
      log_warn "Could not download themes — skipping (theme name must still be valid)"
      rm -f "$THEMES_TMP"
    fi
  fi
else
  if [ -f "$LOCAL_THEMES_ZIP" ]; then
    log_info "[dry-run] would install themes from local $LOCAL_THEMES_ZIP"
  else
    log_info "[dry-run] would download $THEMES_URL and extract to $GHOSTTY_CONFIG_DIR"
  fi
fi

# ====================
# Done
# ====================
log_info "Ghostty setup complete"
log_info "Restart Ghostty to apply changes, or reload config with: ctrl+shift+,"
if $DRY_RUN; then
  log_warn "Dry-run mode enabled — no changes were made"
fi
