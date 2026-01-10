#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# Colors & helpers
# ─────────────────────────────────────────────
RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'

info()    { printf "%b\n" "${YELLOW}$*${RC}"; }
success() { printf "%b\n" "${GREEN}$*${RC}"; }
error()   { printf "%b\n" "${RED}$*${RC}"; }

# ─────────────────────────────────────────────
# Globals
# ─────────────────────────────────────────────
PACKAGER=""
SUDO_CMD=""
SUGROUP=""
GITPATH="$(pwd)"

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ─────────────────────────────────────────────
# Environment checks
# ─────────────────────────────────────────────
checkEnv() {
    command_exists curl || { error "curl required"; exit 1; }

    # Homebrew first
    if command_exists brew; then
        PACKAGER="brew"
        info "Using Homebrew"
        SUDO_CMD=""
        return
    fi

    for pm in nala apt dnf yum pacman zypper emerge xbps-install nix-env; do
        if command_exists "$pm"; then
            PACKAGER="$pm"
            info "Using package manager: $pm"
            break
        fi
    done

    [ -n "$PACKAGER" ] || { error "No supported package manager found"; exit 1; }

    if command_exists sudo; then
        SUDO_CMD="sudo"
    elif command_exists doas && [ -f /etc/doas.conf ]; then
        SUDO_CMD="doas"
    else
        SUDO_CMD="su -c"
    fi
}

# ─────────────────────────────────────────────
# Dependency installation
# ─────────────────────────────────────────────
installDepend() {
    info "Installing dependencies"

    if [ "$PACKAGER" = "brew" ]; then
        brew update
        brew install bash bash-completion bat fastfetch tree multitail wget unzip \
            fontconfig neovim fzf zoxide starship
        brew tap homebrew/cask-fonts
        brew install --cask font-fira-code-nerd-font
        return
    fi

    DEPENDENCIES="bash bash-completion tar bat tree multitail wget unzip fontconfig"
    command_exists nvim || DEPENDENCIES="$DEPENDENCIES neovim"

    case "$PACKAGER" in
        pacman)
            if ! command_exists yay && ! command_exists paru; then
                $SUDO_CMD pacman --noconfirm -S base-devel
                git clone https://aur.archlinux.org/yay-git.git /opt/yay-git
                chown -R "$USER:$USER" /opt/yay-git
                (cd /opt/yay-git && makepkg --noconfirm -si)
            fi
            (command_exists yay && yay -S --noconfirm $DEPENDENCIES) ||
            (command_exists paru && paru -S --noconfirm $DEPENDENCIES)
            ;;
        nala|apt|dnf|yum|zypper|xbps-install)
            $SUDO_CMD "$PACKAGER" install -y $DEPENDENCIES
            ;;
        emerge)
            $SUDO_CMD emerge -v \
                app-shells/bash app-shells/bash-completion app-arch/tar \
                app-editors/neovim sys-apps/bat app-text/tree \
                app-text/multitail app-misc/fastfetch
            ;;
        nix-env)
            nix-env -iA \
                nixos.bash nixos.bash-completion nixos.gnutar \
                nixos.neovim nixos.bat nixos.tree \
                nixos.multitail nixos.fastfetch nixos.starship
            ;;
    esac

    # ── fastfetch for apt/nala (official GitHub release)
    if [[ "$PACKAGER" == "apt" || "$PACKAGER" == "nala" ]]; then
        command_exists fastfetch || {
            info "Installing fastfetch via GitHub"
            ARCH="$(uname -m)"
            case "$ARCH" in
                x86_64) ARCH="amd64" ;;
                aarch64|arm64) ARCH="arm64" ;;
                *) error "Unsupported arch for fastfetch"; exit 1 ;;
            esac
            URL="$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
                | grep browser_download_url | grep linux-$ARCH.deb | cut -d '"' -f 4)"
            wget -q "$URL" -O /tmp/fastfetch.deb
            $SUDO_CMD dpkg -i /tmp/fastfetch.deb
            rm -f /tmp/fastfetch.deb
        }
    fi

    # ── Font install (Linux)
    local FONT_NAME="FiraCode Nerd Font"
    if command_exists fc-list && ! fc-list :family | grep -iq "$FONT_NAME"; then
        info "Installing $FONT_NAME"
        wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.3/FiraCode.zip
        unzip -q FiraCode.zip -d FiraCode
        mkdir -p "$HOME/.local/share/fonts"
        mv FiraCode/*.ttf "$HOME/.local/share/fonts/"
        fc-cache -fv
        rm -rf FiraCode FiraCode.zip
    fi
}

# ─────────────────────────────────────────────
# Tools (skip if brew handled)
# ─────────────────────────────────────────────
installStarshipAndFzf() {
    [ "$PACKAGER" = "brew" ] && return
    command_exists starship || curl -sS https://starship.rs/install.sh | sh -s -- -y
    if ! command_exists fzf; then
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        "$HOME/.fzf/install" --all
    fi
}

installZoxide() {
    [ "$PACKAGER" = "brew" ] && return
    command_exists zoxide || curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
}

# ─────────────────────────────────────────────
# Config linking
# ─────────────────────────────────────────────
create_fastfetch_config() {
    USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6 || echo "$HOME")"
    mkdir -p "$USER_HOME/.config/fastfetch"
    ln -sf "$GITPATH/config.jsonc" "$USER_HOME/.config/fastfetch/config.jsonc"
}

linkConfig() {
    USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" 2>/dev/null | cut -d: -f6 || echo "$HOME")"
    mkdir -p "$USER_HOME/.config"

    [ -f "$USER_HOME/.bashrc" ] && mv "$USER_HOME/.bashrc" "$USER_HOME/.bashrc.bak"
    ln -sf "$GITPATH/.bashrc" "$USER_HOME/.bashrc"
    ln -sf "$GITPATH/starship.toml" "$USER_HOME/.config/starship.toml"
}

# ─────────────────────────────────────────────
# Run
# ─────────────────────────────────────────────
checkEnv
installDepend
installStarshipAndFzf
installZoxide
create_fastfetch_config
linkConfig

success "Done! Restart your shell to see the changes."
