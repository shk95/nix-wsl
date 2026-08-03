# Things that already cost someone an afternoon

Findings that recur. Not a changelog and not a diary — `docs/status.md` holds the
current state and the decisions, this holds the things that will bite again.

**Search this file by the error text, not by reading it.** Headings are the
literal message you will see, so `grep` finds the entry that matches what is in
front of you.

**Bar for adding an entry:** it cost more than a quarter of an hour to work out,
*and* it will happen again — to a future session, on another machine, or after a
dependency upgrade. A typo you fixed in a minute does not belong here. Keep
entries to a few lines; a long one means the explanation belongs in a code
comment where the problem lives.

---

## Nix

### `A corresponding Nix package must be specified via 'nix.package' for generating nix.conf.`

Standalone home-manager (no NixOS or nix-darwin underneath) cannot infer which
Nix binary should generate `nix.conf` the way the OS-level modules can. Set
`nix.package = pkgs.nix;` in whichever module sets `nix.settings` — here that is
`home/nix.nix`. Only `homeConfigurations` needs this.

Note that `nix flake check` passes with this bug present; see the entry below.

### `nix flake check` passes but the configuration is broken

`nix flake check` validates the flake's shape and its standard outputs. It does
not descend into `homeConfigurations`, `darwinConfigurations` or
`nixosConfigurations` — those are arbitrary attributes as far as it is
concerned. Forcing the toplevel derivation is what actually evaluates them:

```sh
nix eval --raw '.#homeConfigurations."<name>".activationPackage.drvPath'
nix eval --raw '.#darwinConfigurations."<name>".config.system.build.toplevel.drvPath'
```

`tool/checks/test` does this for every configuration, on every host.

### `Path 'flake.nix' in the repository "..." is not tracked by Git`

Flakes only see files known to git — an untracked file is invisible to flake
purity even when it is sitting right next to a tracked one. Before the first
`nix flake check` / `nix build` on brand-new files:

```sh
git add -N <the new files>
```

`-N` (intent-to-add) is enough; a full `git add` is not required yet. Name the
paths rather than running `git add -N .` — it fails outright the moment the
tree contains anything that is not a regular file or symlink, and the whole
command aborts instead of adding the files you actually meant.

### `experimental Nix feature 'nix-command' is disabled`

This host has no `~/.config/nix/nix.conf` yet. See the **This host** section of
`CLAUDE.md`: export `NIX_CONFIG="experimental-features = nix-command flakes"`
rather than writing the file, which home-manager will later refuse to clobber.

Note that `nix config show` cannot diagnose this — it needs `nix-command` in
order to run at all. `tool/doctor.sh` probes with `nix flake metadata` instead,
which exercises both flags the way real commands do.

### GitHub Actions never runs, and every API check says it is enabled

A new repository can have Actions switched off in a way nothing visible
reports. Everything that looks like a diagnostic lies:

```
$ gh api repos/<owner>/<repo>/actions/permissions
{"enabled":true,"allowed_actions":"all","sha_pinning_required":false}
$ gh api repos/<owner>/<repo>/actions/workflows -q '.workflows[].state'
active
```

Both were byte-identical to a repository where Actions worked. The only
signal is negative — `gh api repos/<owner>/<repo>/actions/runs -q .total_count`
stays at `0` no matter what you push. Fix it in **Settings → Actions** in the
web UI.

Two consequences worth knowing before you go looking:

- **Enabling does not replay missed events.** Pushes and pull requests that
  happened while it was off are gone; you need a fresh event. Pushing to an
  open pull request's head branch is the cheapest one, since it fires
  `pull_request: synchronize` even when the branch itself is not in the
  workflow's `push` filter.
- **It interacts badly with branch protection.** `setup-repo.sh` makes the
  release branch require the `Secret scan` check. With Actions off that check
  never reports, so every pull request into it waits forever on something that
  cannot arrive — and the branch protection settings look perfectly correct
  while it happens.

### `git push` fails with the same `nix-command is disabled` message

Not a git problem, and nothing in the output says a hook ran. `pre-push`
invokes `tool/checks/test`, which is a Nix command, so on a host where flakes
are not enabled globally the push dies with a Nix error. Export `NIX_CONFIG` in
the shell you push from. `--no-verify` also gets the push through, but skips
the tests, which is the thing the hook is for.

### `a 'aarch64-darwin' with features {} is required to build ..., but I am a 'x86_64-linux'`

Seen while *evaluating* — not building — a configuration for another system.
It means that configuration uses import-from-derivation: evaluation has to
build something for the foreign system part-way through, and there is no
builder for it. Evaluation of a foreign system otherwise works fine, so this
message specifically identifies IFD rather than a general limitation.

Nothing to fix locally. That configuration drops to build-only verification on
its native host; file it as `blocked/needs-<system>`.

### statix: `Found empty pattern in function argument`

A module written as `{...}: { ... }` when nothing from the module arguments is
used. statix wants `_: { ... }` instead — identical behaviour, but it does not
read as attrset-destructuring for a value that is never destructured. Modules
that do use some arguments (`{pkgs, ...}: ...`) are unaffected.

### deadnix reports unused code but the lint check still passes

deadnix's default exit code is 0 regardless of findings. `tool/checks/lint`
passes `--fail`; without it the check is cosmetic.

### `evaluation warning: The default value of 'programs.X.Y' has changed ... because 'home.stateVersion' is less than "..."`

Cosmetic, but recurs on every build until addressed. Either pin the option
explicitly (keeps the old behaviour, silences the warning) or bump
`stateVersion` deliberately after reading the home-manager release notes for
what else changes with it — pinning is the lower-risk fix in the middle of
unrelated work.
