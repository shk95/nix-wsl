# nix-wsl

Reproducible dev environment for WSL, managed by Nix + standalone
[home-manager](https://github.com/nix-community/home-manager) — no NixOS-WSL involved.

This intentionally stops at the user-environment layer: packages, shell, git, editor and
terminal tooling are declared in `home/` and applied with `home-manager switch`. There is no
system-level module here, so it works on any WSL distro that has Nix installed.

## Layout

- `flake.nix` — inputs (`nixpkgs`, `home-manager`) and the `homeConfigurations.user1` output
- `home/` — home-manager modules
  - `default.nix` — `home.*` basics, wires up the other modules
  - `nix.nix` — user-level `nix.conf` (flakes/nix-command)
  - `packages.nix` — CLI packages
  - `shell.nix` — zsh
  - `starship.nix` — prompt
  - `programs/` — one file per program (git, direnv, eza, neovim, skim, yazi)
- `Justfile` — day-to-day commands

## Install

1. Install Nix. Either works; Determinate is recommended on Ubuntu/WSL because it sets up the
   daemon and default settings for you.
   - [Determinate Nix](https://docs.determinate.systems/determinate-nix/)
   - [Official installer](https://nixos.org/download/)
2. Open a new shell so the Nix environment is loaded.
3. Bootstrap home-manager (only needed the first time, before the `home-manager` command exists):
   ```sh
   just bootstrap
   ```
4. From then on:
   ```sh
   just switch
   ```

## Everyday commands

```sh
just switch        # apply home/ changes
just up             # update all flake inputs
just upp nixpkgs    # update a single input
just fmt            # format the nix files (alejandra)
just check          # nix flake check
just gc             # garbage collect store entries older than 7 days
just switch-shell   # make the home-manager zsh your login shell
```

## Editing this flake

`nix develop` drops you into a shell with `alejandra`, `nixd`, `statix` and `deadnix` — the same
reproducibility principle applied to working on the config itself.

## Notes

- `user` (the unix account, `user1`) and `gitname`/`gitmail` (commit identity, `shk`) are set
  separately in `flake.nix` since they don't have to match.
- GUI terminal emulators (alacritty/wezterm), fonts, and secrets management (agenix) are
  deliberately out of scope for this first pass — see [shk95/nix-config](https://github.com/shk95/nix-config)
  for the macOS/nix-darwin config this was inspired by, which does cover those.
