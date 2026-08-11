# Definition of done

Code that compiles is not finished work. This file says what "finished" means,
so a session cannot declare a milestone complete on the strength of a green
build.

**The rule for anything you cannot verify here:** do not quietly skip it and do
not claim it. Open a blocked issue naming what is missing, and say so in the
pull request.

```sh
gh issue create --label blocked --label blocked/<what-is-missing> \
  --title "<milestone>: <what still needs checking>" \
  --body "<what was built, what was tested, and the steps to close this>"
```

Always two labels: `blocked` — the umbrella that `gh issue list --label blocked`
finds, since GitHub matches labels exactly — plus one saying what is missing.

---

## Every change

- [ ] `tool/checks/format` passes
- [ ] `tool/checks/lint` passes (statix and deadnix, the latter with `--fail`)
- [ ] `tool/checks/test` passes — every configuration evaluated, and every one
      targeting this system built
- [ ] The coverage block `tool/checks/test` prints is pasted into the pull
      request, including any configuration it could not build
- [ ] Commits follow Conventional Commits
- [ ] `docs/status.md` updated if a decision was made that is expensive to
      reverse, with the reasoning — not just the conclusion
- [ ] Anything that cost more than a quarter of an hour to work out, and will
      recur, is in `docs/troubleshooting.md` under its literal error text

---

## M0 — The flake builds reproducibly

- [x] `nix flake check` passes
- [x] `nix build .#homeConfigurations.user1.activationPackage` produces a store
      path
- [x] `flake.lock` is committed
- [x] `nix fmt -- --check .` reports no changes needed

## M1 — The scaffold conventions are applied and verified by cloning

Verification here means a fresh clone in a scratch directory, followed in
order, using nothing the current machine happens to have.

Done on 2026-08-03. The clone found a real defect — step 4 of `README.md` told
the reader to run `just bootstrap` when `just` is one of the packages the
bootstrap installs — which is the entire argument for doing this rather than
reasoning about it.

**Re-verified on 2026-08-04**, because a ticked box is only true of the code it
was ticked against. By then every file this list exercises had been
rewritten — all three hooks, all three checks, `worktree.sh`, `doctor.sh` and
`README.md` — most pointedly `tool/doctor.sh`, which is the literal subject of
the second item. All six passed. The clone again found one stale thing, smaller
than last time: step 3 of `README.md` still described the doctor's old two-way
verdict, which no longer exists.

**A box this list can no longer tick on this host:** the first run was done
before activation, so the clone genuinely hit *experimental Nix feature
'nix-command' is disabled* and the `NIX_CONFIG` workaround was exercised. This
host is activated now, so that path is documented but untested here. It needs a
machine that has never run `home-manager switch`.

- [x] The clone lands on `dev`, with `AGENTS.md`, the `CLAUDE.md` compatibility
      entry point, `tool/` and `docs/` present
- [x] `tool/doctor.sh` fails on the unset hooks path and prints the exact
      command to fix it
- [x] A deliberately malformed commit message is rejected by `commit-msg`
- [x] `tool/worktree.sh new` **and `done`** both work — `done` is the path that
      never gets exercised during development
- [x] `tool/checks/format`, `lint` and `test` all pass from inside the clone
- [x] The CI workflow has been watched passing on a real push, not assumed

## M2 — Activated on this host

Deliberately deferred until now; everything above was verified by building
rather than switching. These are the items a build cannot establish.

Activated 2026-08-03; nine of the ten below were verified the same day. The
login shell needed a person and was switched on 2026-08-04, which closes M2.

- [x] `home-manager switch --flake .#user1` completes without error
- [x] Existing `~/.zshrc`, `~/.gitconfig` and similar were dealt with
      beforehand — home-manager refuses to clobber unmanaged files, so this is
      the item most likely to fail
- [x] A newly opened login shell is the nix-managed zsh (`echo $SHELL`)
      — `just switch-shell` needs a password twice, for `sudo` and `chsh`, so
      a person ran it on 2026-08-04. Checked afterwards in a clean login shell
      (`env -i` under a pty, so nothing was inherited): `~/.local/bin` and
      `~/.opencode/bin` are appended rather than prepended, `LANG` and
      `locale charmap` are UTF-8, and `conda` and `sdk` load as functions.
- [x] `git config user.email` reports the address set in `flake.nix`
- [x] `git push` still authenticates over HTTPS — the `gh` credential helper
      moved out of an unmanaged `~/.gitconfig` into `programs.gh`, and the
      activation script moves that file aside
- [x] `~/.gitconfig.before-home-manager.*` exists, holding what was moved
- [x] `command -v claude` still resolves in a fresh shell — `~/.local/bin` was
      reachable only through the `~/.zshrc` that home-manager replaces
- [x] `nvim` resolves inside the nix profile (`command -v nvim`)
- [x] `nix flake metadata` succeeds with **no** `NIX_CONFIG` set — meaning
      `~/.config/nix/nix.conf` is now managed
- [x] `tool/doctor.sh` exits 0 with no ✗

## M3 — Experiments, and what they leave behind

Ongoing rather than completable. The bar is not "the experiment worked" — a
failed experiment is a perfectly good outcome — but that it left something
behind. NixOS-WSL is the next one; anything that would take this repository
off `x86_64-linux` is out of scope rather than an experiment.

- [ ] Each experiment ends with either an entry in `docs/troubleshooting.md` or
      a decision recorded in `docs/status.md`, with the reasoning
- [ ] Anything that turned out to be load-bearing is added to the relevant
      principle in `AGENTS.md`
- [ ] An experiment abandoned part-way says so in `docs/status.md`, rather than
      being deleted silently — the next session needs to know it was tried
