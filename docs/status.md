# Status and handover notes

Last updated: 2026-08-04.

---

## Where things stand

| Milestone | State |
| --- | --- |
| M0 — The flake builds reproducibly | done |
| M1 — Scaffold conventions applied and verified by cloning | done — re-verified 2026-08-04 |
| M2 — Activated on this host | done — activated 2026-08-03, login shell 2026-08-04 |
| M3 — Experiments, and what they leave behind | **next** |

Repository setup, 2026-08-03: `dev` is the default branch, `master` is
protected and requires both `Secret scan` and `Format, lint, eval and build` —
names taken from what a real run reported, not guessed, since a required check
whose name does not match blocks every merge waiting for something that never
arrives. The blocked labels are `blocked/needs-manual-check` and
`blocked/needs-nixos-host` — with the prefix, which is not decoration: an issue
is filed with `blocked` *and* one of these, and GitHub matches label names
exactly, so dropping the prefix files against a label that does not exist.

```
$ tool/checks/test
── Verification coverage ─────────────────────────────────
   host: x86_64-linux

   homeConfigurations.user1               eval ✓ build ✓

   · nothing this branch changes reaches a configuration left unbuilt here.
```

---

## This machine

Ubuntu 26.04 under WSL2, Nix 2.35.1 from the **upstream** installer — not
Determinate, despite what the README recommends for a fresh setup. Activated
since 2026-08-03, so `~/.config/nix/nix.conf` is managed and flakes need no
`NIX_CONFIG`. The workaround that dominated every earlier session is now only
for an unactivated clone; `CLAUDE.md` keeps it on that footing.

The login shell is the nix-managed zsh since 2026-08-04, registered in
`/etc/shells` and set with `chsh`. Verified afterwards in a clean interactive
login shell (`env -i` plus a pty, so nothing was inherited from the caller):
`~/.local/bin` and `~/.opencode/bin` land at the *end* of `PATH`, so `bat`
resolves to the nix package while `claude`, `uv` and `uvx` still resolve to the
standalone installs; `LANG` is `en_US.UTF-8` and `locale charmap` returns
`UTF-8`; `conda` and `sdk` load as functions. `~/.bashrc` is untouched, so bash
remains the fallback.

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

That sentence has been read as "trying NixOS-WSL is a one-way door", and it is
not — the entry point is the flake's, not the machine's. See **The next
experiment** below, where the difference is measured rather than assumed.

**The unix account and the git identity are separate variables.** `user =
"user1"` is the login on this host; `gitname = "shk"` is the commit author.
They were split because they genuinely differ here, and a flake that fuses them
produces commits authored by a machine account. Any future host merged into
this repo inherits the split for free.

**`nix.package` is set explicitly in `home/nix.nix`.** Standalone home-manager
cannot infer which Nix should generate `nix.conf`, unlike the NixOS and
nix-darwin modules. Without it the build fails an assertion — and, importantly,
one that `nix flake check` never reaches. Recorded in `troubleshooting.md`.

