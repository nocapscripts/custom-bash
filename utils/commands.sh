#!/usr/bin/env bash
set -euo pipefail


init() {
    git clone https://github.com/nocapscripts/BashCommands.git
    cd BashCommands
    sudo mkdir -p ~/Commands
    sudo cp commands.bash ~/Commands/commands.bash
    echo 'source ~/Commands/commands.bash' >> ~/.bashrc
    source ~/.bashrc
    cd ..
    rm -rf BashCommands


    echo
    echo -e "${GREEN}====================================${RESET}"
    echo -e "${GREEN} Setup complete!                    ${RESET}"
    echo -e "${GREEN} Restart terminal to apply changes  ${RESET}"
    echo -e "${GREEN}====================================${RESET}"
}

init
