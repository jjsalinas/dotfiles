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
curl -fsSL https://raw.githubusercontent.com/jjsalinas/dotfiles/main/install.sh | bash -s -- --theme clean --add-nvm
```

### Forgejo version

```bash
curl -fsSL https://git.puxorjensap.com/jjsalinas/dotfiles/raw/branch/main/install.sh | bash -s -- --theme clean --add-nvm
```

----
## Other configs
Scripts to setup the config for: **Doom emacs**, **Zed** editor and **Ghostty** terminal are present.

### Example: Ghostty terminal
Custom ghostty configuration setup can be quickly run 
  (`--help` for complete info and params):
```bash
./ghostty/ghostty-config.sh
```

Can also be run with a curl single liner:
```bash
curl -fsSL https://raw.githubusercontent.com/jjsalinas/dotfiles/main/ghostty/ghostty-config.sh | bash -s -- --theme Subliminal
```
```bash
curl -fsSL https://git.puxorjensap.com/jjsalinas/dotfiles/raw/branch/main/ghostty/ghostty-config.sh | bash -s -- --theme Subliminal
```

Same for Zed and Doom emacs, just run the config script under the same name folder of each.

