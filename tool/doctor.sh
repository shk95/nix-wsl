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
#
# The error is kept rather than discarded. Every other way this probe can fail
# — no network, an untracked flake.nix, a read-only ~/.cache/nix — used to be
# reported as "flakes are not enabled", which sends you to export a variable
# that cannot help. Not knowing is its own answer, and it stays a ✗ because the
# question being asked is whether this machine can build.
if err=$(nix flake metadata --no-write-lock-file 2>&1 >/dev/null); then
  ok "nix-command and flakes enabled"
else
  case "$err" in
    *"experimental Nix feature"*)
      bad "nix-command/flakes not enabled by default" \
          'export NIX_CONFIG="experimental-features = nix-command flakes" until the first home-manager switch writes it for you (see home/nix.nix)'
      ;;
    *)
      # nix prints a chain, opening with a bare "error:" and putting the root
      # cause last — so the last non-empty line is the one worth showing.
      detail=$(printf '%s\n' "$err" \
               | grep -v '^[[:space:]]*$' \
               | tail -1 \
               | sed 's/^[[:space:]]*//' \
               | cut -c1-200)
      bad "could not ask the flake whether nix-command works" \
          "Not the experimental-features flag, so exporting NIX_CONFIG will not help. $detail"
      ;;
  esac
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
# tool/checks/test builds every configuration on the host it runs on, so what
# matters here is only whether each one can also be *activated* from this
# machine. Building and activating are different questions: a NixOS closure
# builds on any Linux box, and only switching to it needs the real host.

found=0

if grep -q 'homeConfigurations' flake.nix 2>/dev/null; then
  found=1
  ok "homeConfigurations — build and switch here"
fi

if grep -q 'nixosConfigurations' flake.nix 2>/dev/null; then
  found=1
  if [ -r /etc/os-release ] && grep -q '^ID=nixos' /etc/os-release; then
    ok "nixosConfigurations — build and switch here"
  else
    warn "nixosConfigurations — build here, but not switch" \
         "nixos-rebuild switch needs the target host. The closure still builds and is still verified; only activation is out of reach."
  fi
fi

[ "$found" -eq 1 ] || warn "no homeConfigurations or nixosConfigurations in flake.nix" \
     "tool/checks/test has nothing to verify."

echo
if [ "$failed" -eq 1 ]; then
  printf "${red}Not ready.${off} Fix the ✗ items above before starting work.\n"
  exit 1
fi
printf "${green}Ready.${off} Warnings above only limit which flavours you can build or switch here.\n"
