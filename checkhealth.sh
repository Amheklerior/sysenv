#!/usr/bin/env bash

# Collect all check results — do not abort on individual failures (no -e flag)
set -uo pipefail

# Script location (base dir)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Script state: error/warning counters
errors=0
warnings=0

# ------------------------------------------------------------------------------
# OUTPUT FORMATTING & HELPERS
# ------------------------------------------------------------------------------

if [[ -t 1 ]]; then
  readonly RED='\033[0;31m'
  readonly YELLOW='\033[0;33m'
  readonly GREEN='\033[0;32m'
  readonly GREY='\033[0;37m'
  readonly PURPLE='\033[0;35m'
  readonly BLUE='\033[0;34m'
  readonly BOLD='\033[1m'
  readonly RESET='\033[0m'
else
  readonly RED='' YELLOW='' GREEN='' GREY='' PURPLE='' BLUE='' BOLD='' RESET=''
fi

heading() {
  echo -e "\n${BOLD}## $1${RESET}"
}

info() {
  echo -e "  ${GREY}INFO  $*${RESET}"
}

ok() {
  echo -e "  ${GREEN}${BOLD}OK${RESET}    $*"
}

warn() {
  echo -e "  ${YELLOW}${BOLD}WARN${RESET}  $*"
  ((warnings++))
}

fail() {
  echo -e "  ${RED}${BOLD}ERROR${RESET} $*"
  ((errors++))
}

# ------------------------------------------------------------------------------
# SYSTEM CHECKS
# ------------------------------------------------------------------------------

heading "System"

if [[ "$(uname -s)" == "Darwin" ]]; then
  ok "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
else
  fail "Not running macOS — detected: $(uname -s)"
fi

if [[ "$(uname -m)" == "arm64" ]]; then
  ok "Apple Silicon (arm64)"
else
  fail "Not Apple Silicon — detected: $(uname -m)"
fi

# ------------------------------------------------------------------------------
# HOMEBREW
# ------------------------------------------------------------------------------

heading "Homebrew & Packages"

if ! command -v brew &>/dev/null; then
  fail "Homebrew not installed"
else
  ok "Homebrew $(brew --version | head -1 | awk '{print $2}') installed at ${BLUE}$(brew --prefix)${RESET}"

  if brew analytics 2>/dev/null | grep -q "disabled"; then
    ok "Analytics disabled"
  else
    warn "Analytics may be enabled — run: brew analytics off"
  fi
fi

brewfile="$HOME/.config/homebrew/Brewfile"

if [[ ! -L "$brewfile" ]]; then
  fail "${BLUE}~/.config/homebrew/Brewfile${RESET} symlink not found"
else
  ok "${BLUE}~/.config/homebrew/Brewfile${RESET} ${PURPLE}→ $(readlink "$brewfile")${RESET}"
  info "Running brew bundle check (this may take a moment)..."

  if brew bundle check --global &>/dev/null; then
    ok "All packages installed (Brewfile satisfied)"
  else
    fail "Some packages are missing:"
    brew bundle check --global --verbose 2>&1 | grep "^x " | while IFS= read -r pkg; do
      echo "        $pkg"
    done
  fi
fi

# ------------------------------------------------------------------------------
# SHELL & PLUGINS
# ------------------------------------------------------------------------------

heading "Shell setup and plugins"

brew_zsh="$(brew --prefix 2>/dev/null)/bin/zsh"

if [[ ! -f "$brew_zsh" ]]; then
  fail "Homebrew zsh not found at ${BLUE}$brew_zsh${RESET}"
else
  ok "Homebrew zsh found at ${BLUE}$brew_zsh${RESET}"

  if grep -Fxq "$brew_zsh" /etc/shells 2>/dev/null; then
    ok "${BLUE}$brew_zsh${RESET} is in ${BLUE}/etc/shells${RESET}"
  else
    fail "${BLUE}$brew_zsh${RESET} is not in ${BLUE}/etc/shells${RESET}"
  fi

  if [[ "$SHELL" == "$brew_zsh" ]]; then
    ok "Default login shell is ${BLUE}$brew_zsh${RESET}"
  else
    fail "Default login shell is ${BLUE}$SHELL${RESET} (expected ${BLUE}$brew_zsh${RESET})"
  fi
fi

if [[ -d "$HOME/.config/plugins/fzf-tab" ]]; then
  ok "fzf-tab installed at ${BLUE}~/.config/plugins/fzf-tab${RESET}"
else
  fail "fzf-tab not found at ${BLUE}~/.config/plugins/fzf-tab${RESET}"
fi

# ------------------------------------------------------------------------------
# GITHUB CLI
# ------------------------------------------------------------------------------

heading "GitHub CLI"

if ! command -v gh &>/dev/null; then
  warn "gh not installed"
else
  ok "gh $(gh --version | head -1 | awk '{print $3}') installed"

  if gh auth status &>/dev/null; then
    gh_user=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
    ok "Authenticated as $gh_user"
  else
    warn "Not authenticated — run: gh auth login"
  fi
