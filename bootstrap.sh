#!/usr/bin/env bash

# Prevent the script from continuing silently after something goes wrong
#   -e            exit immediately on any error
#   -u            treat unset vars as errors
#   -o pipefail   make pipelines fail if any command in them fails
set -euo pipefail

TARGET_DIR="$HOME/dev/personal/sysenv"

# ------------------------------------------------------------------------------
# CHECK OS REQUIREMENTS
# ------------------------------------------------------------------------------
# This script is intended for macOS systems running on Apple Silicon only.
# Exits early with an error if the requirements are not met.
# ------------------------------------------------------------------------------

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Error: This script requires macOS. Detected OS: $(uname -s)" >&2
  exit 1
fi

if [ "$(uname -m)" != "arm64" ]; then
  echo "Error: This script requires an Apple Silicon processor. Detected architecture: $(uname -m)" >&2
  exit 1
fi

# ------------------------------------------------------------------------------
# HOMEBREW
# ------------------------------------------------------------------------------
# Homebrew is the package manager used to install any other dependency and tool.
# If it is not already present, install it and make it available on the PATH.
# Homebrew-managed binaries take precedence over system ones. Finally,
# analytics are disabled.
# ------------------------------------------------------------------------------

# install homebrew
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# disable homebrew analytics
if ! brew analytics state | grep -q "disabled"; then
  brew analytics off
fi

# ------------------------------------------------------------------------------
# DEPENDENCIES
# ------------------------------------------------------------------------------
# Installs the required CLI tools via Homebrew.
#   - gh:     the official GitHub CLI, used for authentication and repo cloning.
#   - gnupg:  GNU Privacy Guard, used for GPG key management.
# ------------------------------------------------------------------------------

# install dependencies
brew install gh gnupg

# ------------------------------------------------------------------------------
# GITHUB AUTHENTICATION
# ------------------------------------------------------------------------------
# Ensures the GitHub CLI is authenticated before attempting any repo operations.
# If not yet authenticated, it launches an interactive flow to authenticate (via
# browser or token). The script will exit if authentication fails or is cancelled,
# since all subsequent steps depend on it.
#
# Althouth the main sysenv repo is public (no auth needed), it contains private
# repos as submodules (requiring Github auth).
#
# WARN: make sure to choose HTTPS protocol since SSH keys are not yet set.
#
# ------------------------------------------------------------------------------

# authenticate my Github account
if ! gh auth status &>/dev/null; then
  gh auth login
fi

# ------------------------------------------------------------------------------
# REPOSITORY SETUP
# ------------------------------------------------------------------------------
# Clones my development environment repo into the new machine, including its
# submodules (--recurse-submodule). In case the repo already exists, just update
# with the latest changes, making sure to also update its submodule.
#
# NOTE: the -c url...insteadOf flag rewrites SSH URLs (git@github.com:) to HTTPS
#   (https://github.com/) on the fly. This is necessary because submodule URLs are
#   set in .gitmodules using SSH, which requires SSH keys that are not configured
#   yet. The flag is temporary and does not persist to the git config.
#
# ------------------------------------------------------------------------------

# cloning or updating dev env repo
if [ ! -d "$TARGET_DIR" ]; then
  mkdir -p "$(dirname "$TARGET_DIR")"
  gh repo clone Amheklerior/sysenv "$TARGET_DIR" -- \
    -c url.https://github.com/.insteadOf=git@github.com: \
    --recurse-submodules
else
  git -C "$TARGET_DIR" pull
  git -C "$TARGET_DIR" \
    -c url.https://github.com/.insteadOf=git@github.com: \
    submodule update --init --recursive
fi

# ------------------------------------------------------------------------------
# GPG KEYS SETUP
# ------------------------------------------------------------------------------

bash "$TARGET_DIR/gpg/setup.sh"

# ------------------------------------------------------------------------------
# SSH KEYS SETUP
# ------------------------------------------------------------------------------

bash "$TARGET_DIR/ssh/setup.sh"

# check ssh access
ssh -T git@github.com || true

# ------------------------------------------------------------------------------
# SWITCH REPO GIT PROTOCOL
# ------------------------------------------------------------------------------
# Now that SSH keys are setup, switch git protocol from HTTPS to SSH for the
# sysenv repo and all its submodules, so future git operations use SSH.
#
# NOTE: pushd/popd are used to move into the repo directory and back to where the
#  execution was, allowing for cleaner git commands (avoiding the noisy -C opt).
# ------------------------------------------------------------------------------

