#!/usr/bin/env bash

# Prevent the script from continuing silently after something goes wrong
#   -e            exit immediately on any error
#   -u            treat unset vars as errors
#   -o pipefail   make pipelines fail if any command in them fails
set -euo pipefail

TARGET_DIR="$HOME/dev/personal/devenv"

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
# Althouth the main devenv repo is public (no auth needed), it contains private
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
# NOTE: URL_REWRITE rewrites SSH URLs (git@github.com:) to HTTPS (https://github.com/)
#   on the fly. This is necessary because submodule URLs are hardcoded in .gitmodules
#   and use SSH, which requires keys that are not configured yet. The rewrite is
#   passed as a temporary git -c flag and does not persist to the git config.
#
# ------------------------------------------------------------------------------

URL_REWRITE="-c url.https://github.com/.insteadOf=git@github.com:"

# cloning or updating dev env repo
if [ ! -d "$TARGET_DIR" ]; then
  mkdir -p "$(dirname "$TARGET_DIR")"
  gh repo clone Amheklerior/devenv "$TARGET_DIR" -- "$URL_REWRITE" --recurse-submodules
else
  git -C "$TARGET_DIR" pull
  git -C "$TARGET_DIR" "$URL_REWRITE" submodule update --init --recursive
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
# devenv repo and all its submodules, so future git operations use SSH.
#
# NOTE: pushd/popd are used to move into the repo directory and back to where the
#  execution was, allowing for cleaner git commands (avoiding the noisy -C opt).
# ------------------------------------------------------------------------------

DEVENV_SSH_URL="git@github.com:Amheklerior/devenv.git"

pushd "$TARGET_DIR"

# switch parent repo remote to SSH
git remote set-url origin "$DEVENV_SSH_URL"

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
