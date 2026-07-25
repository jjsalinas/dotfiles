#!/usr/bin/env bash
set -e

# ====================
# Defaults
# ====================
DRY_RUN=false
CHECK=false
SKIP_SYNC=false

DOOM_CONFIG_DIR="$HOME/.config/doom"
DOOM_USER_CONFIG="$DOOM_CONFIG_DIR/config.el"
DOOM_INIT="$DOOM_CONFIG_DIR/init.el"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$SCRIPT_DIR/config.el"
INIT_SRC="$SCRIPT_DIR/init.el"

# Populated by backup_configs() if backups are made
CONFIG_BACKUP=""
INIT_BACKUP=""

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
Doom Emacs config setup

Usage:
  ./doom-config.sh [options]

Options:
  --skip-sync   Skip running `doom sync` after copying files
  --check       Verify installation without making changes
  --dry-run     Show actions without making changes
  --help        Show this help and exit

What this does:
  • Checks that Doom Emacs is installed (doom binary in PATH)
  • Ensures ~/.config/doom/ exists
  • Backs up any existing config.el / init.el before overwriting
  • Copies config.el and init.el from this repo into ~/.config/doom/
  • Runs `doom sync` to apply changes

Examples:
  ./doom-config.sh
  ./doom-config.sh --dry-run
  ./doom-config.sh --skip-sync
  ./doom-config.sh --check
EOF
}

# ====================
# Argument parsing
# ====================
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --skip-sync)
        SKIP_SYNC=true
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
  log_info "Running Doom Emacs installation check..."
  local failures=0

  check_ok()   { log_ok "$1"; }
  check_fail() { log_fail "$1"; failures=$((failures + 1)); }

  # Doom binary
  if command -v doom &>/dev/null; then
    check_ok "doom binary found: $(command -v doom)"
  else
    check_fail "doom binary not found in PATH"
  fi

  # Emacs binary
  if command -v emacs &>/dev/null; then
    check_ok "emacs binary found: $(command -v emacs)"
  else
    check_fail "emacs binary not found in PATH"
  fi

  # Config dir
  [ -d "$DOOM_CONFIG_DIR" ] \
    && check_ok  "doom config dir exists: $DOOM_CONFIG_DIR" \
    || check_fail "doom config dir missing: $DOOM_CONFIG_DIR"

  # config.el
  [ -f "$DOOM_USER_CONFIG" ] \
    && check_ok  "config.el exists: $DOOM_USER_CONFIG" \
    || check_fail "config.el missing: $DOOM_USER_CONFIG"

  # init.el
  [ -f "$DOOM_INIT" ] \
    && check_ok  "init.el exists: $DOOM_INIT" \
    || check_fail "init.el missing: $DOOM_INIT"

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

  if ! command -v doom &>/dev/null; then
    log_error "Doom Emacs is not installed or not in PATH."
    log_error "Install it from https://github.com/doomemacs/doomemacs and re-run this script."
    exit 1
  fi
  log_ok "doom found: $(command -v doom)"

  if ! command -v emacs &>/dev/null; then
    log_error "Emacs is not installed or not in PATH."
    exit 1
  fi
  log_ok "emacs found: $(command -v emacs)"

  if [ ! -f "$CONFIG_SRC" ]; then
    log_error "config.el source not found: $CONFIG_SRC"
    exit 1
  fi
  log_ok "config.el source found: $CONFIG_SRC"

  if [ ! -f "$INIT_SRC" ]; then
    log_error "init.el source not found: $INIT_SRC"
    exit 1
  fi
  log_ok "init.el source found: $INIT_SRC"
}

# ====================
# Ensure config dir exists
# ====================
ensure_config_dir() {
  if [ ! -d "$DOOM_CONFIG_DIR" ]; then
    log_info "Creating Doom config directory: $DOOM_CONFIG_DIR"
    run mkdir -p "$DOOM_CONFIG_DIR"
  else
    log_info "Doom config directory already exists: $DOOM_CONFIG_DIR"
  fi
}

# ====================
# Backup existing configs
# ====================
backup_configs() {
  local timestamp
  timestamp=$(date +%s)

  if [ -f "$DOOM_USER_CONFIG" ]; then
    log_info "Backing up existing config.el"
    CONFIG_BACKUP="$DOOM_USER_CONFIG.backup.$timestamp"
    run cp "$DOOM_USER_CONFIG" "$CONFIG_BACKUP"
  fi

  if [ -f "$DOOM_INIT" ]; then
    log_info "Backing up existing init.el"
    INIT_BACKUP="$DOOM_INIT.backup.$timestamp"
    run cp "$DOOM_INIT" "$INIT_BACKUP"
  fi
}

# ====================
# Copy configs
# ====================
copy_configs() {
  log_info "Copying config.el to $DOOM_USER_CONFIG"
  run cp "$CONFIG_SRC" "$DOOM_USER_CONFIG"

  log_info "Copying init.el to $DOOM_INIT"
  run cp "$INIT_SRC" "$DOOM_INIT"
}

# ====================
# Doom sync
# ====================
run_doom_sync() {
  if $SKIP_SYNC; then
    log_warn "Skipping doom sync (--skip-sync passed)"
    return
  fi

  log_info "Running doom sync..."
  run doom sync
}

# ====================
# Final message
# ====================
print_completion_message() {
  echo ""
  log_info "Doom Emacs config setup complete"

  if $DRY_RUN; then
    log_warn "Dry-run mode enabled — no changes were made"
    return
  fi

  echo ""
  echo "To apply the changes, do ONE of the following:"
  echo "  1) Restart Emacs"
  echo "  2) Or run:  doom sync  (if you used --skip-sync)"
  echo ""
  echo "Useful follow-ups:"
  echo "  • Verify everything is set up correctly:  ./doom-install.sh --check"
  echo "  • Re-run without syncing:                 ./doom-install.sh --skip-sync"

  if [ -n "$CONFIG_BACKUP" ]; then
    echo ""
    log_info "Your previous config.el was backed up to: $CONFIG_BACKUP"
  fi
  if [ -n "$INIT_BACKUP" ]; then
    log_info "Your previous init.el was backed up to:   $INIT_BACKUP"
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

  check_prerequisites
  ensure_config_dir
  backup_configs
  copy_configs
  run_doom_sync
  print_completion_message
}

main "$@"
