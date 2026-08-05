# Working on this repository

A Nix testbed for WSL, and nothing else. Two flavours, both first-class:
standalone home-manager (`homeConfigurations.user1`) and NixOS-WSL
(`nixosConfigurations.wsl`). Seeded from the nix-darwin config at
[shk95/nix-config](https://github.com/shk95/nix-config), but macOS is not in
scope — everything here targets `x86_64-linux`, and the checks assume it.

It exists to try things and to learn Nix. What survives it is the findings,
not the configuration.

## Start here, every session

1. `tool/doctor.sh` — verifies the toolchain and that the git hooks are enabled.
   Do not skip it: a clone does not have hooks until `core.hooksPath` is set.
   It exits 0 on this host; if it does not, believe it over **This host** below.
2. `gh issue list --label blocked` — work a previous session could not finish
   because it needed something this host may now have. Check whether any is now
   unblocked before starting something new.
3. `docs/status.md` — current state, and the decisions that are expensive to
   reverse.

**When something breaks in a way that makes no sense**, grep
`docs/troubleshooting.md` for the error text before investigating — its headings
are the literal messages. Do not read it end to end; it is a lookup table.

**If you are an agent, suspect your own sandbox first.** Its shell tool runs in
a mount namespace that bind-mounts over the paths it denies, so `git status`
can list dotfiles nobody created, `git add -N .` can refuse the tree, and git
can warn `unable to access '.gitmodules': Permission denied` — none of it true
of the disk, and none of it reproducible by a person in a terminal. The check
is always the same: run the command again outside the sandbox and compare. See
**The agent sandbox** in `docs/troubleshooting.md`.

## The rules that are expensive to break

- **The findings are the deliverable, not the configuration.** This repo is a
  scratch pad. A problem that cost real time and went unrecorded means the
  experiment produced nothing, because the config itself is disposable and the
  lesson will not survive being rewritten. Record it in
  `docs/troubleshooting.md`.
- **A file under `modules/` says which flavours it reaches by the option it
  writes to, not by where it sits.** Every file there is a flake-parts module,
  collected automatically, and contributes to one of three names:
  `modules.homeManager.shared` (both flavours), `modules.homeManager.standalone`
  (standalone only), `modules.nixos.wsl` (NixOS only). What imports which is
  decided in exactly one file, `modules/flake/configurations.nix`.

  The containment runs one way and reads backwards: NixOS-WSL is a *superset* —
  it can express everything home-manager can, plus `users.*`, `services.*` and
  the rest, none of which standalone has any equivalent for. So a fragment
  written for `nixos` can quietly become impossible to run standalone, while one
  written for `homeManager.shared` runs under both. Standalone is not a test rig
  being phased out; it is the only thing that works on a machine whose distro you
  cannot replace, and `homeManager.shared` is the whole of it.

  This is why **packages belong to home-manager rather than the system layer**.
  `useUserPackages = true` already folds them into the NixOS closure, so moving
  one to `environment.systemPackages` buys availability to root and costs
  standalone the package outright. The test for anything new: would standalone
  still work if this lived only in `modules/wsl.nix`?
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
  the login on this host; `gitName = "shk"` is who commits are authored by.
  They are separate declared options in `modules/flake/identity.nix` on purpose.
  Fusing them makes every commit look like it came from a machine account.
- **WSL distributions share one kernel, so some state is global and unowned.**
  Not a curiosity — it has now cost two afternoons, in two different places. The
  cgroup hierarchy is shared, so two distributions whose default user has the
  same UID collide and the second one's `systemd --user` never starts. The
  `binfmt_misc` registry is shared, so *any* systemd distribution's shutdown
  flushes it for every distribution still running and Windows interop dies in a
  distribution nobody touched.

  Both failures share a shape worth recognising early: **the damage lands
  somewhere other than where the change was made**, and nothing in the harmed
  distribution's configuration or logs points back at the cause. Anything the
  NixOS flavour declares that reaches a kernel-global resource has to be checked
  against "what happens to the *other* distribution when this one shuts down".
  Both are recorded in `docs/troubleshooting.md` under their literal messages;
  read those before designing around either.
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

**This host is activated.** `home-manager switch` ran on 2026-08-03, so
`~/.config/nix/nix.conf` is managed and flakes work with no `NIX_CONFIG`.
`gitleaks` and `direnv` arrived with it. `tool/doctor.sh` exits 0 with nothing
but ✓ — run it rather than trusting this paragraph.

**A fresh clone on an unactivated machine is a different story**, and the
instructions for it have not gone away: before the first switch, plain `nix`
commands fail with *experimental Nix feature 'nix-command' is disabled*, and so
does `git push`, because the `pre-push` hook runs `tool/checks/test`. The
workaround is `export NIX_CONFIG="experimental-features = nix-command flakes"`
once per shell. Do not hand-write `~/.config/nix/nix.conf` instead —
home-manager refuses to clobber an unmanaged file, so that turns the first
switch into a failure.

**The login shell is the nix-managed zsh**, switched on 2026-08-04. That also
means the shell an agent's tooling runs is zsh, not bash: an unmatched glob is
an error rather than a literal, so a pattern that may match nothing needs
`setopt nullglob` or `find`. On a fresh machine the switch is `just
switch-shell`, which needs a password twice — `sudo` to register the shell in
`/etc/shells`, then `chsh` — so an agent cannot run it.

**`~/.bashrc` is not managed and still holds the conda, SDKMAN and opencode
hooks it always did.** The same hooks are declared in `modules/shell.nix` for zsh.
Changing one does not change the other, and bash stays a working fallback on
purpose — if zsh ever fails to start, that is what you land in.

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
| `flake.nix` | Inputs, and one line handing `modules/` to flake-parts. Nothing else |
| `modules/*.nix` | One file per feature. Each contributes to `modules.homeManager.shared`, `.standalone`, or `modules.nixos.wsl` |
| `modules/flake/` | The wiring: identity, nixpkgs config, the two configurations, the devShell |
| `modules/flake/configurations.nix` | **The only place** that decides which fragments reach which flavour |
| `tool/checks/` | What the git hooks and CI both run |
| `tool/doctor.sh` | Whether this machine can build, check and commit |
| `Justfile` | Day-to-day commands |
| `docs/definition-of-done.md` | What "finished" means, per milestone |
| `docs/status.md` | Current state and the decisions behind it |
| `docs/troubleshooting.md` | Errors that already cost someone an afternoon. Grep, don't read |
