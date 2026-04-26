#!/usr/bin/env bash
set -euo pipefail

# ====================
# Defaults
# ====================
DRY_RUN=false
YES_ALL=false

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
Terminal apps installer — Ubuntu/Fedora, x86_64

Usage:
  ./install_terminal_apps.sh [options]

Options:
  --yes            Install all apps without prompting
  --dry-run        Show actions without making changes
  --help           Show this help and exit

What this does:
  • Shows a list of terminal apps to install
  • Marks which ones are already installed
  • Lets you select which ones to install
  • Installs selected apps via apt (Ubuntu) or dnf (Fedora)

Apps (package manager):
  glow   Render markdown in the terminal
  navi   Interactive cheatsheet tool
  tldr   Simplified man pages
  gping  Ping with a live graph
  bat    cat with syntax highlighting
  htop   Interactive process viewer
  btop   Resource monitor with graphs
  eza    Modern ls with tree view and colors
  fzf    Fuzzy finder for files, history, and more
  rg     ripgrep — fast grep that respects .gitignore

Apps (curl install):
  omz          Oh My Zsh — zsh framework and plugin manager
  lazygit      Terminal UI for git
  lazydocker   Terminal UI for docker
  nvm          Node Version Manager

Examples:
  ./install_terminal_apps.sh
  ./install_terminal_apps.sh --yes
  ./install_terminal_apps.sh --dry-run
EOF
}

# ====================
# Argument parsing
# ====================
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      YES_ALL=true
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

# --yes and --dry-run are contradictory; dry-run wins
if $YES_ALL && $DRY_RUN; then
  log_warn "--yes and --dry-run are both set; --dry-run takes precedence, nothing will be installed"
  YES_ALL=false
fi

# ====================
# Linux-only guard
# ====================
if [[ "$(uname -s)" != "Linux" ]]; then
  log_error "This script only supports Linux (Ubuntu/Fedora, x86_64). Exiting."
  exit 1
fi

# ====================
# Detect package manager
# ====================
detect_pkg_manager() {
  if command -v apt-get &>/dev/null; then
    echo "apt"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  else
    log_error "No supported package manager found (apt or dnf)"
    exit 1
  fi
}

PKG_MANAGER="$(detect_pkg_manager)"
log_info "Using package manager: $PKG_MANAGER"

# ====================
# App definitions
# format: "binary|package_name_apt|package_name_dnf|description"
# binary is used to check if already installed
# ====================
APPS=(
  "glow|glow|glow|Render markdown in the terminal"
  "navi|navi|navi|Interactive cheatsheet for commands"
  "tldr|tldr|tldr|Simplified man pages"
  "gping|gping|gping|Ping with a live graph"
  "bat|bat|bat|cat with syntax highlighting"
  "htop|htop|htop|Interactive process viewer"
  "btop|btop|btop|Resource monitor with graphs"
  "eza|eza|eza|Modern ls with tree view and colors"
  "fzf|fzf|fzf|Fuzzy finder for files, history, and more"
  "rg|ripgrep|ripgrep|Fast grep that respects .gitignore"
)

# ====================
# Curl-installed app definitions
# format: "binary|description"
# Each binary must have a matching install_<binary>() function below
# ====================
CURL_APPS=(
  "omz|Oh My Zsh — zsh framework and plugin manager"
  "lazygit|Terminal UI for git"
  "lazydocker|Terminal UI for docker"
  "nvm|Node Version Manager"
)

# ====================
# Field accessor — splits a pipe-delimited entry, returns the Nth field (1-based)
# ====================
get_field() {
  local entry="$1"
  local field="$2"
  echo "$entry" | cut -d'|' -f"$field"
}

# ====================
# Install functions (curl-based)
# ====================

# Oh My Zsh — installs to ~/.oh-my-zsh; no standalone binary
install_omz() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    log_warn "$HOME/.oh-my-zsh already exists, skipping"
    return
  fi
  if ! command -v zsh &>/dev/null; then
    log_info "zsh not found, installing first..."
    if [ "$PKG_MANAGER" = "apt" ]; then
      run sudo apt-get install -y zsh
    else
      run sudo dnf install -y zsh
    fi
  fi
  log_info "Installing Oh My Zsh..."
  if ! $DRY_RUN; then
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    log_info "[dry-run] would run Oh My Zsh installer from ohmyzsh/ohmyzsh"
  fi
}