SYSENV_SSH_URL="git@github.com:Amheklerior/sysenv.git"

pushd "$TARGET_DIR"

# switch parent repo remote to SSH
git remote set-url origin "$SYSENV_SSH_URL"

# update the .git/config submodule URLs with those specified in .gitsubmodule
git submodule sync --recursive

# switch each submodule's own remote to SSH
git submodule foreach --recursive '
  ssh_url="$(git config --file "$toplevel/.gitmodules" "submodule.$name.url")"
  git remote set-url origin "$ssh_url"
'

# check remotes are now using SSH
git remote get-url origin
git submodule foreach --recursive 'git remote get-url origin'

popd

# ------------------------------------------------------------------------------
# INSTALL PACKAGES
# ------------------------------------------------------------------------------
# Install all packages, applications, Mac App Store apps, and VS Code extensions
# defined in the Brewfile. The bundle is globally available where Homebrew expects
# it (~/.config/homebrew/Brewfile) via a symlink.
#
# NOTE: the script won't interrupt on packages installation failures.
# NOTE: HOMEBREW_CASK_OPTS is set to bypass macOS Gatekeeper for cask installs.
#
# ------------------------------------------------------------------------------

export HOMEBREW_BUNDLE_FILE_GLOBAL="$HOME/.config/homebrew/Brewfile"
export HOMEBREW_CASK_OPTS="--no-quarantine"
mkdir -p "$(dirname "$HOMEBREW_BUNDLE_FILE_GLOBAL")"

# symlink the Brewfile bundle to be globally available
ln -sf "$TARGET_DIR/packages/Brewfile" "$HOMEBREW_BUNDLE_FILE_GLOBAL"

# install all packages, application, and vscode extensions from the bundle
if ! brew bundle check --global; then
  brew bundle install --global --verbose || :
fi

# ------------------------------------------------------------------------------
# BACKUP PRE-EXISTING DOTFILES
# ------------------------------------------------------------------------------
# Before symlinking, check for any pre-existing files or directories at the
# stow target locations. If found and not already stow symlinks, move them
# into a `~/.dotbak/<timestamp>/` backup dir to avoid conflicts.
# ------------------------------------------------------------------------------

DOTFILES_BACKUP_DIR="$HOME/.dotbak/$(date +%Y%m%d_%H%M%S)"

# these are the actual dot-files that will be symlinekd with stow
DOTFILES_FILES=(
  ".gitconfig"
  ".zalias"
  ".zprofile"
  ".zshenv"
  ".zshrc"
  ".config/starship.toml"
  "dev/personal/.markdownlintrc"
)

# these are the dirs that will be symlinked as is with stow, so check these
# as single units rather than dealing with their files directly
DOTFILES_DIRS=(
  ".config/delta"
  ".config/ghostty"
  ".config/git"
  ".config/nvim"
  ".config/zsh"
)

for f in "${DOTFILES_FILES[@]}"; do
  if [ -e "$HOME/$f" ] && [ ! -L "$HOME/$f" ]; then
    mkdir -p "$(dirname "$DOTFILES_BACKUP_DIR/$f")"
    mv "$HOME/$f" "$DOTFILES_BACKUP_DIR/$f"
  fi
done

for d in "${DOTFILES_DIRS[@]}"; do
  if [ -d "$HOME/$d" ] && [ ! -L "$HOME/$d" ]; then
    mkdir -p "$DOTFILES_BACKUP_DIR/$d"
    mv "$HOME/$d" "$DOTFILES_BACKUP_DIR/$d"
  fi
done

# ------------------------------------------------------------------------------
# LINK DOTFILES
# ------------------------------------------------------------------------------
# Symlinks all dotfiles from the dotfiles submodule into $HOME using GNU Stow.
# The `~/.config/` is ensured to exist as a real directory so stow descends
# into it and symlinks its subdirectories individually, rather than symlinking
# the entire `~/.config/` dir. Same goes for the `~/dev/personal/` dir.
# ------------------------------------------------------------------------------

mkdir -p "$HOME/.config"
mkdir -p "$HOME/dev/personal"

stow -R -d "$TARGET_DIR/dotfiles" -t "$HOME" home
