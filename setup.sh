#!/usr/bin/env bash
set -euo pipefail

# Only chmod actual files in this dir, not directories/dotfiles blindly
find . -maxdepth 1 -type f -name "*.sh" -exec chmod +x {} \;

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
USER_HOME=""

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
    REAL_USER="$(get_real_user)"
    USER_HOME="$(get_user_home)"

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
# Install FiraCode Nerd Font
# ─────────────────────────────────────────────
installFiraCodeNerdFont() {

    if command_exists fc-list &&
       fc-list :family | grep -qi "FiraCode Nerd Font"; then
        success "FiraCode Nerd Font already installed."
        return
    fi


    info "Installing FiraCode Nerd Font..."


    case "$PACKAGER" in

        apt|nala|dnf|dnf5|yum|zypper|xbps-install|pacman|emerge)

            if ! command_exists curl; then
                $SUDO_CMD "$PACKAGER" install -y curl
            fi

            if ! command_exists unzip; then
                $SUDO_CMD "$PACKAGER" install -y unzip
            fi

            FONT_DIR="$USER_HOME/.local/share/fonts/FiraCode"

            mkdir -p "$FONT_DIR"


            curl -L \
                https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip \
                -o /tmp/FiraCode.zip


            unzip -qo \
                /tmp/FiraCode.zip \
                -d "$FONT_DIR"


            rm -f /tmp/FiraCode.zip


            if command_exists fc-cache; then
                fc-cache -fv >/dev/null 2>&1
            fi


            success "FiraCode Nerd Font installed."

            ;;


        *)

            info "FiraCode Nerd Font installation skipped for $PACKAGER."

            ;;

    esac
}

# ─────────────────────────────────────────────
# Dependencies
# ─────────────────────────────────────────────
installDepend() {

    info "Installing dependencies..."

    case "$PACKAGER" in

        brew)

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

            brew install --cask font-fira-code-nerd-font || true

            return
            ;;


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
                fontconfig
                alacritty
            )

            command_exists bat || PKGS+=(bat)
            command_exists fastfetch || PKGS+=(fastfetch)
            command_exists nvim || PKGS+=(neovim)
            command_exists fzf || PKGS+=(fzf)
            command_exists zoxide || PKGS+=(zoxide)

            if dnf repoquery multitail >/dev/null 2>&1; then
                PKGS+=(multitail)
            fi

            $SUDO_CMD "$PACKAGER" install -y --skip-unavailable "${PKGS[@]}"
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
                fastfetch
            )


            # Debian uses batcat
            if command_exists bat; then
                :
            elif command_exists batcat; then
                :
            else
                PKGS+=(bat)
            fi


            command_exists nvim || PKGS+=(neovim)

            if apt-cache show multitail >/dev/null 2>&1; then
                PKGS+=(multitail)
            fi


            if apt-cache show alacritty >/dev/null 2>&1; then
                PKGS+=(alacritty)
            fi


            $SUDO_CMD "$PACKAGER" install -y "${PKGS[@]}"




            ;;


        pacman)

            if ! command_exists yay && ! command_exists paru; then

                $SUDO_CMD pacman \
                    -S --needed --noconfirm \
                    base-devel git


                git clone \
                    https://aur.archlinux.org/yay-git.git \
                    /tmp/yay-git


                (
                    cd /tmp/yay-git
                    makepkg -si --noconfirm
                )


                rm -rf /tmp/yay-git
            fi


            PKGS=(
                bash
                bash-completion
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
                bash \
                bash-completion \
                tar \
                tree \
                wget \
                unzip \
                git \
                curl \
                fontconfig \
                neovim

            ;;


        zypper)

            $SUDO_CMD zypper install -y \
                bash \
                bash-completion \
                tar \
                tree \
                wget \
                unzip \
                git \
                curl \
                fontconfig \
                neovim \
                fastfetch

            ;;


        xbps-install)

            $SUDO_CMD xbps-install -Sy \
                bash \
                bash-completion \
                tar \
                tree \
                wget \
                unzip \
                git \
                curl \
                fontconfig \
                neovim \
                fastfetch

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


        *)
            error "Unsupported package manager: $PACKAGER"
            return 1
            ;;

    esac



    # ─────────────────────────────────────────
    # Remove FiraCode Nerd Font
    # ─────────────────────────────────────────

    if command_exists fc-list &&
       fc-list :family | grep -qi "FiraCode Nerd Font"; then


        info "Removing FiraCode Nerd Font..."


        FONT_DIRS=(
            "$USER_HOME/.local/share/fonts"
            "/usr/share/fonts"
            "/usr/local/share/fonts"
            "$USER_HOME/.fzf"
        )


        for dir in "${FONT_DIRS[@]}"; do

            [[ -d "$dir" ]] || continue

            $SUDO_CMD find "$dir" \
                -iname "*FiraCode*Nerd*" \
                -type f \
                -delete 2>/dev/null || true

        done


        fc-cache -fv >/dev/null 2>&1


        if fc-list :family | grep -qi "FiraCode Nerd Font"; then
            error "FiraCode Nerd Font still exists."
        else
            success "FiraCode Nerd Font removed."
        fi

    fi

    installFiraCodeNerdFont

    success "Dependencies installed."
}

# ─────────────────────────────────────────────
# Install missing tools
# ─────────────────────────────────────────────
installStarshipAndFzf() {

    case "$PACKAGER" in
        brew|pacman)
            return
            ;;
    esac

    ## check if .fzf exists if exist remove .fzf and reinstall
    if command_exists fzf; then
        success "Removing existing fzf..."
        rm -rf "$USER_HOME/.fzf"
        success "Existing fzf removed."
    fi



    command_exists starship ||
        curl -fsSL https://starship.rs/install.sh | sh -s -- -y

    if ! command_exists fzf; then
        success "Installing fzf..."
        git clone --depth=1 https://github.com/junegunn/fzf.git "$USER_HOME/.fzf"
        "$USER_HOME/.fzf/install" --all
        success "fzf installed."
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

    mkdir -p "$USER_HOME/.config/fastfetch"

    ln -sf \
        "$GITPATH/config.jsonc" \
        "$USER_HOME/.config/fastfetch/config.jsonc"
}

linkConfig() {

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
installDepend
installStarshipAndFzf
installZoxide
create_fastfetch_config
linkConfig
alacritty
commands

success "Done! Restart your shell to see the changes."
