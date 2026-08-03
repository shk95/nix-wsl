# nix-wsl

A deliberately experimental Nix setup: standalone
[home-manager](https://github.com/nix-community/home-manager) on WSL, with no
NixOS-WSL and no system layer, seeded from the nix-darwin config at
[shk95/nix-config](https://github.com/shk95/nix-config).

It exists to try things and to learn Nix. Its findings are meant to feed a
later unified configuration covering WSL, macOS and NixOS together, which is
why `docs/troubleshooting.md` and the decision notes in `docs/status.md` matter
more here than the configuration itself does.

Because there is no system-level module, this works on any WSL distro that has
Nix installed.

## Setup

**1. Enable the git hooks.** First, before anything else. `core.hooksPath` is
local repository configuration: it is not cloned and nothing reminds you, so a
clone that skips this line commits with no formatting check, no lint and no
secret scan.

```sh
git config core.hooksPath .githooks
```

**2. Install Nix.** [Determinate](https://docs.determinate.systems/) is the
easier route on Ubuntu/WSL because it sets up the daemon and sensible defaults;
the [official installer](https://nixos.org/download/) works too. Open a new
shell afterwards.

**3. Check the machine.**

```sh
tool/doctor.sh
```

It reports what is missing and how to fix each item. On a host where flakes are
not enabled globally it fails with a ✗ and prints the workaround — that is
correct, not a bug.

**4. Bootstrap home-manager.** Only needed the first time. Note that this is
not `just bootstrap`: `just` is one of the packages this configuration
installs, so on a fresh machine it is no more present than `home-manager` is.

```sh
nix run home-manager/master -- switch --flake .#user1
```

That is exactly what the `bootstrap` recipe runs. Once it finishes both
`home-manager` and `just` are on `PATH`, and everything below works — from
then on, `just switch`.

If you would rather not activate anything yet, `nix develop` gives you a shell
with `just` and the Nix tooling in it, without touching `$HOME`.

Note that activation is a deliberate act here, not part of routine work — see
the rules in [`CLAUDE.md`](CLAUDE.md).

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

Verification, which the git hooks and CI both run:

```sh
tool/checks/format  # nix fmt --check
tool/checks/lint    # statix, deadnix
tool/checks/test    # flake check, then evaluate every configuration and
                    # build the ones targeting this system
```

## Editing this flake

`nix develop` drops you into a shell with `alejandra`, `nixd`, `statix` and
`deadnix` — the same reproducibility principle applied to working on the config
itself.

## Layout

| Path | What lives there |
| --- | --- |
| `flake.nix` | Inputs, and the `homeConfigurations.user1` output |
| `home/` | home-manager modules; `programs/` is one file per program |
| `tool/` | The environment doctor, the checks, the worktree helper |
| `docs/` | What "done" means, current state, and findings worth grepping |
| `Justfile` | Day-to-day commands |

## Conventions

Branching, commit format, hooks, blocked-work labels and CI come from
[shk95/project-scaffold](https://github.com/shk95/project-scaffold) — its
`decisions/` directory explains why each one exists and what went wrong without
it. This repository uses its `stacks/nix` overlay, and fixes found here belong
upstream there too.

`master` is the released state; `dev` is the default branch and where work
starts. `master` will sit visibly behind `dev`; that is intended.
