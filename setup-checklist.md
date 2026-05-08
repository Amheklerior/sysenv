# Setup Checklist

#### Bootstrap the system

- [ ] Complete the Apple welcome journey (with minimal setup)
- [ ] Bootstrap the system (run `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Amheklerior/sysenv/main/bootstrap.sh)"`)
- [ ] Disable SIP (enter recovery mode, run `csrutil disable`)
- [ ] Apply system and applications settings (run `~/dev/personal/sysenv/load-prefs.sh`)
- [ ] Check for issues during setup (run `~/dev/personal/sysenv/checkhealth.sh`)
- [ ] Enable SIP (enter recovery mode, run `csrutil enable`)

#### Setup System

- [ ] Install system updates
- [ ] Connect personal and work accounts (`⌘ + space` -> type "Internet Accounts")
- [ ] Enable FileVault disk encryption and save its recovery key (`⌘ + space` -> type "Privacy")
- [ ] Setup Touch-ID (`⌘ + space` -> type "Touch ID") _if relevant_
- [ ] Register payment cards and enable `hide-my-email` (`⌘ + space` -> type "Wallet and Apple Pay") _if relevant_

#### Setup Raycast

- [ ] Complete Raycast's welcome journey (no ext, replace emoji picker, open at login, grant full access)
- [ ] Remove Spotlight shortcut (`⌘ + space` -> type "Keyboard shortcut" -> disable them)
- [ ] Import Raycast settings (`⌘ + space` -> type "Import settings and data" -> select `~/dev/personal/sysenv/prefs/apps/raycast/*.rayconfig`)

#### Setup Mail

- [ ] Sync all emails
- [ ] Order mail boxes as: _main_ / _secondary_ / _work_
- [ ] Add _Newsletter_ folder to favorites
- [ ] Set warmer tones: _Cantalupe_ / _Salmon_ / _Honeydew_ (`Settings` > `Fonts & colors`)

#### Setup Notes

- [ ] Sync all notes from iCloud
- [ ] Set gallery view over list view
- [ ] Enable sorting of notes _by title_ (`Settings`)
- [ ] Uncheck automatic sorting of checked items in a list (`Settings`)
- [ ] Enable touch-id to unlock notes (`Settings`) _if relevant_

#### Setup Calendar

- [ ] Select the wanted calendars
- [ ] Set _start-time_ to _8:00_ and _end-time_ to _22:00_ (`Settings` > `General`)
- [ ] Set the view to a _14 hours_ window (`Settings` > `General`)
- [ ] Remove all default alerts for all calendars (`Settings` > `Alerts`)
- [ ] Enable events in year view (`Settings` > `Advanced`)
- [ ] Enable week numbers (`Settings` > `Advanced`)

#### Setup Finder

- [ ] Delete all tags (`Settings` > `Tags`)
- [ ] Add _Inbox_, _Resources_, and _Archive_ iCloud dirs (from the sidebar)
- [ ] Set the following order: _home_, _desktop_, _iCloud dirs_, _downloads_, _airdrop_ (from the sidebar)

#### Setup Contacts

- [ ] Make sure the address format is set to "Italy" (`Settings` > `General`)
- [ ] Add _Job Title_ field, and remove _Pronouns_ and _External links_ (`Settings` > `Template`)

#### Setup Telegram

- [ ] Login with QR code using the iPhone
- [ ] Disable large emoji (`settings` > `general`)
- [ ] Not include channels in notification badges (`settings` > `notifications`)
- [ ] Switch theme from _night accent_ to _system_ (`settings` > `appearance`)
- [ ] Select flat B/W app icon (`settings` > `appearance`)

#### Setup Other Apps

- [ ] Open **Photo** and **Messages** to sync with iCloud
- [ ] Open **Safari** and customize start page to only have _favorites_ and _reading list_
- [ ] Open **Alt-Tab** and grant it accessibility access rights (no screen recording)
- [ ] Open **Key-Clu** and grant it accessibility access rights
- [ ] Open **Hiddenbar** and declutter the menu bar

#### Final Touches

- [ ] Enable color dimming (`⌘ + space` -> type "Accessibility Display" > second notch grayscale color filter)
- [ ] Set a proper resolution (`⌘ + space` -> type "Displays")
- [ ] Set a cool wallpaper (`⌘ + space` -> type "Wallpaper")
- [ ] Disable screen savers (`⌘ + space` -> type "Wallpaper")
- [ ] Enable Apple Intelligence without Siri (`⌘ + space` -> type "System Settings")
- [ ] Review login and background items (add Alt-Tab, Hiddenbar, Key-Clu, and BetterDisplay)
- [ ] Set system and applications notifications (`⌘ + space` -> type "Notifications")
