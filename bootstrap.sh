#!/usr/bin/env bash

# Prevent the script from continuing silently after something goes wrong
#   -e            exit immediately on any error
#   -u            treat unset vars as errors
#   -o pipefail   make pipelines fail if any command in them fails
set -euo pipefail

TARGET_DIR="$HOME/dev/personal/devenv"
URL_REWRITE="-c url.https://github.com/.insteadOf=git@github.com:"
GPG="$SCRIPT_DIR/gpg-keys"
SSH="$SCRIPT_DIR/ssh-keys"

# install homebrew
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# disable homebrew analytics
if ! brew analytics state | grep -q "disabled"; then
  brew analytics off
fi

# install dependencies
brew install gh

# authenticate my Github account
if ! gh auth status &>/dev/null; then
  gh auth login
fi

# cloning or updating dev env repo
if [ ! -d "$TARGET_DIR" ]; then
  mkdir -p "$(dirname "$TARGET_DIR")"
  gh repo clone Amheklerior/devenv "$TARGET_DIR" -- "$URL_REWRITE" --recurse-submodules
else
  git -C "$TARGET_DIR" pull
  git -C "$TARGET_DIR" "$URL_REWRITE" submodule update --init --recursive
fi

# import GPG keys and ownertrust file
gpg --import "$GPG/keys/amheklerior.pub.asc"
gpg --import-ownertrust "$GPG/config/ownertrust.txt"
if ! gpg --list-secret-keys amheklerior &>/dev/null; then
  TMPFILE="$(mktemp)"
  gpg --decrypt -o "$TMPFILE" "$GPG/keys/amheklerior.sec.asc.gpg"
  gpg --import "$TMPFILE"
  rm -f "$TMPFILE"
fi

# create local SSH directory if it doesn't exist
mkdir -p ~/.ssh

# copy public SSH keys into the system
cp "$SSH/keys/*.pub" ~/.ssh

# copy decrypted SSH private keys into the system
gpg --decrypt "$SSH/keys/personal.gpg" >~/.ssh/personal
gpg --decrypt "$SSH/keys/work-server.gpg" >~/.ssh/work-server

# symlink SSH config
ln -sf "$SSH/hosts/config" ~/.ssh/config

# apply secure permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/personal ~/.ssh/work-server ~/.ssh/config
chmod 644 ~/.ssh/personal.pub ~/.ssh/work-server.pub