**Verification is two-tier, and lives in `tool/checks/test`.** Evaluate each
configuration by forcing its toplevel `.drvPath`, then build it. This came out
of discovering that `nix flake check` does not descend into
`homeConfigurations` at all, so a green check said nothing about whether the
configuration worked. The same script is the `stacks/nix` overlay in
[shk95/project-scaffold](https://github.com/shk95/project-scaffold); fixes
belong there as well as here.

**The checks assume every configuration targets this host, and this repo stays
that way.** Everything here is `x86_64-linux`, NixOS-WSL included, so a
configuration for another system is refused by name rather than
half-verified. An earlier version carried machinery for cross-system
verification — evaluate everywhere, build what matches, warn when a shared
module reached something unbuilt. It was removed: nothing in a WSL-only repo
can ever trigger it, and it had been validated only against a two-flavour
repository built specifically to validate it, laid out the way the heuristic
already assumed. The reasoning survives as a design note in the overlay's
README, to be rebuilt against a real multi-host layout if one ever exists.

**No `LOCALE_ARCHIVE`, despite the standard advice.** The usual instruction for
home-manager on a non-NixOS host is to pin `pkgs.glibcLocales` and point
`LOCALE_ARCHIVE` at it. Measured here instead of assumed: nix's glibc tries
`/run/current-system/sw/lib/locale/locale-archive`, misses, and falls back to
`/usr/lib/locale/locale-archive`, which Ubuntu generates with `en_US.UTF-8` in
it. `locale charmap` returns `UTF-8`, and a deliberately bogus locale returns
`ANSI_X3.4-1968` — so the test can tell the two apart. Pinning glibcLocales
would add a large closure to buy nothing. If `locale charmap` ever starts
saying `ANSI_X3.4-1968`, that is the moment to add it.

**`programs.ssh` runs with `enableDefaultConfig = false`.** Enabling the module
otherwise writes a `Host *` block of home-manager's own defaults, and since a
user config is read before `/etc/ssh/ssh_config` with first match winning,
those defaults replace the system's. One difference is real: Ubuntu sets
`HashKnownHosts yes` and this host's `known_hosts` is already hashed, so the
block would have started appending unhashed entries to a hashed file. Declaring
one host alias should not change how ssh behaves everywhere else. home-manager
documents the option as heading for deprecation; the replacement is to declare
`settings."*"` explicitly rather than to accept the block.

**Activation stays a manual act, and everything else is verified by building.**
Up to M2 every claim was established by building, never by switching. This is
not caution for its own sake: `home-manager switch` writes into `$HOME` over
files this repo does not own, and refuses to clobber unmanaged ones, so a
half-applied switch can leave the shell broken. M2 did it deliberately, once.
The rule survives M2 unchanged — a session does not switch unless it was asked
to, and `tool/checks/test` is what proves an evaluation without touching the
machine.

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

**Activation would have deleted an authentication secret that nothing
declared.** `home/programs/git.nix` carried `rm -f ~/.gitconfig`, right in
intent: git reads that file *after* `~/.config/git/config`, so leaving it in
place would have let the unmanaged copy silently win every overlapping key. But
the inventory taken before M2 found it also held the `gh` credential helper for
github.com and gist.github.com — and every remote here is HTTPS, so the switch
would have removed push authentication at the moment it ran, with nothing to
restore from. The helper is now declared through `programs.gh`, and the
activation script moves the file to `~/.gitconfig.before-home-manager.<stamp>`
instead of removing it. That script is the one place in this configuration that
escapes home-manager's refusal to clobber unmanaged files, which is exactly why
it should not delete.

**Taking over `~/.zshrc` would have removed `claude` from `PATH`.** The file is
26 bytes and does one thing — source `~/.local/bin/env` — and that is the only
thing putting `~/.local/bin` on `PATH`. `claude`, `uv` and `uvx` live there and
nowhere else. home-manager refuses to clobber the file, so this would have
surfaced as a refusal rather than a silent break; the trap is that clearing the
refusal is precisely the step that drops the line. `programs.zsh.initContent`
now declares the directory.

**`home.sessionPath` prepends.** It generates
`export PATH="$dir${PATH:+:}$PATH"`, so a directory added through it shadows
the declared packages rather than deferring to them — and `~/.local/bin` holds
standalone installs that overlap `packages.nix` (`bat`). Appending from
`programs.zsh.initContent` keeps the declared package winning. Established by
reading the built `hm-session-vars.sh`, not by trusting the option's name; the
first version of that change was committed to the opposite belief.

**Predicting which files collide found one conflict; enumerating them found
three.** The first pre-M2 inventory checked the paths it expected
home-manager to want — `~/.zshrc`, `~/.gitconfig`, `~/.config/nix/nix.conf` —
and reported one conflict. Listing the *built* generation's `home-files/`
against `$HOME` instead found `~/.config/gh/config.yml` and
`~/.config/git/ignore` as well, both carrying settings nothing in the flake
declared. The generation knows exactly what it will write; a person guessing
from module names does not. Enumerate:

```sh
cd "$(nix build --no-link --print-out-paths .#homeConfigurations.<name>.activationPackage)/home-files"
find . -mindepth 1 \( -type f -o -type l \) | sed 's|^\./||'
```

**An empty declaration is a deletion.** `programs.gh` writes `aliases: {}` when
none are declared, which silently removed a `co = pr checkout` alias that had
lived in the unmanaged config. The general shape: for any option home-manager
renders wholesale into a file, leaving it out is not "don't touch it", it is
"make it empty".

**The configuration described a shell nobody used.** `programs.zsh` had been
declared from the first commit, but the login shell was bash, zsh was not
installed, and the file that actually ran — `~/.bashrc`, 34 lines of conda,
SDKMAN, opencode and locale setup — is one home-manager does not manage.
Activating without moving that content first would have read as the environment
regressing. Nothing catches this: the build is perfectly correct about a shell
that never starts.

**The doctor reported a blocked probe as a disabled feature.** `tool/doctor.sh`
asks the flake for its own metadata, which is a good probe — it exercises both
experimental flags the way real commands do. But it discarded the error and
treated *every* failure as "flakes are not enabled", so a read-only
`~/.cache/nix` produced a ✗ telling you to export a variable that could not
help. Found by control experiment: identical command, identical commit,
identical `NIX_CONFIG`, opposite verdicts inside and outside an agent sandbox.

This is the third instance of one shape in this repository — **treating "could
not compute" as an answer**, after `tool/checks/test` did it twice. Worth
naming, because the next one will not look like either of them. The rule that
falls out: when a check cannot run, say that, and never let the fallback be one
of the real verdicts. The next one did not look like either of them; it is the
entry below.

**A green `git status` described a filesystem nobody had.** Run inside an agent
sandbox, `git status` reported nineteen untracked entries in the repository
root — `.bashrc`, `.zshrc`, `.gitconfig`, `.idea`, `.vscode` — which reads as
`$HOME` having been emptied into the repo. `ls -l` showed them as
`crw-rw-rw- … nobody nogroup 1, 3`: character devices, every one of them
`/dev/null`, all sharing a single mtime to the nanosecond. `git add -N .`
refused the tree outright. Outside the sandbox, the same commands on the same
commit reported nothing at all — no devices, empty `git status`, no mounts. The
sandbox bind-mounts `/dev/null` over the paths it denies, and those mounts live
in its mount namespace, so every command run inside sees them and nothing
outside does.

This is the sibling of the entry above and the more dangerous of the two.
There, the probe *failed* and a bad fallback promoted the failure to a verdict.
Here the probe *succeeded* — exit 0, no error, no warning — and its answer was
true of the namespace it ran in and false of the disk. Nothing breaks, so
nothing signals. The rule that falls out is narrower than the previous one:
a command's answer is scoped to the environment it ran in, so before believing
anything about files this repository does not track, re-run it outside the
sandbox and compare. `warning: unable to access '.gitmodules': Permission
denied`, emitted by git commands that otherwise work, is the same cause showing
through.

**A verification tier was proposed on the strength of its name.**
`nix build --dry-run` sounds like it sits between evaluating and building, and
its cost said the same — 9s against eval's 7s on a closure that takes 615 MiB
to build. It was written into this file and merged before anyone asked what it
*catches*. Two control cases settled it:

```
a package that does not exist    eval FAIL   dry-run FAIL   ← eval already has it
a source that cannot be fetched  eval PASS   dry-run PASS   ← only a build has it
```

Nothing. Forcing `.drvPath` must instantiate the whole input graph to write
that `.drv`, so existence is a tier 1 guarantee, and dry-run only adds
substituter *availability* — which is not correctness. The general shape, and
this repo keeps finding it: **a tool's cost is easy to measure and gets
measured; what it proves is easy to assume and gets assumed.** Two cheap
control cases, one of which must fail, are what tell them apart.

**The `pre-push` hook and CI do not check the same artifact.** The hook runs
`tool/checks/test`, which builds `.#`, and for a dirty repository a flake reads
the *working tree*. CI checks out the *commit*. So the obvious economy — "it
built locally on a single-host repo, why build it again" — rests on the two
being the same thing, and they are not. Demonstrated rather than argued, on a
fresh clone:

```
home/programs/default.nix   imports ./demo.nix   committed
home/programs/demo.nix      git add-ed, never committed

hook  (working tree)  nix eval .#…drvPath                 PASS  -> push proceeds
CI    (the commit)    nix eval git+file://…?ref=HEAD#…     FAIL
                      error: path '…/home/programs/demo.nix' does not exist
```

An untracked file is not this bug — flakes refuse to see it, so the local build
fails too and you find out immediately. The dangerous state is *staged but not
committed*, which flakes do see, and which is what half a repository looks like
during ordinary work. Add the two other things CI backstops — a clone has no
hooks until `core.hooksPath` is set, and `--no-verify` exists — and the answer
is that CI's value is real but it is **per repository, not per configuration**.
One configuration built from a clean checkout proves the commit is complete;
the second one proves it again for a great deal more money.

**A ticked box outlived the code it was ticked against.** M1 was verified by
cloning on 2026-08-03. Twenty-two commits later every file that verification
exercises had been rewritten — all three hooks, all three checks,
`worktree.sh`, `README.md`, and `doctor.sh`, which is the literal subject of
one of the items. Nothing flagged it: a checklist records that something was
true, never when it stopped being. Re-running took minutes and found a stale
`README.md` sentence describing a `doctor.sh` verdict that no longer exists.
The cheap habit is to re-run the clone verification whenever the files it
touches change, rather than treating M1 as finished forever.

**`pre-push` ran the whole suite to delete a branch.** Deleting the first
merged branch was blocked by a test run that could not tell it apart from a
push of new commits. Nothing a deletion does can fail a test, and on this host
— where the suite then needed `NIX_CONFIG` — it meant branch cleanup was impossible
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

## The next experiment: NixOS-WSL

Groundwork done 2026-08-04, and the flake now carries
`nixosConfigurations.wsl` — `system/default.nix`, deliberately almost empty,
because starting an experiment about whether a system layer earns its place
with packages already moved into it answers the question by assumption.

**Where it has got to:**

| | |
| --- | --- |
| evaluates through `tool/checks/test` | ✓ |
| closure builds (`CHECKS_BUILD_ALL=1`) | ✓ 1.9 GiB |
| tarball for `wsl --import` | ✓ built 2026-08-04 by a person — 603 MB |
| imported and booted | not started |
| `nixos-rebuild switch` inside it | not started |

The tarball was the same shape of blocker as `just switch-shell`: NixOS-WSL's
builder opens with `if ! [ $EUID -eq 0 ]` and exits, because it chowns paths
inside the rootfs it assembles, so it needs a password and a person.
`just nixos-tarball` is the one command; it takes several minutes, because it
runs a real `nixos-install` into a temporary root before archiving it.

**Two things that were wrong when this recipe was first written**, both found
by watching the real run rather than by reading the script:

- The output is **`nixos.wsl`**, not `nixos-wsl.tar.gz`. That is the builder's
  own default, and it is relative to whatever the cwd happens to be. The recipe
  now passes the path explicitly instead of inheriting it.
- Nothing in `.gitignore` caught it. A 603 MB root-owned file appeared in the
  repository root as untracked — `result` and `*.gz` both miss it, and it is one
  `git add -A` away from a very bad commit. `*.wsl` is now ignored.

Removing it needs `sudo rm`, since the builder runs as root.

The remaining step is on the Windows side:

```
wsl --import NixOS <install-dir> \\wsl.localhost\Ubuntu-26.04\home\user1\github_prj\nix-wsl\nixos.wsl
wsl -d NixOS
```

The numbers below are what shaped the design, and they were cheaper to get than
to undo.

**What it is for.** Whether a system layer earns its place here at all: services
and system packages are the things standalone home-manager cannot declare, and
this repo has never needed one badly enough to find out. The second question is
whether the two-tier checks survive a repository with more than one flavour in
it, which they have never had.

**What is already in place**, verified rather than assumed:

- `tool/doctor.sh` already branches on `nixosConfigurations`, and on a non-NixOS
  host warns *build here, but not switch* — which is exactly this machine.
- `tool/checks/test` already calls `check_flavour nixosConfigurations`, and both
  of its probes work against a real NixOS-WSL configuration: the system probe
  returns `x86_64-linux`, so the FOREIGN guard behaves, and
  `config.system.build.toplevel.drvPath` evaluates. The closure has since been
  built as well, so the overlay README's "nothing here has built one" no longer
  holds — only activation is still untested.
- The `blocked/needs-nixos-host` label exists for the activation half.

**What it costs, and the decision that forces.** A *minimal* NixOS-WSL toplevel
— `wsl.enable`, a default user, a `stateVersion`, nothing else:

```
these 169 derivations will be built
these 255 paths will be fetched (615.5 MiB download, 2.2 GiB unpacked)
```

**That number is store-relative, and reading it as absolute will mislead you.**
It is what the machine asking still needs. The real
`nixosConfigurations.wsl` reports 385.4 MiB here rather than 615.5, because this
store already holds much of it from the home-manager configuration — the two
share nixpkgs. On CI's empty store it is the larger figure, and the coverage
block printing the smaller one is not a contradiction. The realised closure is
1.9 GiB either way.

`tool/checks/test` builds every configuration that targets this host, and both
`pre-push` and CI run it. Locally the store amortises that after the first
time. **CI does not** — it starts from nothing every run, which is the point of
it, and this overlay ships no binary cache on purpose (`magic-nix-cache-action`
needs a FlakeHub account, and measured at 6m39s against 1m23s without). So a
`nixosConfigurations` entry on `dev` turns a ninety-second CI run into a
600 MiB download on every pull request, for a configuration nothing can
activate from here.

The obvious economy is to drop CI's build and trust the local one, since this
is a single-host repo and Nix is deterministic. That was tested and it does not
hold — the hook builds the working tree and CI builds the commit, and the entry
under **Bugs worth remembering** shows a case where the first passes and the
second fails. But the same test says something useful for this decision: what
CI proves is *per repository*, not per configuration. One configuration built
from a clean checkout already proves the commit is complete. A second one buys
almost nothing at 615 MiB a run.

**So the rule is which configurations get tier 2, not a new tier.** An earlier
version of this section proposed `nix build --dry-run` as a cheap middle tier,
on the strength of it resolving a whole closure for 9s against eval's 7s. That
was wrong, and the correction is recorded under **Bugs worth remembering**: it
proves nothing eval does not. Forcing `.drvPath` has to instantiate the entire
input graph in order to write that `.drv`, so "every package exists" is a tier
1 guarantee already.

What tier 2 uniquely proves is therefore narrow: that sources fetch and
derivations compile. `tool/checks/test` now evaluates every configuration and
builds the ones this host could activate — `nixos-rebuild switch` needs a NixOS
host, home-manager runs anywhere — and prints what it skipped, with the size,
rather than going quiet:

```
nixosConfigurations.probe   eval ✓ build — not activatable here (615.5 MiB download, 2.2 GiB unpacked)
```

`CHECKS_BUILD_ALL=1` builds everything regardless, which is what to use when a
flavour actually changes. `--dry-run` survives only to produce that size, which
is information rather than verification.

**It worked, and the number is the point of the whole detour.** The first CI run
carrying `nixosConfigurations.wsl` took **100s against a 78s baseline** — 22
seconds for a second flavour, where building it would have meant a 600 MiB
download on an empty store every run. The rule was worth establishing before
the configuration landed rather than after, which is the only reason the
groundwork came first.

**Reversibility, measured.** NixOS-WSL is installed with `wsl --import`, which
registers a *new* distribution; it does not convert or replace an existing one.
This machine currently has:

```
$ wsl.exe --list --verbose
* Ubuntu-26.04      Running    2
  docker-desktop    Stopped    2
```

The experiment adds a third entry. `Ubuntu-26.04` — where this repository, the
activated home-manager generation and the login shell all live — is untouched
and keeps running throughout, and rollback is `wsl --unregister <name>`. The
machine-side risk is genuinely low; the repository-side cost above is the real
constraint, and they should not be confused for each other.

**Input hygiene.** NixOS-WSL pins its own nixpkgs (`e7a3ca8`, 2026-07-11),
which is not ours. Without `inputs.nixos-wsl.inputs.nixpkgs.follows = "nixpkgs"`
the flake evaluates two of them. The probe above used `follows` and the
configuration evaluated clean, so there is no known reason to carry a second.

---

## Next

**M2 is closed.** `just switch-shell` ran on 2026-08-04 — it needs a password
twice, for `sudo` and `chsh`, so it was the one step an agent could not do.

Everything moved aside during activation is still on disk, under
`*.before-home-manager.<stamp>`, plus a tarball of the whole set at
`~/dotfiles-backup/`. Delete them once the shell switch has been lived with for
a few days — not before, because the bash fallback is what you land in if zsh
fails to start. Five files and one tarball; `find ~ -maxdepth 3 -name
'*.before-home-manager.*'` lists them.

**Left undone deliberately:** `programs.yazi.shellWrapperName` prints a
`stateVersion` deprecation warning on every build, so it appears in the
coverage block pasted into every pull request. The fix is the one in
`troubleshooting.md` — pin the option or bump `stateVersion` — and it was left
out of the M2 merge rather than folded into an unrelated change.

**M3 is open, and NixOS-WSL is the first experiment.** Its groundwork is the
section above; the one thing to decide before any code is where a
`nixosConfigurations` entry lives, given what it does to CI. `gitleaks` arrived
with M2 as predicted, so the secret scan now runs locally as well as in CI and
the other waiting experiment — secrets management — no longer starts from a
gap.

**A standing chore, not a milestone:** re-run the M1 clone verification whenever
the files it exercises change. It went stale in a day and nothing flagged it.

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
