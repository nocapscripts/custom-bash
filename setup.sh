#!/usr/bin/env bash
set -euo pipefail

chmod +x *

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
GITPATH="$(pwd)"
REAL_USER=""

command_exists() {
    command -v "$1" >/dev/null 2>&1
}


get_real_user() {

    if [[ -n "${SUDO_USER:-}" ]]; then
        echo "$SUDO_USER"
    else
        echo "$USER"
    fi
}


get_user_home() {

    if command_exists getent; then
        getent passwd "$REAL_USER" | cut -d: -f6
    else
        eval echo "~$REAL_USER"
    fi
}


run_root() {

    if [[ $EUID -eq 0 ]]; then
        "$@"

    elif command_exists sudo; then
        sudo "$@"

    elif command_exists doas; then
        doas "$@"

    else
        su -c "$(printf '%q ' "$@")"
    fi
}


run_user() {

    if [[ "$REAL_USER" == "$USER" ]]; then
        "$@"
    else
        runuser -u "$REAL_USER" -- "$@"
    fi
}

# ─────────────────────────────────────────────
# Environment
# ─────────────────────────────────────────────
checkEnv() {
    command_exists curl || {
        error "curl is required."
        exit 1
    }

    if command_exists brew; then
        PACKAGER="brew"
        info "Using Homebrew"
        return
    fi

    for pm in dnf5 dnf nala apt yum pacman zypper emerge xbps-install nix-env; do
        if command_exists "$pm"; then
            PACKAGER="$pm"
            info "Using package manager: $pm"
            break
        fi
    done

    [[ -n "$PACKAGER" ]] || {
        error "No supported package manager found."
        exit 1
    }

    if command_exists sudo; then
        SUDO_CMD="sudo"
    elif command_exists doas; then
        SUDO_CMD="doas"
    else
        SUDO_CMD="su -c"
    fi
}

