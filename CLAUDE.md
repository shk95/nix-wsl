# Working on this repository

A Nix testbed for WSL, and nothing else. Standalone home-manager with no
system layer today; NixOS-WSL is the next thing to try here. Seeded from the
nix-darwin config at
[shk95/nix-config](https://github.com/shk95/nix-config), but macOS is not in
scope — everything here targets `x86_64-linux`, and the checks assume it.

It exists to try things and to learn Nix. What survives it is the findings,
not the configuration.

## Start here, every session

1. `tool/doctor.sh` — verifies the toolchain and that the git hooks are enabled.
   Do not skip it: a clone does not have hooks until `core.hooksPath` is set,
   and this host has a known ✗ described under **This host** below.
2. `gh issue list --label blocked` — work a previous session could not finish
   because it needed something this host may now have. Check whether any is now
   unblocked before starting something new.
3. `docs/status.md` — current state, and the decisions that are expensive to
   reverse.

**When something breaks in a way that makes no sense**, grep
`docs/troubleshooting.md` for the error text before investigating — its headings
are the literal messages. Do not read it end to end; it is a lookup table.

## The rules that are expensive to break

- **The findings are the deliverable, not the configuration.** This repo is a
  scratch pad. A problem that cost real time and went unrecorded means the
  experiment produced nothing, because the config itself is disposable and the
  lesson will not survive being rewritten. Record it in
  `docs/troubleshooting.md`.
- **Keep the scope at WSL.** Everything here targets `x86_64-linux`, and
  `tool/checks/test` assumes it — a configuration for another system is
  refused outright rather than half-verified. Adding one is not a small
  change; it re-opens the question of what "verified" means for a build this
  machine cannot run.
- **Never activate without being asked.** `home-manager switch` rewrites files
  in `$HOME` that this repository does not own — `~/.zshrc`, `~/.gitconfig` and
  others — and home-manager refuses to clobber an existing unmanaged file, so a
  surprise switch can half-apply and leave the shell broken. Verify by
  *building* (`tool/checks/test`), which proves the same evaluation without
  touching the machine.
- **The unix account and the git identity are separate.** `user = "user1"` is
  the login on this host; `gitname = "shk"` is who commits are authored by.
  They are different variables in `flake.nix` on purpose. Fusing them makes
  every commit look like it came from a machine account.
- **`flake.lock` is the pin.** Reproducibility is the entire point here, so it
  is committed and never ignored. `nix flake update` is a deliberate act, not
  housekeeping — it is not on the pre-approved command list.
- **Everything written into this repository is in English** — documentation,
  commit messages, code comments, issue and pull request text. The repository
  is public.

## Workflow

Branches: `master` (released) ← `dev` (integration) ← `feature/<name>` and
`fix/<name>`. `dev` is the default branch, so a clone is already on it. Branch
from `dev`, merge back to `dev`. Never commit to `master` directly.

Commits are [Conventional Commits](https://www.conventionalcommits.org); the
`commit-msg` hook rejects anything else.

Finishing a piece of work means meeting `docs/definition-of-done.md`. Anything
in it you cannot verify on this host is not a reason to skip it — open a blocked
issue instead, labelled `blocked` plus the specific reason, and say so in the
pull request.

## This host

**Flakes are not enabled globally.** Nix was installed with the upstream
installer, and nothing has written `~/.config/nix/nix.conf` yet, so plain `nix`
commands fail with *experimental Nix feature 'nix-command' is disabled*.
`tool/doctor.sh` reports this as a hard ✗, correctly. Until the first
`home-manager switch` writes that file (`home/nix.nix` manages it), prefix work
with:

```sh
export NIX_CONFIG="experimental-features = nix-command flakes"
```

**This includes `git push`**, which is the surprising part: the `pre-push` hook
runs `tool/checks/test`, so without that variable the push fails with a Nix
error rather than anything that looks git-related. Export it once per shell,
not once per nix command.

Do not hand-write `~/.config/nix/nix.conf` to silence it — home-manager will
later refuse to clobber the unmanaged file.

`gitleaks` and `direnv` are not installed here; the doctor warns rather than
failing, and CI still scans for secrets.

## Parallel sessions

Use a worktree per branch rather than switching branches under a running
session:

```sh
tool/worktree.sh new <name> feature
tool/worktree.sh list
tool/worktree.sh done <name>
```

Worktrees share `.git`, so the hooks configuration carries over automatically.

**What does not parallelise:** `home-manager switch` and anything else writing
to `$HOME` or `~/.config/nix/`. Only one session at a time may hold those.
Concurrent `nix build` runs are fine — the daemon serialises the store.

## Layout

| Path | What lives there |
| --- | --- |
| `flake.nix` | Inputs, and the `homeConfigurations.user1` output |
| `home/` | home-manager modules; `programs/` is one file per program |
| `tool/checks/` | What the git hooks and CI both run |
| `tool/doctor.sh` | Whether this machine can build, check and commit |
| `Justfile` | Day-to-day commands |
| `docs/definition-of-done.md` | What "finished" means, per milestone |
| `docs/status.md` | Current state and the decisions behind it |
| `docs/troubleshooting.md` | Errors that already cost someone an afternoon. Grep, don't read |
