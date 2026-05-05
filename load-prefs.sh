#!/usr/bin/env bash

# Prevent the script from continuing silently after something goes wrong
#   -e            exit immediately on any error
#   -u            treat unset vars as errors
#   -o pipefail   make pipelines fail if any command in them fails
set -euo pipefail

# Define the directory path where preferences are located
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFS_DIR="$BASE_DIR/prefs"

# ------------------------------------------------------------------------------
# COLORS & FORMATTING
# ------------------------------------------------------------------------------
# Color and style variables for terminal output (when run on interactive shells).
# ------------------------------------------------------------------------------

if [[ -t 1 ]]; then
  readonly RED=$'\033[0;31m'
  readonly YELLOW=$'\033[0;33m'
  readonly GREEN=$'\033[0;32m'
  readonly GREY=$'\033[0;37m'
  readonly BOLD=$'\033[1m'
  readonly RESET=$'\033[0m'
else
  readonly RED='' YELLOW='' GREEN='' GREY='' BOLD='' RESET=''
fi

# ------------------------------------------------------------------------------
# LOGGING
# ------------------------------------------------------------------------------
# Helpers for consistent, color-coded log output.
# ------------------------------------------------------------------------------

log() { echo -e "${BOLD}[INFO] $*${RESET}"; }
trace() { echo -e "${GREY}$*${RESET}"; }
success() { echo -e "${GREEN}${BOLD}[OK] $*${RESET}"; }
warn() { echo -e "${YELLOW}${BOLD}[WARN] $*${RESET}" >&2; }
error() { echo -e "${RED}${BOLD}[ERROR] $*${RESET}" >&2; }

# ------------------------------------------------------------------------------
# PARSE FLAGS
# ------------------------------------------------------------------------------
# Reads optional flags passed to the install script and sets up env variables.
# ------------------------------------------------------------------------------

usage() {
  cat <<EOF
${BOLD}Usage:${RESET} $(basename "$0") [OPTIONS]

Apply macOS system and application preferences.

${BOLD}Options:${RESET}
  ${BOLD}--skip-osx${RESET}     Skip macOS system preferences
  ${BOLD}--skip-apple${RESET}   Skip Apple apps preferences (Safari, Mail, Notes, etc.)
                    ${GREY}Note: requires SIP disabled regardless of this flag${RESET}
  ${BOLD}--skip-apps${RESET}    Skip third-party apps preferences (Alt-Tab, KeyClu, HiddenBar, VSCode)
  ${BOLD}-h, --help${RESET}     Show this help message and exit
EOF
}

SKIP_OSX_PREFS=0
SKIP_APPLE_APPS_PREFS=0
SKIP_THIRD_PARTY_APPS_PREFS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  --skip-osx)
    SKIP_OSX_PREFS=1
    shift
    ;;
  --skip-apple)
    SKIP_APPLE_APPS_PREFS=1
    shift
    ;;
  --skip-apps)
    SKIP_THIRD_PARTY_APPS_PREFS=1
    shift
    ;;
  *)
    warn "Unknown flag: $1. Ignored."
    shift
    ;;
  esac
done

readonly SKIP_OSX_PREFS
readonly SKIP_APPLE_APPS_PREFS
readonly SKIP_THIRD_PARTY_APPS_PREFS

# ------------------------------------------------------------------------------
# SYSTEM/APPS PREFS SETUP LOGIG
# ------------------------------------------------------------------------------
# Applies macOS system's and applications' preferences.
#
# NOTE: Apple apps preferences (Safari, Mail, Notes, etc.) require SIP (System Integrity
# Protection) to be disabled first. In case SIP is enabled, they are skipped
# regardless of the --skip flag.
#
# ------------------------------------------------------------------------------

if ((SKIP_OSX_PREFS)) && ((SKIP_APPLE_APPS_PREFS)) && ((SKIP_THIRD_PARTY_APPS_PREFS)); then
  error "All --skip flags are set. There is nothing to apply. Remove at least one flag to proceed."
  echo ""
  usage
  exit 1
fi

# setup macOS system preferences
if ((!SKIP_OSX_PREFS)); then
  log "Applying system preferences..."
  bash "$PREFS_DIR/system/macos/osx-prefs.sh" &&
    success "System preferences have been applied." ||
    error "Failed to apply system preferences."
fi

# setup Apple apps prefs
if ((!SKIP_APPLE_APPS_PREFS)); then
  if csrutil status | grep -q "enabled"; then
    warn "SIP is enabled. Apple apps preferences require SIP to be disabled — skipping."
  else
    log "Applying Apple apps preferences..."
    bash "$PREFS_DIR/system/macos/apple-apps.sh" &&
      success "Apple apps preferences have been applied." ||
      error "Failed to apply Apple apps preferences."
  fi
fi

# setup third-party apps preferences
if ((!SKIP_THIRD_PARTY_APPS_PREFS)); then
  log "Applying third-party apps preferences..."

  # setup Alt-Tab prefs
  bash "$PREFS_DIR/apps/alt-tab/alt-tab-settings.sh" &&
    trace "Alt-Tab preferences have been applied." ||
    error "Failed to apply Alt-Tab preferences."

  # setup Key-Clu prefs
  bash "$PREFS_DIR/apps/keyclu/keyclu-settings.sh" &&
    trace "Key-Clu preferences have been applied." ||
    error "Failed to apply Key-Clu preferences."

  # setup Hiddenbar prefs
  bash "$PREFS_DIR/apps/hiddenbar/hiddenbar-settings.sh" &&
    trace "HiddenBar preferences have been applied." ||
    error "Failed to apply HiddenBar preferences."

  # clear the system from pre-existing VSCode prefs
  VSCODE_PREFS_PATH="$HOME/Library/Application Support/Code/User"
  mkdir -p "$VSCODE_PREFS_PATH"
  [[ -e "$VSCODE_PREFS_PATH/snippets" ]] && rm -rf "$VSCODE_PREFS_PATH/snippets" && warn "removed $VSCODE_PREFS_PATH/snippets/"
  [[ -e "$VSCODE_PREFS_PATH/keybindings.json" ]] && rm "$VSCODE_PREFS_PATH/keybindings.json" && warn "Removed $VSCODE_PREFS_PATH/keybindings.json"
  [[ -e "$VSCODE_PREFS_PATH/settings.json" ]] && rm "$VSCODE_PREFS_PATH/settings.json" && warn "Removed $VSCODE_PREFS_PATH/settings.json"

  # setup VSCode prefs
  stow -d "$PREFS_DIR/apps" -t "$VSCODE_PREFS_PATH" vscode &&
    trace "VSCode preferences have been applied." ||
    error "Failed to apply VSCode preferences."

  success "Third-party apps preferences have been applied."
fi

# ------------------------------------------------------------------------------
# THE END
# ------------------------------------------------------------------------------

success "🤘 System/apps preferences loaded!"
trace "Restart the system to apply all changes."
