# My System Environment Hub

![macOS](https://img.shields.io/badge/macOS-Apple_Silicon-EEEEEE?logo=apple&logoColor=white)
![Shell](https://img.shields.io/badge/shell-zsh-EEEEEE?logo=gnu-bash&logoColor=white)
[![License: MIT](https://img.shields.io/badge/license-MIT-EEEEEE)](LICENSE)

A single-command bootstrap for a complete macOS development environment.

## Overview

This is my central hub for managing a full macOS development setup. It ties together dotfiles, shell configuration,
packages, SSH and GPG keys into a single, automated, idempotent workflow built on top of modular git submodules.

## Quick Start

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Amheklerior/sysenv/main/bootstrap.sh)"
```

The script installs Homebrew, authenticates with GitHub, imports my GPG and SSH keys, installs all packages and
applications from the Brewfile, and symlinks my dotfiles.

## Repository Structure

```ruby
sysenv/
├── bootstrap.sh    # the holistic script which automates the setup process
├── dotfiles/       # my dotfiles (shell, git, nvim, and terminal configs)
├── packages/       # my Homebrew Brewfile — CLI tools, apps, and VS Code extensions
├── gpg/            # encrypted GPG keys and import automation script
└── ssh/            # encrypted SSH keys and setup automation script
```

Each subdirectory is a git submodule pointing to its own dedicated repository. This keeps sensitive material
isolated from configuration, makes individual components independently updatable, and allows any module to be
reused or forked on its own.

## License

Licensed under [MIT](LICENCE) © Andrea Amato 2026

_For information, see [TLDR Legal / MIT](https://www.tldrlegal.com/license/mit-license)_
