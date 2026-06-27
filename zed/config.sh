#!/usr/bin/env bash
set -e

# ====================
# Defaults
# ====================
DRY_RUN=false
CHECK=false
KEYMAP_SRC=""
SETTINGS_SRC=""

ZED_CONFIG_DIR="$HOME/.config/zed"
ZED_KEYMAP="$ZED_CONFIG_DIR/keymap.json"
ZED_SETTINGS="$ZED_CONFIG_DIR/settings.json"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Populated by backup_configs() if backups are made
KEYMAP_BACKUP=""
SETTINGS_BACKUP=""

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
Zed editor config setup

Usage:
  ./config.sh [options]

Options:
  --keymap   <file>   Path to keymap.json to install   (default: ./keymap.json)
  --settings <file>   Path to settings.json to install (default: ./settings.json)
  --check             Verify installation without making changes
  --dry-run           Show actions without making changes
  --help              Show this help and exit

What this does:
  • Checks that Zed is installed
  • Ensures ~/.config/zed/ exists
  • Backs up any existing keymap.json / settings.json before overwriting
  • Copies your keymap.json and settings.json into ~/.config/zed/
  • Works on Ubuntu, Fedora, and macOS

Examples:
  ./config.sh
  ./config.sh --keymap ./my-keymap.json --settings ./my-settings.json
  ./config.sh --dry-run
  ./config.sh --check
EOF
}

# ====================
# Argument parsing
# ====================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --keymap)
        KEYMAP_SRC="$2"
        shift
        ;;
      --settings)
        SETTINGS_SRC="$2"
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
# Resolve source files
# ====================
resolve_sources() {
  KEYMAP_SRC="${KEYMAP_SRC:-$SCRIPT_DIR/keymap.json}"
  SETTINGS_SRC="${SETTINGS_SRC:-$SCRIPT_DIR/settings.json}"
}

