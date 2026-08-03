# Status and handover notes

Last updated: 2026-08-03.

---

## Where things stand

| Milestone | State |
| --- | --- |
| M0 — The flake builds reproducibly | done |
| M1 — Scaffold conventions applied and verified by cloning | done |
| M2 — Activated on this host | **next** — not started, deliberately |
| M3 — Experiments feeding the unified repository | ongoing |

Repository setup, 2026-08-03: `dev` is the default branch, `master` is
protected and requires both `Secret scan` and `Format, lint, eval and build` —
names taken from what a real run reported, not guessed, since a required check
whose name does not match blocks every merge waiting for something that never
arrives. The blocked labels are `needs-manual-check`, `needs-aarch64-darwin`
and `needs-nixos-host`.

```
$ export NIX_CONFIG="experimental-features = nix-command flakes"   # see CLAUDE.md
$ tool/checks/test
── Verification coverage ─────────────────────────────────
   host: x86_64-linux

   homeConfigurations.user1               eval ✓ build ✓

   · nothing this branch changes reaches a configuration left unbuilt here.
```

---

## This machine

Ubuntu 26.04 under WSL2, Nix 2.35.1 from the **upstream** installer — not
Determinate, despite what the README recommends for a fresh setup. Flakes are
therefore not enabled globally; see the **This host** section of `CLAUDE.md`
for the workaround and why it should not be "fixed" by hand.

`tool/doctor.sh` reports what is actually here. Prefer running it over trusting
this paragraph, which is only true as of the date above.

---

## Decisions that are expensive to reverse

**Standalone home-manager, not NixOS-WSL.** The user environment is managed
without any system layer, so this works on any WSL distro with Nix installed
and does not require replacing the distro. The cost is that nothing
system-level can be declared here — no services, no system packages. Reversing
it means adopting NixOS-WSL and rewriting the entry point, so the decision is
worth revisiting only if something genuinely system-level is needed.

**The unix account and the git identity are separate variables.** `user =
"user1"` is the login on this host; `gitname = "shk"` is the commit author.
They were split because they genuinely differ here, and a flake that fuses them
produces commits authored by a machine account. Any future host merged into
this repo inherits the split for free.

**`nix.package` is set explicitly in `home/nix.nix`.** Standalone home-manager
cannot infer which Nix should generate `nix.conf`, unlike the NixOS and
nix-darwin modules. Without it the build fails an assertion — and, importantly,
one that `nix flake check` never reaches. Recorded in `troubleshooting.md`.

**Verification is two-tier, and lives in `tool/checks/test`.** Evaluate every
configuration from any host, build only those targeting this system. This came
out of discovering that `nix flake check` does not descend into
`homeConfigurations` at all, so a green check said nothing about whether the
configuration worked. The same script is the `stacks/nix` overlay in
[shk95/project-scaffold](https://github.com/shk95/project-scaffold); fixes
belong there as well as here.

**Activation is deferred and stays a manual act.** Every claim made so far was
established by building, never by switching. This is not caution for its own
sake: `home-manager switch` writes into `$HOME` over files this repo does not
own, and refuses to clobber unmanaged ones, so a half-applied switch can leave
the shell broken. M2 exists to do it deliberately, once.

**GUI terminal emulators, fonts and secrets management are out of scope.**
Terminals and fonts belong to the Windows side of a WSL setup; agenix waits
until there is an actual secret. The upstream nix-config carries alacritty,
wezterm and fonts, and they were dropped on the way in rather than ported and
left unused.

---

## Bugs worth remembering

**The setup instructions opened with a command the reader could not run.**
Step 4 said `just bootstrap`, but `just` is one of the packages the bootstrap
installs, so a fresh machine gets `just: command not found` on the first thing
the README asks for. Found by the clone verification, not by reading — the
machine that wrote the instructions was assumed to have the tool, and in fact
did not have it either. The README now gives the underlying `nix run` command,
and `just` was added to the devShell so `nix develop` is a working entry point
before anything is activated.

**`nix flake check` passing on a broken configuration.** Found while bringing
the flake up: the missing `nix.package` assertion did not fire until the
toplevel derivation was forced. This is what produced the two-tier design
above, and the reason `tool/checks/test` evaluates `.drvPath` explicitly rather
than trusting `nix flake check`.

**`pre-push` ran the whole suite to delete a branch.** Deleting the first
merged branch was blocked by a test run that could not tell it apart from a
push of new commits. Nothing a deletion does can fail a test, and on this host
— where the suite needs `NIX_CONFIG` — it meant branch cleanup was impossible
without `--no-verify`, which is the habit least worth teaching. The hook now
reads the refs git hands it on stdin and skips when all of them are deletions.
Fixed upstream in project-scaffold's core as well; both were found here, on the
first tidy-up after a merge.

---

## Traps that will recur

Everything that has already cost time lives in
[`troubleshooting.md`](troubleshooting.md). **This file holds state and
decisions; that one holds findings**, so updating the state does not delete them.

When stuck, grep it for the error text rather than reading it.

---

## Next

M2, activation. Before running `home-manager switch`, inventory what already
exists in `$HOME` that home-manager will want to own — `~/.zshrc`,
`~/.gitconfig`, `~/.config/nix/nix.conf` — because that is where it will fail,
and it fails part-way rather than cleanly. Deal with those first, then work
the M2 list in `definition-of-done.md`; `tool/doctor.sh` exiting 0 with no ✗ is
the item that confirms the rest.

Two things left over from M1, neither blocking:

- The blast-radius warning in `tool/checks/test` has only ever been exercised
  against a synthetic two-flavour repository. It stays unproven in real use
  until this repo, or the unified one, actually declares a configuration this
  host cannot build.
- `gitleaks` is not installed here, so the pre-commit secret scan has never
  run locally on this repository. CI's `Secret scan` job has covered every
  push so far, which is the backstop working as designed rather than a reason
  to leave it uninstalled.

---

## Conventions

Branch strategy, commit format, hooks and CI all come from
[shk95/project-scaffold](https://github.com/shk95/project-scaffold); its
`decisions/` directory carries the reasoning, which is not repeated here.
`CLAUDE.md` has the short version that a session needs.

`master` will sit visibly behind `dev`, often by a lot. That is the intended
shape, not drift — `dev` is the default branch so that a clone lands on the
branch work starts from. Do not "fix" it by merging `dev` into `master` outside
a release.
