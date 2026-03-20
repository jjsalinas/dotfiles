# dotfiles

Personal dotfiles for a clean, reproducible Zsh environment.

> Plus separate script for ghostty terminal setup.

This setup is focused on:
- Oh My Zsh
- Syntax highlighting (green/red command validation)
- fzf-powered history search
- Ergonomic word movement & deletion keybindings
- Minimal, modular configuration

## Requirements

- Zsh
- Oh My Zsh already installed
- Git
- Ubuntu or Fedora based distro

## Install

Clone the repository and run the installer:
```
git clone https://github.com/jjsalinas/dotfiles.git
cd dotfiles
./install.sh
```

### Options

Run `./install.sh --help` to see all available options and details.
```
./install.sh --help           # Show all options
./install.sh --dry-run        # Show actions without making changes
./install.sh --theme <n>      # Set Oh My Zsh theme (default: clean)
./install.sh --add-nvm        # Enable Node Version Manager config
./install.sh --update         # Update installed plugins
./install.sh --check          # Verify installation without making changes
```

## One-line install

> The one-line install will clone the repo to `~/.dotfiles` automatically.

```bash
curl -fsSL https://raw.githubusercontent.com/jjsalinas/dotfiles/main/install.sh | bash
```

With options
```bash
curl -fsSL https://raw.githubusercontent.com/jjsalinas/dotfiles/main/install.sh | bash -s -- --theme clean --add-nvm
```

### Gitea version
```bash
curl -fsSL https://git.puxorjensap.com/jjsalinas/dotfiles/raw/branch/main/install.sh | bash
```
```bash
curl -fsSL https://git.puxorjensap.com/jjsalinas/dotfiles/raw/branch/main/install.sh | bash -s -- --theme clean --add-nvm
```

----

## Ghostty terminal
Custom ghostty configuration setup can be quickly run:
```bash
./ghostty/config.sh
```

All info of this script can be check via:
```bash
./ghostty/config.sh --help
```

Can also be run with a curl single liner:
```bash
curl -fsSL https://raw.githubusercontent.com/jjsalinas/dotfiles/main/ghostty/config.sh | bash -s -- --theme Subliminal
```
```bash
curl -fsSL https://git.puxorjensap.com/jjsalinas/dotfiles/raw/branch/main/ghostty/config.sh | bash -s -- --theme Subliminal
```
