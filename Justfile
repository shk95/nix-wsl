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
#  nixos-wsl  (M3 experiment)
#
############################################################################

# Evaluate and build the NixOS-WSL closure. tool/checks/test skips this build
# by default, because nothing on a non-NixOS host can activate it.
[group('nixos-wsl')]
nixos-build:
    nix build --no-link --print-out-paths .#nixosConfigurations.wsl.config.system.build.toplevel

# Produce the .tar.gz that `wsl --import` takes. NixOS-WSL's builder refuses to
# run unless EUID is 0 — it chowns paths inside the rootfs — so this needs a
# password and an agent cannot run it. Writes nixos-wsl.tar.gz to the cwd.
[group('nixos-wsl')]
nixos-tarball:
    sudo $(nix build --no-link --print-out-paths .#nixosConfigurations.wsl.config.system.build.tarballBuilder)/bin/nixos-wsl-tarball-builder

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