# ====================
# --check mode
# ====================
run_checks() {
  log_info "Running Zed installation check..."
  local failures=0

  check_ok()   { log_ok "$1"; }
  check_fail() { log_fail "$1"; failures=$((failures + 1)); }

  # Zed binary
  if command -v zed &>/dev/null; then
    check_ok "zed binary found: $(command -v zed)"
  else
    check_fail "zed binary not found in PATH"
  fi

  # Config dir
  [ -d "$ZED_CONFIG_DIR" ] \
    && check_ok  "zed config dir exists: $ZED_CONFIG_DIR" \
    || check_fail "zed config dir missing: $ZED_CONFIG_DIR"

  # keymap.json
  [ -f "$ZED_KEYMAP" ] \
    && check_ok  "keymap.json exists: $ZED_KEYMAP" \
    || check_fail "keymap.json missing: $ZED_KEYMAP"

  # settings.json
  [ -f "$ZED_SETTINGS" ] \
    && check_ok  "settings.json exists: $ZED_SETTINGS" \
    || check_fail "settings.json missing: $ZED_SETTINGS"

  # Validate JSON syntax if jq is available
  if command -v jq &>/dev/null; then
    if [ -f "$ZED_KEYMAP" ]; then
      jq empty "$ZED_KEYMAP" 2>/dev/null \
        && check_ok  "keymap.json is valid JSON" \
        || check_fail "keymap.json is not valid JSON"
    fi
    if [ -f "$ZED_SETTINGS" ]; then
      jq empty "$ZED_SETTINGS" 2>/dev/null \
        && check_ok  "settings.json is valid JSON" \
        || check_fail "settings.json is not valid JSON"
    fi
  else
    log_warn "jq not found — skipping JSON validation"
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
# Pre-flight checks
# ====================
check_prerequisites() {
  log_info "Checking prerequisites..."

  # Zed must be installed
  if ! command -v zed &>/dev/null; then
    log_error "Zed is not installed or not in PATH."
    log_error "Install it from https://zed.dev and re-run this script."
    exit 1
  fi
  log_ok "Zed found: $(command -v zed)"

  # Source files must exist
  if [ ! -f "$KEYMAP_SRC" ]; then
    log_error "keymap.json source not found: $KEYMAP_SRC"
    log_error "Pass a path with --keymap or place keymap.json next to this script."
    exit 1
  fi
  log_ok "keymap source found: $KEYMAP_SRC"

  if [ ! -f "$SETTINGS_SRC" ]; then
    log_error "settings.json source not found: $SETTINGS_SRC"
    log_error "Pass a path with --settings or place settings.json next to this script."
    exit 1
  fi
  log_ok "settings source found: $SETTINGS_SRC"

  # Warn if jq is missing (optional but useful)
  # SKIPPED: There are comments to in keymap.json to make it more useful
  # if ! command -v jq &>/dev/null; then
  #   log_warn "jq not found — skipping JSON validation of source files"
  # else
  #   log_info "Validating source files with jq..."
  #   if ! jq empty "$KEYMAP_SRC" 2>/dev/null; then
  #     log_error "keymap.json is not valid JSON: $KEYMAP_SRC"
  #     exit 1
  #   fi
  #   log_ok "keymap.json is valid JSON"

  #   if ! jq empty "$SETTINGS_SRC" 2>/dev/null; then
  #     log_error "settings.json is not valid JSON: $SETTINGS_SRC"
  #     exit 1
  #   fi
  #   log_ok "settings.json is valid JSON"
  # fi
}

# ====================
# Ensure config dir exists
# ====================
ensure_config_dir() {
  if [ ! -d "$ZED_CONFIG_DIR" ]; then
    log_info "Creating Zed config directory: $ZED_CONFIG_DIR"
    run mkdir -p "$ZED_CONFIG_DIR"
  else
    log_info "Zed config directory already exists: $ZED_CONFIG_DIR"
  fi
}

# ====================
# Backup existing configs
# ====================
backup_configs() {
  local timestamp
  timestamp=$(date +%s)

  if [ -f "$ZED_KEYMAP" ]; then
    log_info "Backing up existing keymap.json"
    KEYMAP_BACKUP="$ZED_KEYMAP.backup.$timestamp"
    run cp "$ZED_KEYMAP" "$KEYMAP_BACKUP"
  fi

  if [ -f "$ZED_SETTINGS" ]; then
    log_info "Backing up existing settings.json"
    SETTINGS_BACKUP="$ZED_SETTINGS.backup.$timestamp"
    run cp "$ZED_SETTINGS" "$SETTINGS_BACKUP"
  fi
}

# ====================
# Copy configs
# ====================
copy_configs() {
  log_info "Copying keymap.json to $ZED_KEYMAP"
  run cp "$KEYMAP_SRC" "$ZED_KEYMAP"

  log_info "Copying settings.json to $ZED_SETTINGS"
  run cp "$SETTINGS_SRC" "$ZED_SETTINGS"
}

# ====================
# Final message
# ====================
print_completion_message() {
  echo ""
  log_info "Zed config setup complete"

  if $DRY_RUN; then
    log_warn "Dry-run mode enabled — no changes were made"
    return
  fi

  echo ""
  echo "To apply the changes, do ONE of the following:"
  echo "  1) Restart Zed"
  echo "  2) Or run:  cmd+shift+p → reload config"
  echo ""
  echo "Useful follow-ups:"
  echo "  • Verify everything is set up correctly:  ./config.sh --check"
  echo "  • Use a different keymap/settings file:   ./config.sh --keymap <file> --settings <file>"

  if [ -n "$KEYMAP_BACKUP" ]; then
    echo ""
    log_info "Your previous keymap.json was backed up to: $KEYMAP_BACKUP"
  fi
  if [ -n "$SETTINGS_BACKUP" ]; then
    log_info "Your previous settings.json was backed up to: $SETTINGS_BACKUP"
  fi
}

# ====================
# Main
# ====================
main() {
  parse_args "$@"
  resolve_sources

  if $CHECK; then
    run_checks
    exit $?
  fi

  check_prerequisites
  ensure_config_dir
  backup_configs
  copy_configs
  print_completion_message
}

main "$@"
