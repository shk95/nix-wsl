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

**Both flavours are first-class, and `home/` is shared between them.**
Superseded the original decision, which was "standalone home-manager, not
NixOS-WSL, revisit only if something genuinely system-level is needed". Two
things changed it.

The first is that something system-level was in fact needed, and had already
cost a day: M2's last open item was the login shell, which needed `sudo` and
`chsh` and so could not be done without a person. NixOS expresses it as
`users.users.<name>.shell` and registers `/etc/shells` itself. The same is now
true of the UID in `../system`, which no standalone option can reach.

The second is that the containment runs one way, and the intuitive reading of it
is backwards. **NixOS-WSL is a superset of standalone**, not an equivalent:
anything home-manager expresses, NixOS can express too via
`home-manager.nixosModules.home-manager`, while `users.*`, `services.*`,
`environment.systemPackages`, `boot.*` and `wsl.*` have no standalone
counterpart at all — `home-manager` has no `users` option, checked rather than
assumed. So a configuration developed *against* NixOS-WSL drifts into system
options and then cannot be run standalone, whereas one developed in `home/`
runs under both. The safe direction is standalone → NixOS.

**Standalone is therefore not demoted to a test rig.** It is the only thing that
works on a machine whose distro you cannot replace — a work laptop with an
Ubuntu WSL you do not control — and that is a real use rather than a hedge.
Keeping it first-class costs nothing *because* of the structure: features are
written once and evaluated twice.

Since the dendritic restructure the mechanism is an option rather than a
directory. A file under `modules/` contributes to `modules.homeManager.shared`
(both flavours), `modules.homeManager.standalone` (no system layer beneath) or
`modules.nixos.wsl`, and `modules/flake/configurations.nix` is the only place
that decides which of those an evaluator receives. Before, the same rule was a
directory convention with the reasoning in a comment, which is what let
`allowUnfree` and `home/nix.nix` go wrong in the two ways recorded below.

**Packages go to home-manager, not the system layer**, and the reason is the
same containment read forwards. `useUserPackages = true` already folds
`home.packages` into the NixOS closure — built by `nixos-rebuild`, rolled back
with the generation, installed to `/etc/profiles/per-user` — so promoting one to
`environment.systemPackages` gains availability to root and loses it for
standalone entirely, because `environment.*` has no standalone equivalent. The
temptation runs the other way (a "common" layer feels like it belongs at the
bottom), which is why it is written down.

**The unix account and the git identity are separate variables.** `user =
"user1"` is the login on this host; `gitName = "shk"` is the commit author.
They were split because they genuinely differ here, and fusing them produces
commits authored by a machine account. Both are declared options in
`modules/flake/identity.nix`, which is also how they stopped being `specialArgs`.
Any future host merged into this repo inherits the split for free.

**`nix.package` is set explicitly in `modules/nix-conf.nix`.** Standalone home-manager
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

**Sharing `home/` between the flavours did not make them agree.** The point of
the shared directory is that one set of modules is evaluated under both, so
neither drifts. It does not cover what they are evaluated *with*:
`allowUnfree = true` was written inline in the standalone `import nixpkgs`, and
the NixOS flavour builds its own pkgs from `nixpkgs.config`, so the same
`home/` was evaluated under two different nixpkgs configurations.

```
standalone  true
nixos-wsl   false
```

Nothing in `home/` needs an unfree package, which is why it survived review:
the first one added would have built standalone, failed under NixOS, and given
no hint that the *flavour* was the variable. Both now read one `nixpkgsConfig`
in the flake's `let`, and the arguments `home/` receives are defined once as
`homeArgs` for the same reason. Worth generalising: sharing a module directory
makes drift in the modules impossible and drift in their *arguments* invisible,
so anything passed in from `flake.nix` needs a single definition rather than a
matching pair. Found by asking what the two flavours disagreed on, not by
anything failing.

