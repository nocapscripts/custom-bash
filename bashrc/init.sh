#!/bin/bash

# Define variables
REPO_URL="https://github.com/reduxscripts/arch-bash.git"  # Replace with your GitHub repo URL
CLONE_DIR="$HOME/arch-bash"  # Directory to clone the repository into
BACKUP_FILE="$HOME/.bashrc.bak"
NEW_BASHRC="$CLONE_DIR/.bashrc"  # Path to the new .bashrc file within the cloned repo

# Clone the GitHub repository
if [ -d "$CLONE_DIR" ]; then
  echo "Repository directory $CLONE_DIR already exists. Pulling latest changes..."
  cd "$CLONE_DIR"
  git pull
else
  echo "Cloning the repository from $REPO_URL..."
  git clone "$REPO_URL" "$CLONE_DIR"
fi

# Check if .bashrc exists before proceeding with backup and replacement
if [ -f "$HOME/.bashrc" ]; then
  # Backup the current .bashrc file
  cp "$HOME/.bashrc" "$BACKUP_FILE"
  echo "Backup created at $BACKUP_FILE"

  # Copy the new .bashrc file
  if [ -f "$NEW_BASHRC" ]; then
    cp "$NEW_BASHRC" "$HOME/.bashrc"
    echo "New .bashrc file copied from $NEW_BASHRC"
  else
    echo "New .bashrc file not found at $NEW_BASHRC"
    exit 1
  fi

  # Reload the .bashrc file
  source "$HOME/.bashrc"
  echo "Your .bashrc has been reloaded and backed up."
else
  echo ".bashrc does not exist. Skipping backup and replacement."
fi
