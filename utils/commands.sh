#!/usr/bin/env bash
set -euo pipefail

GREEN=$'\033[0;32m'
RESET=$'\033[0m'

REPO_URL="https://github.com/nocapscripts/BashCommands.git"

# Resolve the real user's home even when run under sudo
if [[ -n "${SUDO_USER:-}" ]]; then
    REAL_USER="$SUDO_USER"
else
    REAL_USER="$USER"
fi

if command -v getent >/dev/null 2>&1; then
    USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
else
    USER_HOME="$(eval echo "~$REAL_USER")"
fi

DEST="$USER_HOME/Commands"

init() {
    if [[ -d "$DEST/.git" ]]; then
        echo "Commands already installed, pulling latest..."
        sudo -u "$REAL_USER" git -C "$DEST" pull
    else
        rm -rf "$DEST"   # in case it exists but isn't a git repo
        git clone "$REPO_URL" "$DEST"
        chown -R "$REAL_USER:$REAL_USER" "$DEST"
    fi

    if ! grep -qF 'source ~/Commands/commands.bash' "$USER_HOME/.bashrc" 2>/dev/null; then
        echo 'source ~/Commands/commands.bash' >> "$USER_HOME/.bashrc"
        chown "$REAL_USER:$REAL_USER" "$USER_HOME/.bashrc"
    fi

    echo
    echo -e "${GREEN}====================================${RESET}"
    echo -e "${GREEN} Setup complete!                    ${RESET}"
    echo -e "${GREEN} Restart terminal to apply changes  ${RESET}"
    echo -e "${GREEN}====================================${RESET}"
}

init