**A prompt configuration where 20 of 28 lines did nothing, and the noise hid two
real bugs.** `home/starship.nix` looked thoroughly configured. Diffing it
against starship's own computed defaults showed most of it restating them
exactly — and among the handful of lines that did have an effect:

- `git_status.stashed = "$"` **removed the stash indicator**. `$` opens a
  variable reference in a starship format string, so it parsed as one, resolved
  to nothing, and rendered `[?]` where the default `'\$'` gives `[$?]`. A stash
  existed and the prompt never said so.
- The whole `time` block was dead twice over: `disabled = true` is its default
  so it never rendered, and the format it carried, `[$hour:$minute]($style)`,
  names two variables the module does not have. Enabling it alone produced a
  bare `:`. The module exposes `$time`; the clock shape belongs in
  `time_format`.

The second one is the more instructive: a dead setting cannot be wrong, so
*disabled* hid *incorrect*, and fixing one defect was needed before the other
became visible at all. A no-op line is not merely clutter — it is a place a bug
can wait.

The check is cheap and mechanical, and generalises to anything with layered
defaults:

```sh
STARSHIP_CONFIG=/dev/null starship print-config > default.toml
starship print-config                           > ours.toml
diff default.toml ours.toml   # anything absent can be deleted
```

Applying it to the replacement caught a third error, this one mine: the comment
justifying `nix_shell.heuristic = true` claimed `nix develop` does not set
`IN_NIX_SHELL`. It does. The setting is still right, for `nix shell`, which does
not — but the reason recorded in the file was false until it was tested rather
than asserted.

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
| imported and booted | ✓ 2026-08-04 — NixOS 26.11 (Zokor), systemd 261 |
| system-level systemd | ✓ works |
| user-level systemd | ✗ **blocked by WSL, not by NixOS** — see below |
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

**The image has to be staged onto a Windows drive first.** `wsl --import` will
not take a UNC source, which is not obvious because the path itself is
perfectly readable — `dir \\wsl.localhost\...` and `dir \\wsl$\...` both list
the file. It is the importer that refuses, so the natural one-step version of
this fails for a reason that looks like a path problem and is not. In
`troubleshooting.md` under its symptom.

