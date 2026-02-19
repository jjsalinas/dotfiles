# dotfiles

Personal dotfiles for a clean, reproducible Zsh environment.

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

```
curl -fsSL https://raw.githubusercontent.com/jjsalinas/dotfiles/main/install.sh | bash
```

With options
```
curl -fsSL https://raw.githubusercontent.com/jjsalinas/dotfiles/main/install.sh | bash -s -- --theme clean --add-nvm
```

### Gitea version
```bash
curl -fsSL https://puxorjensap.com/jjsalinas/dotfiles/raw/branch/main/install.sh | bash
curl -fsSL https://puxorjensap.com/jjsalinas/dotfiles/raw/branch/main/install.sh | bash -s -- --theme clean --add-nvm
```

