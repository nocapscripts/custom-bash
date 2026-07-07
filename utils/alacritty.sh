#!/usr/bin/env bash
set -euo pipefail

# =========================
#  COOL DESKTOP SETUP
# =========================

GREEN="\e[32m"
BLUE="\e[34m"
CYAN="\e[36m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"


info() {
    echo -e "${BLUE}[INFO]${RESET} $*"
}

ok() {
    echo -e "${GREEN}[✓]${RESET} $*"
}

warn() {
    echo -e "${YELLOW}[!]${RESET} $*"
}

fail() {
    echo -e "${RED}[X]${RESET} $*"
}


# -------------------------
# User detection
# -------------------------

REAL_USER="${SUDO_USER:-$USER}"

if command -v getent >/dev/null; then
    USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
else
    USER_HOME="/home/$REAL_USER"
fi


run_user() {
    if [[ "$REAL_USER" == "$USER" ]]; then
        "$@"
    else
        sudo -u "$REAL_USER" "$@"
    fi
}


run_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}



echo -e "${CYAN}====================================${RESET}"
echo -e "${GREEN}   Starting system customization    ${RESET}"
echo -e "${CYAN}====================================${RESET}"



# -------------------------
# Package manager detection
# -------------------------

if command -v pacman >/dev/null; then
    PM="pacman"

elif command -v dnf >/dev/null; then
    PM="dnf"

elif command -v apt >/dev/null; then
    PM="apt"

else
    fail "Unsupported distribution"
    exit 1
fi


info "Detected package manager: $PM"



# -------------------------
# Terminus Font
# -------------------------

echo -e "${BLUE}[1/4] Installing Terminus font...${RESET}"


case "$PM" in

pacman)
    run_root pacman -S --needed --noconfirm terminus-font
    ;;

dnf)
    run_root dnf install -y terminus-fonts
    ;;

apt)
    run_root apt update
    run_root apt install -y xfonts-terminus
    ;;

esac


ok "Terminus font installed"



# -------------------------
# Cinnamon focus mode
# -------------------------

echo -e "${BLUE}[2/4] Setting Cinnamon focus mode...${RESET}"


if command -v gsettings >/dev/null; then

    if command -v dbus-launch >/dev/null; then

        run_user dbus-launch \
            gsettings set \
            org.cinnamon.desktop.wm.preferences \
            focus-mode sloppy \
            || warn "Could not set Cinnamon focus mode"

    else

        run_user gsettings \
            set \
            org.cinnamon.desktop.wm.preferences \
            focus-mode sloppy \
            || warn "Could not set Cinnamon focus mode"

    fi

    ok "Cinnamon focus mode set"

else

    warn "gsettings not found, skipping Cinnamon tweak"

fi




# -------------------------
# Install Alacritty
# -------------------------

echo -e "${BLUE}[3/4] Checking Alacritty...${RESET}"


if command -v alacritty >/dev/null; then

    ok "Alacritty already installed"

else

    info "Installing Alacritty..."

    case "$PM" in


    pacman)

        run_root pacman \
            -S --needed --noconfirm \
            alacritty

        ;;


    dnf)

        run_root dnf \
            install -y \
            alacritty

        ;;


    apt)

        run_root apt update

        run_root apt install -y \
            alacritty

        ;;


    esac


    ok "Alacritty installed"

fi




# -------------------------
# Alacritty theme
# -------------------------

echo -e "${BLUE}[4/4] Installing Alacritty theme...${RESET}"


THEME_DIR="$USER_HOME/.local/share/alacritty-theme"
ALACRITTY_DIR="$USER_HOME/.config/alacritty"


mkdir -p "$THEME_DIR"
mkdir -p "$ALACRITTY_DIR"


if [[ -d "$THEME_DIR/.git" ]]; then

    info "Updating existing theme repo..."

    run_user git \
        -C "$THEME_DIR" \
        pull

else

    rm -rf "$THEME_DIR"

    run_user git clone \
        https://github.com/nocapscripts/alacritty-theme.git \
        "$THEME_DIR"

fi



if [[ -f "$THEME_DIR/alacritty.toml" ]]; then

    cp \
        "$THEME_DIR/alacritty.toml" \
        "$ALACRITTY_DIR/alacritty.toml"


    chown -R \
        "$REAL_USER:$REAL_USER" \
        "$ALACRITTY_DIR"


    ok "Alacritty theme installed"

else

    fail "alacritty.toml not found"

fi



echo
echo -e "${GREEN}====================================${RESET}"
echo -e "${GREEN} Setup complete!                    ${RESET}"
echo -e "${GREEN} Restart terminal to apply changes  ${RESET}"
echo -e "${GREEN}====================================${RESET}"
