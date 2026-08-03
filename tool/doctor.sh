#!/bin/sh
#
# Checks this machine can build, check and commit the project — and says
# plainly what is missing when it cannot.
#
# Run it at the start of a session. The failure it exists to prevent is the
# quiet one: a clone with no git hooks commits without a secret scan, and a
# machine with flakes disabled fails every command in a way that looks like a
# broken flake rather than a missing setting.

cd "$(dirname "$0")/.." || exit 1

red='\033[31m'; yellow='\033[33m'; green='\033[32m'; dim='\033[2m'; off='\033[0m'
failed=0

ok()   { printf "  ${green}✓${off} %s\n" "$1"; }
warn() { printf "  ${yellow}!${off} %s\n     ${dim}%s${off}\n" "$1" "$2"; }
bad()  { printf "  ${red}✗${off} %s\n     ${dim}%s${off}\n" "$1" "$2"; failed=1; }

echo "Toolchain"

if command -v nix >/dev/null 2>&1; then
  ok "nix $(nix --version | awk '{print $NF}')"
else
  bad "nix not on PATH" "Install it: https://docs.determinate.systems (recommended on WSL) or https://nixos.org/download/"
fi

# `nix config show` needs nix-command itself to inspect nix-command, so it
# cannot tell you whether nix-command is enabled. Asking the flake in this
# repository to resolve its own metadata tests both flags at once, the way
# every other command here actually needs them.
if nix flake metadata --no-write-lock-file >/dev/null 2>&1; then
  ok "nix-command and flakes enabled"
else
  bad "nix-command/flakes not enabled by default" \
      'export NIX_CONFIG="experimental-features = nix-command flakes" until the first home-manager switch writes it for you (see home/nix.nix)'
fi

command -v direnv >/dev/null 2>&1 && ok "direnv" \
  || warn "direnv not installed" "Optional. programs.direnv expects it once you switch; install via your OS package manager."

echo
echo "Version control"

hooks=$(git config core.hooksPath 2>/dev/null)
if [ "$hooks" = ".githooks" ]; then
  ok "git hooks enabled"
else
  # A hard failure, not a warning — see decisions/002 upstream. Without this a
  # clone commits with no formatting check, no lint and no secret scan.
  bad "git hooks are NOT enabled" "Run: git config core.hooksPath .githooks"
fi

command -v gitleaks >/dev/null 2>&1 && ok "gitleaks" \
  || warn "gitleaks not installed — commits will not be scanned for secrets" "CI scans too, but only after you have pushed."

command -v gh >/dev/null 2>&1 && ok "gh" \
  || warn "gh not installed — cannot read or file blocked issues" "Install: https://cli.github.com"

echo
echo "Flavours declared in flake.nix"
# What this host can do with each, in the two tiers tool/checks/test uses:
# every configuration is *evaluated* wherever you are — Nix evaluates a foreign
# system's modules perfectly well — and only one whose target system matches
# this machine is *built*. So "cannot build here" never means "unverified".

kernel=$(uname -s)
found=0

if grep -q 'homeConfigurations' flake.nix 2>/dev/null; then
  found=1
  ok "homeConfigurations — eval, build and switch here (for entries targeting this system)"
fi

if grep -q 'darwinConfigurations' flake.nix 2>/dev/null; then
  found=1
  if [ "$kernel" = "Darwin" ]; then
    ok "darwinConfigurations — eval and build here"
  else
    warn "darwinConfigurations — eval only on this $kernel host" \
         "Option typos, type errors and module assertions are still caught. Only the build needs real macOS; tool/checks/test reports that gap rather than hiding it."
  fi
fi

if grep -q 'nixosConfigurations' flake.nix 2>/dev/null; then
  found=1
  if [ -r /etc/os-release ] && grep -q '^ID=nixos' /etc/os-release; then
    ok "nixosConfigurations — eval, build and switch here"
  elif [ "$kernel" = "Linux" ]; then
    ok "nixosConfigurations — eval and build here (switch needs the target host)"
  else
    warn "nixosConfigurations — eval only on this $kernel host" \
         "The closure needs a Linux builder. Evaluation still catches option and assertion errors."
  fi
fi

[ "$found" -eq 1 ] || warn "no homeConfigurations/darwinConfigurations/nixosConfigurations in flake.nix" \
     "tool/checks/test has nothing to verify."

echo
if [ "$failed" -eq 1 ]; then
  printf "${red}Not ready.${off} Fix the ✗ items above before starting work.\n"
  exit 1
fi
printf "${green}Ready.${off} Warnings above only limit which flavours you can build or switch here.\n"