`just nixos-stage` copies it to `C:\WSL\`, checks the copy is still a complete
gzip stream, and prints the command with the Windows path filled in. Four
seconds over drvfs. Then, from PowerShell or CMD:

```
wsl --import NixOS C:\WSL\NixOS C:\WSL\nixos.wsl
wsl -d NixOS
```

There are now two copies of a 576 MB file, one in the repo and one on `C:`.
Both are disposable once the distribution is registered; the repo one needs
`sudo rm`.

### The first real result: the system layer works, the user layer cannot

`wsl -d NixOS` boots and prints
*`Failed to start the systemd user session for 'user1'`*. It reads like a
teething problem in NixOS-WSL. It is not a NixOS problem at all, and the
diagnosis is worth more than the experiment's original question.

**All WSL distributions share a single cgroup v2 hierarchy.** Ubuntu-26.04 and
NixOS both have `user1` at UID 1000, so both want
`/user.slice/user-1000.slice/user@1000.service`. Ubuntu booted first and owns
it; NixOS's systemd gets `EBUSY` and gives up. Measured, not assumed:
`/sys/fs/cgroup` reports the same `st_dev` from both, and from inside NixOS you
can enumerate Ubuntu's delegated subtree with Ubuntu's three processes in it.

The control experiment is what makes it certain — in NixOS, at the same moment:

```
user@0.service    (UID 0,    unclaimed)      → active
user@1000.service (UID 1000, held by Ubuntu) → failed
```

Same kernel, same systemd, same second; the only variable is whether another
distribution already holds that UID's path. Upstream:
[microsoft/WSL#40519](https://github.com/microsoft/WSL/pull/40519) isolates
per-distro cgroups and is not in WSL 2.7.11.0.

**Why this matters for the question M3 was asking.** The experiment exists to
find out whether a system layer earns its place, and services are the reason to
want one. System services work here. *User* services do not, for as long as the
Ubuntu side is running — which on this machine is always, because that is where
this repository lives. So a NixOS-WSL setup that put home-manager inside the
system configuration would have its user services silently fail, and the cause
would be nothing to do with the configuration. That is a genuine constraint on
the design, discovered by booting the thing rather than by reasoning about it.

**The UID workaround works, and is now declared.** Tested inside the running
distro before being written down, with a normal non-root account rather than
root, since root might plausibly be treated differently:

```
user@1001.service (UID 1001, unclaimed)  → active,  /run/user/1001/bus exists
user@1000.service (UID 1000, Ubuntu's)   → cannot start
```

`../system` therefore sets `users.users.user1.uid = 2000`. Not 1001, which is
exactly what Ubuntu's next `useradd` would hand out; Ubuntu holds 1000 and then
nixbld at 30001+, so 2000 is clear of both. It takes effect on a **freshly
imported** distribution — changing it on the existing one would leave
`/home/user1` owned by the old UID.

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

### That last paragraph was wrong, and finding out cost a day

**"Untouched and keeps running throughout" is false.** Booting the imported
distribution on 2026-08-04 broke Windows interop *in Ubuntu* — every `.exe`
failed with `exec format error` — and it stayed broken for a day, across no
reboot, until the registration was written back by hand on 2026-08-05. Nothing
in Ubuntu had changed.

**Why it was mis-attributed.** The two things that had changed on the Ubuntu
side that week were the home-manager activation and the bash→zsh login shell
switch, so both were suspected first. Neither can touch `binfmt_misc`; it is a
kernel-global registry that a user-level generation has no access to. The
timeline is what settles it — interop was healthy at 13:28, the NixOS
distribution booted at 13:49, and the first `exec format error` is at 14:30,
with nothing else in the journal in between.

**A third shared-kernel resource, after cgroups.** WSL2 gives every distribution
its own mount and PID namespaces but one kernel, and `binfmt_misc` is global to
it. The registry is not merely shared, it is *unowned* — and worse, the natural
way to "add" to it is destructive. `systemd-binfmt`'s `apply_rule()` deletes the
entry named by each `binfmt.d` rule and registers its own in its place, so a
rule named `WSLInterop` in any distribution **takes the shared entry over**.
Only `--unregister` (`ExecStop`) flushes wholesale, via `-1` into
`.../binfmt_misc/status`.

Ubuntu is protected — WSL generates a drop-in clearing that `ExecStop` and
re-registering afterwards, and offers `[boot] protectBinfmt` to disable it. But
a drop-in in one distribution only guards that distribution's copy of the unit.
Nothing guards the registry.

**What is declared now.** `modules/wsl.nix` sets `wsl.interop.register = true`
and clears `ExecStop` on `systemd-binfmt.service`, so this flavour registers its
own entry on boot and never flushes anyone's. NixOS-WSL defaults that option to
false, commented "use the existing registration" — a bet that another
distribution registered `WSLInterop` and will keep it registered, which is
precisely the bet that loses when two distributions run. The design consequence
is the same shape as the UID one: **a fragment can be correct in isolation and
still be wrong because another distribution is running**, and neither failure
is visible from inside the distribution that causes it.

### The fix was wrong, and the test said so

Tested the same day, 2026-08-05, and **it does not work**. Recorded in full
because a failed experiment is a perfectly good outcome and the next session
must not retry it.

**The test was real.** The tarball a person built at 15:28 resolves to the same
store path as `nix build .#nixosConfigurations.wsl.config.system.build.tarballBuilder`
on the fix branch, and embeds toplevel `cwkb59h…` — the one carrying both
settings. So this is a negative result, not a stale build.

**What the journal shows.** The NixOS distribution's own systemd logs into
Ubuntu's journal, which is a piece of luck worth remembering:

```
proc-sys-fs-binfmt_misc.automount: Path /proc/sys/fs/binfmt_misc is already a mount point, refusing start.
Starting Set Up Additional Binary Formats...      ← systemd-binfmt ran
Finished Set Up Additional Binary Formats.        ← 16 ms, no warnings
...
systemd-binfmt.service: Deactivated successfully. ← stopped cleanly; ExecStop= worked
```

So both halves did exactly what they were written to do. Interop broke anyway.

**Why the design is wrong, not merely incomplete.** Reading
`systemd/src/binfmt/binfmt.c` after the fact instead of before it:
`apply_rule()` deletes the entry by name and re-registers. Declaring a rule
named `WSLInterop` therefore **destroys Ubuntu's entry and substitutes ours** —
`:WSLInterop:M::MZ::/run/binfmt/WSLInterop:PF`, whose interpreter is a tmpfiles
symlink in this distribution's `/run`, resolvable elsewhere only because `F`
pins the inode. Ubuntu's `/init:P` is gone, replaced by something whose lifetime
is tied to a distribution that is about to be terminated or unregistered. Taking
ownership of shared state you are about to delete is worse than leaving it
alone.

There is a second hazard in the same change. systemd's comment on
`disable_binfmt()` says the shutdown flush exists "to cover for rules using F,
since those might pin a file and thus block us from unmounting stuff cleanly".
WSL can disarm that flush for Ubuntu because WSL's rule is `P` with no `F`. Ours
is `PF`. The change disarms the flush *and* introduces the pinning rule.

**What is still not known.** Which moment does the damage — the NixOS boot, its
shutdown, or `wsl --unregister` — is unresolved, and the run above cannot say,
because nobody looked at the registry from Ubuntu in between. Only the
unregister path was exercised; terminate was not. Note also that on this host
`.../binfmt_misc/status` still carries its mount-time timestamp, which suggests
no wholesale flush has ever run here and that every disappearance so far has
been a by-name takeover.

**Operationally, for now:** run one distribution at a time, and re-register by
hand afterwards. `docs/troubleshooting.md` carries the command.

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

## M3's second experiment: the dendritic module pattern

**Declared before starting, on 2026-08-04, so that abandoning it is a result
rather than a failure.** M3's bar is that an experiment leaves something behind,
not that it succeeds, and a restructure is the kind of work that acquires sunk
cost quickly. The exit criteria below are what they were at the start; if this
section ends up describing a reverted experiment, that is a pass.

### Why now

The module layout is descended from a hand-made prototype, and its shape has
started producing defects rather than merely being untidy. Two so far:

- `allowUnfree` differed between the flavours because it was written where only
  one of them could read it (fixed in the entry above).
- `home/nix.nix` is standalone-only, sits among shared modules, and says so
  nowhere except a comment in the file that imports it. Nothing stops the next
  reader from adding it to `home/default.nix` and breaking the NixOS flavour.

Both are the same shape: **the layout expresses "what kind of file is this" by
path, and gets it wrong.** Twenty files is the cheap moment to change that. Sixty
is not.

### What the pattern is, and what it buys here

Every file below the module tree is a flake-parts module, auto-imported, and each
one implements one *feature* across every configuration that feature applies to
— rather than one layer of one configuration. Fragments are stored as option
values (`flake.modules.<class>.<name>`) and merged by the `deferredModule` type,
so several files may contribute to the same name.

Three things it addresses directly:

1. **A path is a feature name, not a type.** Whether a fragment reaches the
   standalone flavour is decided by which configuration imports it, which is one
   place, rather than by which directory it sits in.
2. **A feature spanning system and user lives in one file.** This is the question
   left open above — where a service and its user-side configuration go — and the
   answer stops being a directory convention.
3. **`specialArgs` goes away.** The pattern names it as an anti-pattern, and this
   repository is a live example: `user`, `gitname` and `gitmail` are threaded
   through `specialArgs` *and* `extraSpecialArgs`, which is why they had to be
   deduplicated into `homeArgs` one entry above. That fix was local; declaring
   options instead removes the class of problem.

### Exit criteria

**Keep it if all of these hold.**

- Both flavours produce **byte-identical** store paths to the ones this branch
  started from. A restructure that changes behaviour is not a restructure, and
  this is the invariant that makes the claim checkable rather than argued:

  ```
  standalone  /nix/store/q2dccd1c3yjnkcij0r9blxwpyx3ldzqp-home-manager-generation
  nixos       /nix/store/rq1nr1kr8l3gdiyzrry6lvzsjxq9v65w-nixos-system-nixos-26.11.20260801.148bab9
  ```

- The containment rule is enforced by the structure rather than by a comment: it
  must be possible to point at the single place that decides whether a fragment
  reaches standalone.
- `tool/checks/test` still enumerates both configurations and still reports
  coverage, with no new host assumptions.
- `flake.lock` gains only the new inputs and their transitive nodes. Existing
  pins must not move — adding inputs is not an excuse to update the others.

**Revert it if any of these turn out to be true.**

- Auto-import makes "what sets this option?" materially harder than reading an
  `imports` list did. This repository's habit is that a reader can trace a
  setting to its cause; a pattern that trades that away for brevity is the wrong
  trade here.
- The two new inputs (`flake-parts`, `import-tree`) cost more in evaluation time
  or lock churn than the structure returns.
- The pattern needs option declarations whose only purpose is to satisfy the
  pattern. Its own list of anti-patterns includes exactly that, and an
  `enable` flag for a feature this machine always has is the likely form.

### Cost accepted going in

The payoff scales with hosts × features, and there is one host. So the honest
case for doing it now is not this month's convenience — it is that the layout has
already produced two defects of the same shape, and that a restructure is
cheapest before there is more to move.

### Result: kept, and the store-path criterion was not met

**A pure restructure cannot be hash-stable, and the reason is worth keeping.**
The criterion above asked for byte-identical store paths. Neither flavour
produced one:

```
standalone  q2dccd1c…  ->  b1z4n0im…
nixos       rq1nr1kr…  ->  wggsi64v…
```

Every difference traces to one cause. `home.packages` is a **list**, list-valued
options merge in module evaluation order, and import-tree's collection order is
not the order the hand-written `imports` lists happened to have. The package
*set* is unchanged — 42 entries in both, `diff` on the sorted names is empty —
but `noto-fonts-cjk-sans` moved from position 19 to position 1, which changes the
`buildEnv` input list, which changes the profile's hash, which changes every
generated file that embeds the profile path, which changes the generation.

The full extent of it, measured rather than assumed:

| What differs | Why |
| --- | --- |
| `home.packages` order | module merge order; the set is identical |
| profile hash | `buildEnv` takes the list as input |
| `10-hm-fonts.conf` | embeds the profile path — identical once that path is masked |
| fontconfig cache filenames | their names are hashes of the font directory path |
| NixOS `home-manager-user1.service` | one `ExecStart=` line naming the generation |
| `.zshrc`, three lines | a comment naming a moved file, updated on purpose |

Nothing else. Every other generated file is byte-identical, and every symlink
target inside both profiles matches. The `_class`/`_file` wrapper on the module
option was suspected and cleared — removing it entirely changed no hash.

So the criterion was the right instrument and the wrong threshold: it caught a
real difference, and the difference turned out to be an ordering artefact with no
behavioural content. **The generalisation is what to keep**: for any option whose
type is a list, a hash is a function of module order, so "prove the restructure
changed nothing" cannot be done by comparing store paths alone. Compare the
built trees and the option's *set*. Written down here because the next
restructure will hit it again and the first instinct will be to hunt for a real
change that is not there.

One deviation from the pattern's usual spelling. Fragments live in a top-level
`modules` option rather than `flake.modules`, because making them flake outputs
adds `warning: unknown flake output 'modules'` to every `nix flake check` — every
hook, every CI run. This repository already carries one such warning and treats
it as a cost. Exporting them later is one line, and flake-parts' `touchup` module
is the other way out.

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