# ─────────────────────────────────────────────
# Dependencies
# ─────────────────────────────────────────────
installDepend() {

    info "Installing dependencies..."

    if [[ "$PACKAGER" == "brew" ]]; then
        brew update

        brew install \
            bash \
            bash-completion \
            bat \
            fastfetch \
            tree \
            multitail \
            wget \
            unzip \
            fontconfig \
            neovim \
            fzf \
            zoxide \
            starship

        brew tap homebrew/cask-fonts
        brew install --cask font-fira-code-nerd-font

        return
    fi

    case "$PACKAGER" in

        dnf5|dnf)

            PKGS=(
                bash
                bash-completion
                tar
                tree
                wget
                unzip
                git
                curl
                alacritty
                fontconfig
            )

            command_exists bat || PKGS+=(bat)
            command_exists fastfetch || PKGS+=(fastfetch)
            command_exists nvim || PKGS+=(neovim)
            command_exists starship || PKGS+=(starship)
            command_exists fzf || PKGS+=(fzf)
            command_exists zoxide || PKGS+=(zoxide)

            if "$PACKAGER" repoquery multitail >/dev/null 2>&1; then
                PKGS+=(multitail)
            fi

            $SUDO_CMD "$PACKAGER" install -y "${PKGS[@]}"
            ;;

        apt|nala)

            PKGS=(
                bash
                bash-completion
                tar
                tree
                wget
                unzip
                git
                curl
                fontconfig
                bat
                alacritty
                multitail
            )

            command_exists nvim || PKGS+=(neovim)

            $SUDO_CMD "$PACKAGER" install -y "${PKGS[@]}"

            if ! command_exists fastfetch; then
                info "Installing fastfetch..."

                ARCH="$(uname -m)"

                case "$ARCH" in
                    x86_64) ARCH=amd64 ;;
                    aarch64|arm64) ARCH=arm64 ;;
                    *)
                        error "Unsupported architecture."
                        exit 1
                        ;;
                esac

                URL=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
                    | grep browser_download_url \
                    | grep "linux-${ARCH}.deb" \
                    | cut -d '"' -f4)

                wget -q "$URL" -O /tmp/fastfetch.deb
                $SUDO_CMD dpkg -i /tmp/fastfetch.deb
                rm -f /tmp/fastfetch.deb
            fi
            ;;

        pacman)

            if ! command_exists yay && ! command_exists paru; then
                $SUDO_CMD pacman -S --needed --noconfirm base-devel git

                git clone https://aur.archlinux.org/yay-git.git /tmp/yay-git

                (
                    cd /tmp/yay-git
                    makepkg -si --noconfirm
                )

                rm -rf /tmp/yay-git
            fi

            PKGS=(
                bash
                bash-completion
                tar
                bat
                fastfetch
                tree
                multitail
                wget
                unzip
                fontconfig
                neovim
                starship
                alacritty
                fzf
                zoxide
            )

            if command_exists yay; then
                yay -S --needed --noconfirm "${PKGS[@]}"
            else
                paru -S --needed --noconfirm "${PKGS[@]}"
            fi
            ;;

        yum)
            $SUDO_CMD yum install -y \
                bash bash-completion tar tree wget unzip \
                git curl fontconfig neovim bat
            ;;

        zypper)
            $SUDO_CMD zypper install -y \
                bash bash-completion tar tree wget unzip \
                git curl fontconfig neovim bat fastfetch
            ;;

        xbps-install)
            $SUDO_CMD xbps-install -Sy \
                bash bash-completion tar tree wget unzip \
                git curl fontconfig neovim bat fastfetch
            ;;

        emerge)

            $SUDO_CMD emerge -v \
                app-shells/bash \
                app-shells/bash-completion \
                app-arch/tar \
                app-editors/neovim \
                sys-apps/bat \
                app-text/tree \
                app-misc/fastfetch
            ;;

        nix-env)

            nix-env -iA \
                nixos.bash \
                nixos.bash-completion \
                nixos.gnutar \
                nixos.neovim \
                nixos.bat \
                nixos.tree \
                nixos.fastfetch \
                nixos.starship \
                nixos.fzf \
                nixos.zoxide
            ;;

    esac

    if command_exists fc-list && ! fc-list :family | grep -qi "FiraCode Nerd Font"; then

        info "Installing FiraCode Nerd Font..."

        wget -q https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/FiraCode.zip

        unzip -q FiraCode.zip -d FiraCode

        mkdir -p "$HOME/.local/share/fonts"

        mv FiraCode/*.ttf "$HOME/.local/share/fonts/"

        fc-cache -fv >/dev/null

        rm -rf FiraCode FiraCode.zip
    fi
}

# ─────────────────────────────────────────────
# Install missing tools
# ─────────────────────────────────────────────
installStarshipAndFzf() {

    case "$PACKAGER" in
        brew|dnf|dnf5|pacman)
            return
            ;;
    esac

    command_exists starship ||
        curl -fsSL https://starship.rs/install.sh | sh -s -- -y

    if ! command_exists fzf; then
        git clone --depth=1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
        "$HOME/.fzf/install" --all
    fi
}

installZoxide() {

    case "$PACKAGER" in
        brew|dnf|dnf5|pacman)
            return
            ;;
    esac

    command_exists zoxide ||
        curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
}

# ─────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────
create_fastfetch_config() {

    USER_HOME="$(get_user_home)"

    mkdir -p "$USER_HOME/.config/fastfetch"

    ln -sf \
        "$GITPATH/config.jsonc" \
        "$USER_HOME/.config/fastfetch/config.jsonc"
}

linkConfig() {

    USER_HOME="$(get_user_home)"

    mkdir -p "$USER_HOME/.config"

    [[ -f "$USER_HOME/.bashrc" && ! -f "$USER_HOME/.bashrc.bak" ]] &&
        mv "$USER_HOME/.bashrc" "$USER_HOME/.bashrc.bak"

    ln -sf "$GITPATH/.bashrc" "$USER_HOME/.bashrc"

    ln -sf \
        "$GITPATH/starship.toml" \
        "$USER_HOME/.config/starship.toml"
}

alacritty() {
    info "Installing Alacritty theme and fonts..."
    bash ./utils/alacritty.sh
}

commands() {
    info "Installing simplified commands"
    bash ./utils/commands.sh
}



# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────
checkEnv
alacritty
commands
installDepend
installStarshipAndFzf
installZoxide
create_fastfetch_config
linkConfig




success "Done! Restart your shell to see the changes."
