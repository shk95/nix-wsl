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

# `tool/checks/test` skips this build by default, because nothing on a
# non-NixOS host can activate the result. This is the deliberate way to ask
# for it; `CHECKS_BUILD_ALL=1 tool/checks/test` is the other.

# Build the NixOS-WSL closure (~1.9 GiB)
[group('nixos-wsl')]
nixos-build:
    nix build --no-link --print-out-paths .#nixosConfigurations.wsl.config.system.build.toplevel

# NixOS-WSL's builder refuses to run unless EUID is 0 — it chowns paths inside
# the rootfs it assembles — so this needs a password and an agent cannot run
# it. It takes several minutes, because it runs a real `nixos-install` into a
# temporary root before archiving it.
#
# The output path is passed explicitly rather than left to the builder's
# default, which is `nixos.wsl` relative to whatever the cwd happens to be. It
# lands in the repo root and is gitignored; it is owned by root, so removing it
# needs sudo as well.

# Produce the rootfs archive that `wsl --import` takes (needs sudo)
[group('nixos-wsl')]
nixos-tarball:
    sudo $(nix build --no-link --print-out-paths .#nixosConfigurations.wsl.config.system.build.tarballBuilder)/bin/nixos-wsl-tarball-builder nixos.wsl
    @echo
    @echo "Wrote ./nixos.wsl (root-owned, gitignored). Now run: just nixos-stage"

# `wsl --import` will not take a UNC source path. `\\wsl.localhost\...` reads
# perfectly from `dir`, so it is not a permissions or 9p problem — the importer
# specifically does not accept one, and the failure does not say so. Copying the
# image onto a real Windows drive first is what makes the path plain and the
# command work. About four seconds over drvfs, not the minute you would expect.

# Copy the rootfs archive somewhere `wsl --import` will actually read it
[group('nixos-wsl')]
nixos-stage dest="/mnt/c/WSL":
    #!/usr/bin/env bash
    set -euo pipefail
    [ -f nixos.wsl ] || { echo "No ./nixos.wsl — run 'just nixos-tarball' first." >&2; exit 1; }
    [ -d "$(dirname "{{ dest }}")" ] || { echo "{{ dest }} is not reachable — is that drive mounted?" >&2; exit 1; }
    mkdir -p "{{ dest }}"
    cp nixos.wsl "{{ dest }}/nixos.wsl"
    gzip -t "{{ dest }}/nixos.wsl"
    win=$(printf '%s' "{{ dest }}/nixos.wsl" | sed 's|^/mnt/\([a-z]\)|\U\1:|; s|/|\\|g')
    echo
    echo "Staged and verified. From PowerShell or CMD — not from in here:"
    echo
    echo "  wsl --import NixOS C:\\WSL\\NixOS $win"
    echo "  wsl -d NixOS"
    echo
    echo "That registers a NEW distribution. Ubuntu is untouched;"
    echo "rollback is: wsl --unregister NixOS"

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
