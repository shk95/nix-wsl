user := "user1"

# List all the just commands
default:
    @just --list

############################################################################
#
#  home-manager
#
############################################################################

# First-time activation, before the `home-manager` command exists on PATH
[group('home-manager')]
bootstrap:
    nix run home-manager/master -- switch --flake .#{{ user }}

[group('home-manager')]
switch:
    home-manager switch --flake .#{{ user }}

[group('home-manager')]
build:
    home-manager build --flake .#{{ user }}

[group('home-manager')]
news:
    home-manager news --flake .#{{ user }}

# List all home-manager generations
[group('home-manager')]
generations:
    home-manager generations

############################################################################
#
#  nix
#
############################################################################

# Update all the flake inputs
[group('nix')]
up:
    nix flake update

# Update a single input, e.g. `just upp nixpkgs`
[group('nix')]
upp input:
    nix flake update {{ input }}

[group('nix')]
check:
    nix flake check

# Format the nix code in this flake
[group('nix')]
fmt:
    nix fmt .

# Garbage collect unused nix store entries older than 7 days
[group('nix')]
gc:
    nix-collect-garbage --delete-older-than 7d

############################################################################
#
#  setup
#
############################################################################

# Make the home-manager-managed zsh the login shell
[group('setup')]
switch-shell:
    #!/usr/bin/env bash
    set -euo pipefail

    TARGET_SHELL="$HOME/.nix-profile/bin/zsh"

    if [ "$SHELL" = "$TARGET_SHELL" ]; then
      echo "Current shell is already $TARGET_SHELL"
      exit 0
    fi

    if ! grep -Fxq "$TARGET_SHELL" /etc/shells; then
      echo "Registering $TARGET_SHELL in /etc/shells (needs sudo)"
      echo "$TARGET_SHELL" | sudo tee -a /etc/shells
    fi

    chsh -s "$TARGET_SHELL"
    echo "Login shell updated. Restart the WSL terminal for it to take effect."
