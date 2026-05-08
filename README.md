# My System Environment Hub

![macOS](https://img.shields.io/badge/macOS-Apple_Silicon-EEEEEE?logo=apple&logoColor=white)
![Shell](https://img.shields.io/badge/shell-zsh-EEEEEE?logo=gnu-bash&logoColor=white)
[![License: MIT](https://img.shields.io/badge/license-MIT-EEEEEE)](LICENSE)

A single-command bootstrap for a complete macOS development environment.

## Overview

This is my central hub for managing a full macOS development setup. It ties together dotfiles, shell configuration,
packages, SSH and GPG keys, and system and app preferences into a single, automated, and idempotent workflow
built on top of modular git submodules.

## Quick Start

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Amheklerior/sysenv/main/bootstrap.sh)"
```

The [`bootstrap`](./bootstrap.sh) script installs Homebrew, imports my GPG and SSH keys, installs
all packages and applications from the Brewfile, and symlinks my dotfiles.

Additionally, you can run the [`load-prefs`](./load-prefs.sh) script to set up system settings
as well as some apps settings. It accepts flags to determine which prefs should be applied, run
`load-prefs` with the `-h` or `--help` flag to see what's available.

Run the [`checkhealth.sh`](./checkhealth.sh) script to verify the setup completed with no issues.

## Repository Structure

```ruby
sysenv/
│
├── prefs/              # macOS system preferences and app settings 
├── dotfiles/           # my dotfiles (shell, git, nvim, and terminal configs)
├── packages/           # my Homebrew Brewfile — CLI tools, apps, and VS Code extensions
├── gpg/                # encrypted GPG keys and import automation script
├── ssh/                # encrypted SSH keys and setup automation script
│
├── setup-checklist.md  # full step-by-step checklist to setup a new machine exactly as I want
├── load-prefs.sh       # applies macOS system and app preferences (run with --help flag for more detail)
├── checkhealth.sh      # diagnostic script to verify the setup completed correctly
└── bootstrap.sh        # the holistic script which automates the setup process
```

Each subdirectory is a git submodule pointing to its own dedicated repository. This keeps sensitive material
isolated from configuration, makes individual components independently updatable, and allows any module to be
reused or forked on its own.

## License

Licensed under [MIT](LICENSE) © Andrea Amato 2026

_For information, see [TLDR Legal / MIT](https://www.tldrlegal.com/license/mit-license)_