# Fetch latest GitHub release tag for a repo (owner/repo).
# Prints the version string without a leading 'v', or exits 1 on failure.
# Honours GITHUB_TOKEN if set, to avoid the 60 req/hour anonymous rate limit.
fetch_latest_github_version() {
  local repo="$1"
  local auth_args=()
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    auth_args=(-H "Authorization: token ${GITHUB_TOKEN}")
  fi

  local response version
  response=$(curl -fsSL "${auth_args[@]}" \
    "https://api.github.com/repos/${repo}/releases/latest")

  # Detect a rate-limit response before trying to parse a version
  if echo "$response" | grep -qi "rate limit"; then
    log_error "GitHub API rate limit hit for ${repo}."
    log_error "Set the GITHUB_TOKEN environment variable to increase the limit."
    return 1
  fi

  version=$(echo "$response" | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')
  if [ -z "$version" ]; then
    log_error "Could not parse latest version for ${repo}"
    return 1
  fi
  echo "$version"
}

# Lazygit — latest release tarball from GitHub
install_lazygit() {
  log_info "Fetching latest lazygit release..."
  if ! $DRY_RUN; then
    local version url tmp
    version=$(fetch_latest_github_version "jesseduffield/lazygit")
    url="https://github.com/jesseduffield/lazygit/releases/download/v${version}/lazygit_${version}_Linux_x86_64.tar.gz"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    curl -fsSL "$url" | tar -xz -C "$tmp"
    sudo install -m755 "$tmp/lazygit" /usr/local/bin/lazygit
  else
    log_info "[dry-run] would download latest lazygit and install to /usr/local/bin"
  fi
}

# Lazydocker — latest release tarball from GitHub
install_lazydocker() {
  log_info "Fetching latest lazydocker release..."
  if ! $DRY_RUN; then
    local version url tmp
    version=$(fetch_latest_github_version "jesseduffield/lazydocker")
    url="https://github.com/jesseduffield/lazydocker/releases/download/v${version}/lazydocker_${version}_Linux_x86_64.tar.gz"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' RETURN
    curl -fsSL "$url" | tar -xz -C "$tmp"
    sudo install -m755 "$tmp/lazydocker" /usr/local/bin/lazydocker
  else
    log_info "[dry-run] would download latest lazydocker and install to /usr/local/bin"
  fi
}

# NVM — Node Version Manager; installs to ~/.nvm, no binary in PATH
install_nvm() {
  if [ -d "$HOME/.nvm" ]; then
    log_warn "$HOME/.nvm already exists, skipping"
    return
  fi
  log_info "Fetching latest nvm release..."
  if ! $DRY_RUN; then
    local version
    version=$(fetch_latest_github_version "nvm-sh/nvm")
    # fetch_latest_github_version strips the leading 'v', but the nvm installer URL needs it back
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v${version}/install.sh" | bash
  else
    log_info "[dry-run] would run nvm installer from nvm-sh/nvm"
  fi
}

# Dispatcher — calls the matching install_<binary>() function
install_curl_app() {
  local binary="$1"
  local fn="install_${binary}"
  if declare -f "$fn" &>/dev/null; then
    "$fn"
  else
    log_error "No installer function found for '$binary'"
    return 1
  fi
}

# ====================
# Installed checks
# ====================

is_installed() {
  command -v "$1" &>/dev/null
}

# omz and nvm have no binary in PATH — check via their install directories
is_installed_curl() {
  local binary="$1"
  case "$binary" in
    omz) [ -d "$HOME/.oh-my-zsh" ] ;;
    nvm) [ -d "$HOME/.nvm" ] ;;
    *)   command -v "$binary" &>/dev/null ;;
  esac
}

# ====================
# Build unified list for the menu
# format: "binary|description|type"  (type = pkg | curl)
# ====================
ALL_ITEMS=()
for entry in "${APPS[@]}"; do
  IFS='|' read -r binary pkg_apt pkg_dnf desc <<< "$entry"
  ALL_ITEMS+=("${binary}|${desc}|pkg")
done
for entry in "${CURL_APPS[@]}"; do
  IFS='|' read -r binary desc <<< "$entry"
  ALL_ITEMS+=("${binary}|${desc}|curl")
done

# ====================
# Build selected[] and installed_flags[] arrays
# ====================
declare -a selected=()
declare -a installed_flags=()