fi

# ------------------------------------------------------------------------------
# GPG
# ------------------------------------------------------------------------------

heading "GPG"

if ! command -v gpg &>/dev/null; then
  fail "gpg not installed"
else
  ok "gpg $(gpg --version | head -1 | awk '{print $3}') installed"

  if gpg --list-secret-keys "amheklerior" 2>/dev/null | grep -q "amheklerior"; then
    ok "Secret key for 'amheklerior' found"
  else
    fail "No secret key found for 'amheklerior'"
  fi

  if gpg --list-keys "amheklerior" 2>/dev/null | grep -q "amheklerior"; then
    ok "Public key for 'amheklerior' found"
  else
    fail "No public key found for 'amheklerior'"
  fi
fi

# ------------------------------------------------------------------------------
# SSH
# ------------------------------------------------------------------------------

heading "SSH"

if [[ ! -d "$HOME/.ssh" ]]; then
  fail "${BLUE}~/.ssh${RESET} directory not found"
else
  ssh_dir_perms=$(stat -f "%OLp" "$HOME/.ssh")
  if [[ "$ssh_dir_perms" == "700" ]]; then
    ok "${BLUE}~/.ssh${RESET} exists ${GREY}(permissions: 700)${RESET}"
  else
    warn "${BLUE}~/.ssh${RESET} exists but has permissions $ssh_dir_perms ${GREY}(expected 700)${RESET}"
  fi

  ssh_found_keys=0
  for ssh_key in "$HOME"/.ssh/*; do
    ssh_key_name=$(basename "$ssh_key")

    [[ -f "$ssh_key" ]] || continue
    [[ "$ssh_key_name" == *.pub ]] && continue
    [[ "$ssh_key_name" == "config" ]] && continue
    [[ "$ssh_key_name" == "known_hosts" ]] && continue

    ssh_found_keys=$((ssh_found_keys + 1))

    ssh_key_perms=$(stat -f "%OLp" "$ssh_key")
    if [[ "$ssh_key_perms" == "600" ]]; then
      ok "$ssh_key_name ${GREY}(permissions: 600)${RESET}"
    else
      warn "$ssh_key_name has permissions $ssh_key_perms ${GREY}(expected 600)${RESET}"
    fi

    if [[ -f "${ssh_key}.pub" ]]; then
      ssh_pub_perms=$(stat -f "%OLp" "${ssh_key}.pub")
      if [[ "$ssh_pub_perms" == "644" ]]; then
        ok "${ssh_key_name}.pub ${GREY}(permissions: 644)${RESET}"
      else
        warn "${ssh_key_name}.pub has permissions $ssh_pub_perms ${GREY}(expected 644)${RESET}"
      fi
    else
      fail "No public key found for $ssh_key_name"
    fi
  done

  [[ $ssh_found_keys -eq 0 ]] && fail "No private key files found in ${BLUE}~/.ssh/${RESET}"

  if [[ -L "$HOME/.ssh/config" ]]; then
    ok "${BLUE}~/.ssh/config${RESET} ${PURPLE}→ $(readlink "$HOME/.ssh/config")${RESET}"
  else
    fail "${BLUE}~/.ssh/config${RESET} symlink not found"
  fi

  ssh_test=$(ssh -T git@github.com -o ConnectTimeout=5 -o BatchMode=yes 2>&1 || true)
  if echo "$ssh_test" | grep -q "successfully authenticated"; then
    ok "GitHub SSH authentication works"
  else
    fail "GitHub SSH authentication failed — run: ssh -T git@github.com"
  fi
fi

# ------------------------------------------------------------------------------
# DOTFILES
# ------------------------------------------------------------------------------

heading "Dotfiles"

dotfiles_files=(
  ".gitconfig"
  ".zalias"
  ".zshenv"
  ".zshrc"
  ".config/starship.toml"
  "dev/personal/.markdownlintrc"
)

dotfiles_dirs=(
  ".config/delta"
  ".config/ghostty"
  ".config/git"
  ".config/nvim"
  ".config/zsh"
)

for dotfile in "${dotfiles_files[@]}" "${dotfiles_dirs[@]}"; do
  dotfile_path="$HOME/$dotfile"
  if [[ -L "$dotfile_path" ]]; then
    ok "${BLUE}~/$dotfile${RESET} ${PURPLE}→ $(readlink "$dotfile_path")${RESET}"
  elif [[ -e "$dotfile_path" ]]; then
    fail "${BLUE}~/$dotfile${RESET} exists but is not a symlink"
  else
    fail "${BLUE}~/$dotfile${RESET} not found"
  fi
done

# ------------------------------------------------------------------------------

heading "VSCode"

vscode_prefs="$HOME/Library/Application Support/Code/User"
for vscode_item in "settings.json" "keybindings.json" "snippets"; do
  if [[ -L "$vscode_prefs/$vscode_item" ]]; then
    ok "${BLUE}$vscode_item${RESET} ${PURPLE}→ $(readlink "$vscode_prefs/$vscode_item")${RESET}"
  elif [[ -e "$vscode_prefs/$vscode_item" ]]; then
    fail "${BLUE}$vscode_item${RESET} exists but is not a symlink"
  else
    fail "${BLUE}$vscode_item${RESET} not found"
  fi
done

# ------------------------------------------------------------------------------
# TOUCH ID FOR SUDO
# ------------------------------------------------------------------------------

heading "Touch ID for sudo"

if ! hidutil list 2>/dev/null | grep -qi "Apple Internal Keyboard"; then
  info "Apple keyboard not detected — Touch ID check skipped"
else
  sudo_local="/etc/pam.d/sudo_local"

  if [[ ! -f "$sudo_local" ]]; then
    fail "${BLUE}$sudo_local${RESET} not found"
  elif grep -qF "pam_tid.so" "$sudo_local"; then
    ok "Touch ID enabled for sudo (${BLUE}$sudo_local${RESET})"
  else
    fail "Touch ID not configured in ${BLUE}$sudo_local${RESET}"
  fi
fi

# ------------------------------------------------------------------------------
# PREFERENCES CHECKS
# ------------------------------------------------------------------------------
# Verifies that all preferences applied by load-prefs.sh are in effect.
# ------------------------------------------------------------------------------

# Usage: check_default <domain> <key> <expected> <label> where <domain> is either
#   a bundle ID, a full plist path, or NSGlobalDomain.
# Expected values follow what `defaults read` returns:
#   -bool true/false → "1"/"0", -string "S" → "S", -int/-float N → "N"
check_default() {
  local domain="$1" key="$2" expected="$3" label="$4" extra=()
  shift 4
  [[ "${1:-}" == "--" ]] && {
    shift
    extra=("$@")
  }
  local actual
  actual="$(defaults "${extra[@]+"${extra[@]}"}" read "$domain" "$key" 2>/dev/null)"
  # case-insensitive comparison
  if [[ "$(tr '[:lower:]' '[:upper:]' <<<"$actual")" == "$(tr '[:lower:]' '[:upper:]' <<<"$expected")" ]]; then
    ok "$label"
  else
    warn "$label (got: ${actual:-<not set>})"
  fi
}

heading "macOS system preferences"

# Rapport
rapport_name="$(defaults read "com.apple.rapport" "familySyncedName" 2>/dev/null)"
if [[ "$rapport_name" == *"amheklerior"* ]]; then
  ok "Rapport: name contains 'amheklerior' (${rapport_name})"
else
  warn "Rapport: wtf dude! name '${rapport_name}' does not contain 'amheklerior'"
fi

# Software updates
check_default "/Library/Preferences/com.apple.SoftwareUpdates" "AutomaticCheckEnabled" "1" "Updates: automatic check enabled"
check_default "/Library/Preferences/com.apple.SoftwareUpdates" "AutomaticDownload" "1" "Updates: automatic download enabled"
check_default "/Library/Preferences/com.apple.SoftwareUpdates" "ConfigDataInstall" "1" "Updates: config data install enabled"
check_default "/Library/Preferences/com.apple.SoftwareUpdates" "CriticalUpdateInstall" "1" "Updates: critical update install enabled"

# Locale
check_default "NSGlobalDomain" "AppleLocale" "en_IT" "Locale: en_IT"
check_default "NSGlobalDomain" "AKLastLocale" "en_IT" "Locale: AK last locale = en_IT"
check_default "com.apple.dock" "region" "IT" "Locale: dock region = IT"
check_default "com.apple.iCal" "NotificationsLastLocale" "en_IT" "Locale: iCal notifications locale = en_IT"
check_default "com.apple.iCal" "BirthdayEventsGenerationLastLocale" "en_IT" "Locale: iCal birthday events locale = en_IT"

# Timezone
check_default "/Library/Preferences/com.apple.timezone.auto" "Active" "1" "Timezone: auto-detect enabled"

# Display
check_default "NSGlobalDomain" "AppleFontSmoothing" "1" "Display: font smoothing enabled"
check_default "/Library/Preferences/com.apple.windowserver" "DisplayResolutionEnabled" "1" "Display: HiDPI resolution enabled"

# Sound
check_default "NSGlobalDomain" "com.apple.sound.uiaudio.enabled" "1" "Sound: UI audio enabled"
check_default "NSGlobalDomain" "com.apple.sound.beep.feedback" "0" "Sound: beep feedback disabled"
check_default "NSGlobalDomain" "com.apple.sound.beep.volume" "0.7" "Sound: beep volume = 0.7"
check_default "com.apple.BluetoothAudioAgent" "Apple Bitpool Min (editable)" "40" "Bluetooth: audio bitpool min = 40"

# Keyboard
check_default "NSGlobalDomain" "AppleKeyboardUIMode" "2" "Keyboard: full keyboard access enabled"
check_default "NSGlobalDomain" "com.apple.keyboard.fnState" "0" "Keyboard: fn key = media keys"
check_default "com.apple.HIToolbox" "AppleFnUsageType" "0" "Keyboard: fn usage type = 0"

# Text corrections
check_default "NSGlobalDomain" "NSAutomaticSpellingCorrectionEnabled" "0" "Text: auto spell-correct disabled"
check_default "NSGlobalDomain" "NSAutomaticCapitalizationEnabled" "0" "Text: auto-capitalize disabled"
check_default "NSGlobalDomain" "NSAutomaticDashSubstitutionEnabled" "0" "Text: auto dash substitution disabled"
check_default "NSGlobalDomain" "NSAutomaticPeriodSubstitutionEnabled" "0" "Text: auto period substitution disabled"
check_default "NSGlobalDomain" "NSAutomaticQuoteSubstitutionEnabled" "0" "Text: auto quote substitution disabled"

# Trackpad — internal
check_default "NSGlobalDomain" "com.apple.trackpad.scaling" "2.5" "Trackpad: tracking speed = 2.5"
check_default "com.apple.AppleMultitouchTrackpad" "Clicking" "0" "Trackpad: tap-to-click disabled (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "FirstClickThreshold" "1" "Trackpad: click threshold = 1 (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "SecondClickThreshold" "1" "Trackpad: second-click threshold = 1 (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "ActuationStrength" "0" "Trackpad: actuation strength = 0 (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "ActuateDetents" "0" "Trackpad: actuate detents disabled (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "ForceSuppressed" "1" "Trackpad: force touch suppressed (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "USBMouseStopsTrackpad" "1" "Trackpad: USB mouse stops trackpad (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "TrackpadRightClick" "1" "Trackpad: right click enabled (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "TrackpadPinch" "1" "Trackpad: pinch enabled (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "TrackpadTwoFingerDoubleTapGesture" "1" "Trackpad: two-finger double tap enabled (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "TrackpadRotate" "1" "Trackpad: rotate gesture enabled (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "TrackpadThreeFingerHorizSwipeGesture" "0" "Trackpad: three-finger horiz swipe disabled (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "TrackpadTwoFingerFromRightEdgeSwipeGesture" "3" "Trackpad: right-edge swipe = 3 (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "TrackpadThreeFingerVertSwipeGesture" "0" "Trackpad: three-finger vert swipe disabled (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "TrackpadFourFingerVertSwipeGesture" "0" "Trackpad: four-finger vert swipe disabled (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "TrackpadFourFingerPinchGesture" "0" "Trackpad: four-finger pinch disabled (internal)"
check_default "com.apple.AppleMultitouchTrackpad" "TrackpadFiveFingerPinchGesture" "0" "Trackpad: five-finger pinch disabled (internal)"

# Trackpad — bluetooth
check_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "Clicking" "0" "Trackpad: tap-to-click disabled (bluetooth)"
check_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "USBMouseStopsTrackpad" "1" "Trackpad: USB mouse stops trackpad (bluetooth)"
check_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadRightClick" "1" "Trackpad: right click enabled (bluetooth)"
check_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadPinch" "1" "Trackpad: pinch enabled (bluetooth)"
check_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadTwoFingerDoubleTapGesture" "1" "Trackpad: two-finger double tap enabled (bluetooth)"
check_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadRotate" "1" "Trackpad: rotate gesture enabled (bluetooth)"
check_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadThreeFingerHorizSwipeGesture" "0" "Trackpad: three-finger horiz swipe disabled (bluetooth)"
check_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadTwoFingerFromRightEdgeSwipeGesture" "3" "Trackpad: right-edge swipe = 3 (bluetooth)"
check_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadThreeFingerVertSwipeGesture" "0" "Trackpad: three-finger vert swipe disabled (bluetooth)"
check_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadFourFingerVertSwipeGesture" "0" "Trackpad: four-finger vert swipe disabled (bluetooth)"
check_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadFourFingerPinchGesture" "0" "Trackpad: four-finger pinch disabled (bluetooth)"
check_default "com.apple.driver.AppleBluetoothMultitouch.trackpad" "TrackpadFiveFingerPinchGesture" "0" "Trackpad: five-finger pinch disabled (bluetooth)"

# Trackpad — scroll & gestures
check_default "NSGlobalDomain" "AppleScrollerPagingBehavior" "1" "Trackpad: paging by scrollbar click enabled"
check_default "NSGlobalDomain" "com.apple.swipescrolldirection" "1" "Trackpad: natural scroll direction enabled"
check_default "NSGlobalDomain" "ContextMenuGesture" "1" "Trackpad: context menu gesture enabled"
check_default "NSGlobalDomain" "AppleEnableSwipeNavigateWithScrolls" "1" "Trackpad: swipe navigation enabled"

# Login window
check_default "/Library/Preferences/com.apple.loginwindow" "HideUserAvatarAndName" "1" "Login: user avatar and name hidden"
check_default "/Library/Preferences/com.apple.loginwindow" "LoginwindowText" "" "Login: login window text empty"
check_default "/Library/Preferences/com.apple.loginwindow" "RetriesUntilHint" "0" "Login: password hint disabled"
check_default "/Library/Preferences/com.apple.loginwindow" "PowerOffDisabled" "0" "Login: power-off button enabled"

# Screenshots
check_default "com.apple.screencapture" "type" "png" "Screenshots: format = png"
check_default "com.apple.screencapture" "location" "$HOME/Desktop" "Screenshots: save to Desktop"
check_default "com.apple.screencapture" "include-date" "1" "Screenshots: date included in filename"
check_default "com.apple.screencapture" "disable-shadow" "1" "Screenshots: shadow disabled"

# Siri
check_default "com.apple.assistant.support" "Assistant Enabled" "0" "Siri: disabled"
check_default "com.apple.Siri" "StatusMenuVisible" "0" "Siri: status menu hidden"
check_default "com.apple.Siri" "VoiceTriggerUserEnabled" "0" "Siri: voice trigger disabled"
check_default "com.apple.Siri" "SiriPrefStashedStatusMenuVisible" "0" "Siri: stashed menu not visible"

# Hot corners (all off)
for _corner in wvous-tl-corner wvous-tl-modifier wvous-tr-corner wvous-tr-modifier wvous-bl-corner wvous-bl-modifier wvous-br-corner wvous-br-modifier; do
  check_default "com.apple.dock" "$_corner" "0" "Hot corner: $_corner = 0"
done

# Dock gestures
check_default "com.apple.dock" "showMissionControlGestureEnabled" "0" "Dock: mission control gesture disabled"
check_default "com.apple.dock" "showAppExposeGestureEnabled" "0" "Dock: app expose gesture disabled"
check_default "com.apple.dock" "showLaunchpadGestureEnabled" "0" "Dock: launchpad gesture disabled"
check_default "com.apple.dock" "showDesktopGestureEnabled" "0" "Dock: show desktop gesture disabled"

# Dock appearance & behaviour
check_default "com.apple.dock" "orientation" "bottom" "Dock: position = bottom"
check_default "com.apple.dock" "autohide" "1" "Dock: auto-hide enabled"
check_default "com.apple.dock" "autohide-delay" "1000" "Dock: auto-hide delay = 1000"
check_default "com.apple.dock" "tilesize" "36" "Dock: tile size = 36"
check_default "com.apple.dock" "magnification" "1" "Dock: magnification enabled"
check_default "com.apple.dock" "largesize" "48" "Dock: magnified size = 48"
check_default "com.apple.dock" "launchanim" "1" "Dock: launch animation enabled"
check_default "com.apple.dock" "show-process-indicators" "1" "Dock: process indicators shown"
check_default "com.apple.dock" "minimize-to-application" "1" "Dock: minimize to application icon"
check_default "com.apple.dock" "mineffect" "scale" "Dock: minimize effect = scale"
check_default "com.apple.dock" "show-recents" "0" "Dock: recent apps hidden"

# Mission Control / Spaces
check_default "NSGlobalDomain" "AppleWindowTabbingMode" "fullscreen" "Windows: tab mode = fullscreen"
check_default "com.apple.WindowManager" "EnableStandardClickToShowDesktop" "1" "Windows: click desktop to show enabled"
check_default "NSGlobalDomain" "AppleSpacesSwitchOnActivate" "1" "Spaces: switch on activate"
check_default "com.apple.dock" "expose-group-apps" "1" "Spaces: Exposé grouped by app"
check_default "com.apple.dock" "mru-spaces" "0" "Spaces: auto-rearrange disabled"
check_default "com.apple.spaces" "spans-displays" "0" "Spaces: spans displays disabled"

# Finder
check_default "com.apple.finder" "CreateDesktop" "0" "Finder: no items on desktop"
check_default "com.apple.finder" "_FXSortFoldersFirstOnDesktop" "1" "Finder: folders first on desktop"
check_default "com.apple.finder" "ShowHardDrivesOnDesktop" "0" "Finder: hard drives hidden on desktop"
check_default "com.apple.finder" "ShowExternalHardDrivesOnDesktop" "0" "Finder: external drives hidden on desktop"
check_default "com.apple.finder" "ShowRemovableMediaOnDesktop" "0" "Finder: removable media hidden on desktop"
check_default "com.apple.finder" "ShowMountedServersOnDesktop" "0" "Finder: mounted servers hidden on desktop"
check_default "com.apple.finder" "NewWindowTarget" "PfLo" "Finder: new window target = home"
check_default "com.apple.finder" "NewWindowTargetPath" "file://$HOME/" "Finder: new window path = home"
check_default "com.apple.finder" "QuitMenuItem" "0" "Finder: quit menu item hidden"
check_default "com.apple.finder" "ShowPathbar" "1" "Finder: path bar shown"
check_default "com.apple.finder" "ShowStatusBar" "1" "Finder: status bar shown"
check_default "com.apple.finder" "FinderSpawnTab" "0" "Finder: folders open in new window"
check_default "com.apple.finder" "FXPreferredViewStyle" "Nlsv" "Finder: default view = list"
check_default "NSGlobalDomain" "AppleShowAllExtensions" "1" "Finder: all file extensions shown"
check_default "com.apple.finder" "FXEnableExtensionChangeWarning" "0" "Finder: extension change warning disabled"
check_default "com.apple.finder" "FXDefaultSearchScope" "SCcf" "Finder: search current folder by default"
check_default "NSGlobalDomain" "com.apple.springing.enabled" "1" "Finder: spring loading enabled"
check_default "NSGlobalDomain" "com.apple.springing.delay" "0" "Finder: spring loading delay = 0"
check_default "com.apple.desktopservices" "DSDontWriteNetworkStores" "1" "Finder: no .DS_Store on network drives"
check_default "com.apple.desktopservices" "DSDontWriteUSBStores" "1" "Finder: no .DS_Store on USB drives"
check_default "com.apple.frameworks.diskimages" "auto-open-ro-root" "1" "Finder: auto-open read-only disk images"
check_default "com.apple.frameworks.diskimages" "auto-open-rw-root" "1" "Finder: auto-open read-write disk images"
check_default "com.apple.finder" "OpenWindowForNewRemovableDisk" "1" "Finder: auto-open new removable disk"
check_default "com.apple.finder" "DisableAllAnimations" "1" "Finder: animations disabled"
check_default "com.apple.NetworkBrowser" "BrowseAllInterfaces" "1" "Network: browse all interfaces"

# Screensaver
check_default "com.apple.screensaver" "idleTime" "300" "Screensaver: idle time = 300s"
check_default "com.apple.screensaver" "askForPassword" "1" "Screensaver: password required"
check_default "com.apple.screensaver" "askForPasswordDelay" "0" "Screensaver: password delay = 0"

# Appearance
check_default "NSGlobalDomain" "AppleInterfaceStyle" "Dark" "Appearance: dark mode"
check_default "NSGlobalDomain" "NSTableViewDefaultSizeMode" "1" "Appearance: sidebar icon size = small"
check_default "NSGlobalDomain" "AppleShowScrollBars" "WhenScrolling" "Appearance: scroll bars when scrolling"
check_default "NSGlobalDomain" "AppleReduceDesktopTinting" "0" "Appearance: desktop tinting not reduced"
check_default "com.apple.WindowManager" "StandardHideDesktopIcons" "0" "Appearance: desktop icons shown"
check_default "com.apple.widgets" "widgetAppearance" "2" "Appearance: widgets monochrome"
check_default "NSGlobalDomain" "NSUseAnimatedFocusRing" "0" "Appearance: animated focus ring disabled"
check_default "NSGlobalDomain" "AppleMenuBarVisibleInFullscreen" "0" "Appearance: menu bar hidden in fullscreen"
check_default "NSGlobalDomain" "_HIHideMenuBar" "0" "Appearance: menu bar visible"

# Misc
check_default "NSGlobalDomain" "NSDisableAutomaticTermination" "1" "System: automatic app termination disabled"
check_default "com.apple.ncprefs" "content_visibility" "2" "Notifications: content visibility = 2"
check_default "com.apple.systempreferences" "NSQuitAlwaysKeepsWindows" "0" "System Prefs: quit doesn't keep windows"
check_default "com.apple.donotdisturb" "disableCloudSync" "0" "Do Not Disturb: cloud sync enabled"
check_default "com.apple.chronod" "remoteWidgetsEnabled" "1" "Widgets: remote widgets enabled"
check_default "com.apple.ImageCapture" "disableHotPlug" "1" "Image Capture: auto-open on connect disabled" -- -currentHost
check_default "NSGlobalDomain" "AppleLiveTextEnabled" "1" "Live Text: enabled"
check_default "NSGlobalDomain" "AppleActionOnDoubleClick" "None" "Windows: double-click title bar = none"
check_default "com.apple.TimeMachine" "DoNotOfferNewDisksForBackup" "1" "Time Machine: no disk backup prompts"
check_default "NSGlobalDomain" "NSDocumentSaveNewDocumentsToCloud" "0" "iCloud: don't auto-save to cloud"

# ------------------------------------------------------------------------------

csrutil status 2>/dev/null | grep -q "disabled" && sip_disabled=true || sip_disabled=false

heading "Safari"

if [[ "$sip_disabled" == false ]]; then
  info "SIP is enabled — disable SIP to read this domain (reboot into Recovery, run: csrutil disable)"
else
  check_default "com.apple.Safari" "BlockStoragePolicy" "0" "Block storage policy = 0"
  check_default "com.apple.Safari" "WebKitStorageBlockingPolicy" "2" "WebKit storage blocking = 2"
  check_default "com.apple.Safari" "WebKitPreferences.storageBlockingPolicy" "2" "WebKit prefs storage blocking = 2"
  check_default "com.apple.Safari" "SuppressSearchSuggestions" "1" "Search suggestions suppressed"
  check_default "com.apple.Safari" "ShowStandaloneTabBar" "1" "Standalone tab bar shown"
  check_default "com.apple.Safari" "NeverUseBackgroundColorInToolbar" "1" "No background color in toolbar"
  check_default "com.apple.Safari" "HideSuggestionsEmptyItemView" "1" "Suggestions empty view hidden"
  check_default "com.apple.Safari" "HideStartPageRecentlyClosedTabsEmptyItemView" "1" "Recently closed tabs empty view hidden"
  check_default "com.apple.Safari" "ReadingListSaveArticlesOfflineAutomatically" "1" "Reading list saves offline"
  check_default "com.apple.Safari" "AutoOpenSafeDownloads" "0" "Auto-open safe downloads disabled"
  check_default "com.apple.Safari" "WebKitPreferences.applePayCapabilityDisclosureAllowed" "1" "Apple Pay disclosure allowed"
  check_default "com.apple.Safari" "CommandClickMakesTabs" "1" "Cmd+click opens tabs"
  check_default "com.apple.Safari" "OpenNewTabsInFront" "0" "New tabs open in background"
fi

# ------------------------------------------------------------------------------

heading "Contacts"

check_default "NSGlobalDomain" "NSPersonNameDefaultShortNameEnabled" "0" "Short name format disabled"
check_default "NSGlobalDomain" "NSPersonNameDefaultShortNameFormat" "1" "Short name format = 1"

# ------------------------------------------------------------------------------

heading "Mail"

if [[ "$sip_disabled" == false ]]; then
  info "SIP is enabled — disable SIP to read this domain (reboot into Recovery, run: csrutil disable)"
else
  check_default "com.apple.Mail" "IndexJunk" "1" "Junk mail indexed"
fi

# ------------------------------------------------------------------------------

heading "Notes"

if [[ "$sip_disabled" == false ]]; then
  info "SIP is enabled — disable SIP to read this domain (reboot into Recovery, run: csrutil disable)"
else
  check_default "com.apple.Notes" "ICChecklistAutoSortEnabledDefaultsKey" "0" "Checklist auto-sort disabled"
fi

# ------------------------------------------------------------------------------

heading "Passwords"

check_default "com.apple.Passwords" "ShowServiceNamesInPasswords" "0" "Service names hidden"

# ------------------------------------------------------------------------------

heading "Alt-Tab"

check_default "com.lwouis.alt-tab-macos" "startAtLogin" "true" "Start at login"
check_default "com.lwouis.alt-tab-macos" "screenRecordingPermissionSkipped" "true" "Screen recording permission skipped"
check_default "com.lwouis.alt-tab-macos" "menubarIconShown" "false" "Menu bar icon hidden"
check_default "com.lwouis.alt-tab-macos" "NSStatusItem Visible Item-0" "0" "Status item not visible"
check_default "com.lwouis.alt-tab-macos" "updatePolicy" "0" "Update policy = 0"
check_default "com.lwouis.alt-tab-macos" "crashPolicy" "0" "Crash policy = 0"
check_default "com.lwouis.alt-tab-macos" "SUAutomaticallyUpdate" "0" "Auto update disabled"
check_default "com.lwouis.alt-tab-macos" "SUEnableAutomaticChecks" "0" "Automatic update checks disabled"
check_default "com.lwouis.alt-tab-macos" "windowDisplayDelay" "100" "Window display delay = 100ms"
check_default "com.lwouis.alt-tab-macos" "appearanceSize" "0" "Appearance size = 0"
check_default "com.lwouis.alt-tab-macos" "appearanceStyle" "2" "Appearance style = 2"
check_default "com.lwouis.alt-tab-macos" "windowOrder" "2" "Window order = 2"
check_default "com.lwouis.alt-tab-macos" "windowOrder2" "2" "Window order 2 = 2"
check_default "com.lwouis.alt-tab-macos" "appearanceVisibility" "0" "Appearance visibility = 0"
check_default "com.lwouis.alt-tab-macos" "fadeOutAnimation" "true" "Fade out animation enabled"
check_default "com.lwouis.alt-tab-macos" "hideStatusIcons" "true" "Status icons hidden"
check_default "com.lwouis.alt-tab-macos" "hideSpaceNumberLabels" "true" "Space number labels hidden"
check_default "com.lwouis.alt-tab-macos" "hideWindowlessApps" "true" "Windowless apps hidden"
check_default "com.lwouis.alt-tab-macos" "showTabsAsWindows" "false" "Tabs as windows disabled"
check_default "com.lwouis.alt-tab-macos" "previewFocusedWindow" "false" "Preview focused window disabled"
check_default "com.lwouis.alt-tab-macos" "hideAppBadges" "false" "App badges shown"
check_default "com.lwouis.alt-tab-macos" "showAppsOrWindows" "1" "Show apps or windows = 1"
check_default "com.lwouis.alt-tab-macos" "showTitles" "2" "Show titles = 2"
check_default "com.lwouis.alt-tab-macos" "titleTruncation" "1" "Title truncation = 1"
check_default "com.lwouis.alt-tab-macos" "holdShortcut" "\\U2318" "Hold shortcut = ⌘"
check_default "com.lwouis.alt-tab-macos" "arrowKeysEnabled" "false" "Arrow keys disabled"
check_default "com.lwouis.alt-tab-macos" "vimKeysEnabled" "true" "Vim keys enabled"
check_default "com.lwouis.alt-tab-macos" "shortcutStyle" "0" "Shortcut style = 0"
check_default "com.lwouis.alt-tab-macos" "quitAppShortcut" "Q" "Quit app shortcut = Q"
check_default "com.lwouis.alt-tab-macos" "closeWindowShortcut" "W" "Close window shortcut = W"
check_default "com.lwouis.alt-tab-macos" "toggleFullscreenWindowShortcut" "F" "Fullscreen shortcut = F"
check_default "com.lwouis.alt-tab-macos" "minDeminWindowShortcut" "M" "Minimize shortcut = M"
check_default "com.lwouis.alt-tab-macos" "hideShowAppShortcut" "" "Hide/show app shortcut = empty"

# ------------------------------------------------------------------------------

heading "KeyClu"

check_default "com.0804Team.KeyClu" "SUSendProfileInfo" "0" "Profile info not sent"
check_default "com.0804Team.KeyClu" "SUAutomaticallyUpdate" "0" "Auto update disabled"
check_default "com.0804Team.KeyClu" "SUEnableAutomaticChecks" "0" "Automatic update checks disabled"
check_default "com.0804Team.KeyClu" "launchAtLogin" "1" "Launch at login"
check_default "com.0804Team.KeyClu" "hideMenuIcon" "1" "Menu icon hidden"
check_default "com.0804Team.KeyClu" "silentLaunchQuit" "1" "Silent launch/quit"
check_default "com.0804Team.KeyClu" "activationKeyId" "4" "Activation key = Globe/Fn"
check_default "com.0804Team.KeyClu" "activationKeyType" "1" "Activation key type = 1"
check_default "com.0804Team.KeyClu" "activationPersistentKeyType" "0" "Persistent key type = 0"
check_default "com.0804Team.KeyClu" "keyHoldingDelay" "0.5" "Key holding delay = 0.5s"
check_default "com.0804Team.KeyClu" "dismissKeyType" "1" "Dismiss key type = 1"
check_default "com.0804Team.KeyClu" "appearance" "system" "Appearance = system"
check_default "com.0804Team.KeyClu" "amountOfColumns" "4" "Columns = 4"
check_default "com.0804Team.KeyClu" "fontSize" "12" "Font size = 12"
check_default "com.0804Team.KeyClu" "showHotkeyOnTheRight" "1" "Hotkey shown on right"
check_default "com.0804Team.KeyClu" "showHighlight" "1" "Highlight shown"
check_default "com.0804Team.KeyClu" "highlightAccentColor" "2" "Highlight accent color = 2"
check_default "com.0804Team.KeyClu" "showInactiveMenu" "1" "Inactive menu shown"
check_default "com.0804Team.KeyClu" "showAppIcon" "0" "App icon hidden"
check_default "com.0804Team.KeyClu" "showBookmarks" "0" "Bookmarks hidden"
check_default "com.0804Team.KeyClu" "showUserHiddenElements" "0" "User-hidden elements not shown"
check_default "com.0804Team.KeyClu" "enableMacosShortcuts" "1" "macOS shortcuts enabled"
check_default "com.0804Team.KeyClu" "enableCustomShortcuts" "1" "Custom shortcuts enabled"
check_default "com.0804Team.KeyClu" "enableMyShortcuts" "1" "My shortcuts enabled"

# ------------------------------------------------------------------------------

heading "HiddenBar"

check_default "com.dwarvesv.minimalbar" "isAutoStart" "1" "Auto-start enabled"
check_default "com.dwarvesv.minimalbar" "isShowPreferences" "0" "Preferences not shown on start"
check_default "com.dwarvesv.minimalbar" "isAutoHide" "1" "Auto-hide enabled"
check_default "com.dwarvesv.minimalbar" "numberOfSecondForAutoHide" "10" "Auto-hide delay = 10s"

# ------------------------------------------------------------------------------
# SUMMARY
# ------------------------------------------------------------------------------

echo -e "\n${BOLD}$(printf '─%.0s' {1..50})${RESET}"
if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
  echo -e "  ${GREEN}${BOLD}All checks passed!${RESET}"
elif [[ $errors -eq 0 ]]; then
  echo -e "  ${YELLOW}${BOLD}$warnings warning(s) — no errors${RESET}"
else
  echo -e "  ${RED}${BOLD}$errors error(s)${RESET}, ${YELLOW}$warnings warning(s)${RESET} found"
fi
echo -e "${BOLD}$(printf '─%.0s' {1..50})${RESET}\n"

[[ $errors -eq 0 ]] && exit 0 || exit 1