n=${#ALL_ITEMS[@]}
for ((i=0; i<n; i++)); do
  IFS='|' read -r binary desc type <<< "${ALL_ITEMS[$i]}"
  already_installed=false
  if [ "$type" = "curl" ]; then
    if is_installed_curl "$binary"; then already_installed=true; fi
  else
    if is_installed "$binary"; then already_installed=true; fi
  fi
  if $already_installed; then
    installed_flags[i]=true
    selected[i]=false
  else
    installed_flags[i]=false
    selected[i]=true
  fi
done

# ====================
# Interactive selection or --yes
# ====================

# Number of lines print_menu outputs — must match print_menu exactly.
# 1 blank + 1 header + 1 blank + N apps + 1 blank = n + 4
MENU_STATIC_LINES=4

print_menu() {
  local current="$1"
  local binary desc type status_tag checkbox pointer
  echo ""
  echo "  Select apps to install  (↑/↓ move, space toggle, a select all, enter confirm)"
  echo ""
  for ((i=0; i<n; i++)); do
    IFS='|' read -r binary desc type <<< "${ALL_ITEMS[$i]}"
    status_tag=""
    ${installed_flags[$i]} && status_tag=" (installed)"
    [ "$type" = "curl" ] && status_tag="${status_tag} [curl]"
    checkbox="[ ]"
    ${selected[$i]} && checkbox="[x]"
    pointer="  "
    [ "$i" -eq "$current" ] && pointer="> "
    printf "%s%s %-14s  %-38s%s\n" "$pointer" "$checkbox" "$binary" "$desc" "$status_tag"
  done
  echo ""
}

if $YES_ALL; then
  for ((i=0; i<n; i++)); do
    if ! ${installed_flags[i]}; then selected[i]=true; fi
  done
else
  # Hide cursor; restore on any exit
  tput civis 2>/dev/null || true
  trap 'tput cnorm 2>/dev/null || true' EXIT

  current=0
  print_menu "$current"
  menu_lines=$((n + MENU_STATIC_LINES))

  while true; do
    IFS= read -rsn1 key
    if [[ "$key" == $'\033' ]]; then
      read -rsn2 -t 0.1 rest
      key="${key}${rest}"
    fi

    case "$key" in
      $'\033[A'|k)  # up
        current=$(( current > 0 ? current - 1 : 0 ))
        ;;
      $'\033[B'|j)  # down
        current=$(( current < n-1 ? current + 1 : n-1 ))
        ;;
      ' ')  # toggle
        if ${installed_flags[$current]}; then
          IFS='|' read -r binary _ _ <<< "${ALL_ITEMS[$current]}"
          # Print warning below menu without blocking; redraw will erase it next keypress
          tput cnorm 2>/dev/null || true
          printf "\n[WARN]  %s is already installed — cannot deselect\n" "$binary"
          tput civis 2>/dev/null || true
          # Account for the extra line we just printed in next redraw
          menu_lines=$((n + MENU_STATIC_LINES + 2))
        else
          if ${selected[$current]}; then selected[current]=false; else selected[current]=true; fi
          menu_lines=$((n + MENU_STATIC_LINES))
        fi
        ;;
      a|A)  # select all not-yet-installed
        for ((i=0; i<n; i++)); do
          if ! ${installed_flags[i]}; then selected[i]=true; fi
        done
        menu_lines=$((n + MENU_STATIC_LINES))
        ;;
      '')  # enter
        break
        ;;
    esac

    printf "\033[%dA" "$menu_lines"
    print_menu "$current"
    menu_lines=$((n + MENU_STATIC_LINES))
  done

  tput cnorm 2>/dev/null || true
fi

# ====================
# Confirm selection
# ====================
echo ""
log_info "Apps selected for installation:"
to_install=()
for ((i=0; i<n; i++)); do
  if ${selected[$i]}; then
    IFS='|' read -r binary _ _ <<< "${ALL_ITEMS[$i]}"
    to_install+=("$i")
    log_info "  + $binary"
  fi
done

if [ "${#to_install[@]}" -eq 0 ]; then
  log_info "Nothing to install."
  exit 0
fi

echo ""
if ! $YES_ALL && ! $DRY_RUN; then
  read -rp "Proceed? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { log_warn "Aborted."; exit 0; }
fi

# ====================
# Install
# ====================
if [ "$PKG_MANAGER" = "apt" ]; then
  log_info "Updating apt package index"
  run sudo apt-get update -qq
fi

for i in "${to_install[@]}"; do
  IFS='|' read -r binary desc type <<< "${ALL_ITEMS[$i]}"

  log_info "Installing $binary..."

  if [ "$type" = "curl" ]; then
    install_curl_app "$binary"
  else
    # Look up the full pkg entry by binary name to get per-manager package names
    pkg_entry=""
    for entry in "${APPS[@]}"; do
      IFS='|' read -r b pkg_apt pkg_dnf _d <<< "$entry"
      [ "$b" = "$binary" ] && pkg_entry="$entry" && break
    done
    IFS='|' read -r _ pkg_apt pkg_dnf _ <<< "$pkg_entry"

    if [ "$PKG_MANAGER" = "apt" ]; then
      run sudo apt-get install -y "$pkg_apt"
    else
      run sudo dnf install -y "$pkg_dnf"
    fi
  fi

  if ! $DRY_RUN; then
    already_installed=false
    if [ "$type" = "curl" ]; then
      if is_installed_curl "$binary"; then already_installed=true; fi
    else
      if is_installed "$binary"; then already_installed=true; fi
    fi
    if $already_installed; then
      log_ok "$binary installed successfully"
    else
      log_fail "$binary — not found in PATH after install, check manually"
    fi
  fi
done

# ====================
# Done
# ====================
echo ""
log_info "Done. You may need to restart your shell for all changes to take effect."
if $DRY_RUN; then
  log_warn "Dry-run mode — no changes were made"
fi
