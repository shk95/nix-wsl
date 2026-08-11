# When Windows programs stop working in WSL

One page, for whoever hits this next. If `.exe` files suddenly fail everywhere
in a WSL distribution, this is almost certainly why.

## The symptom

```
$ cmd.exe /c echo hi
exec format error
```

Everything Windows-side breaks at once — `powershell`, `explorer.exe`,
`clip.exe`, `code`, `wsl.exe`. But `/mnt/c` still reads fine, and that is what
makes it confusing: the drive is healthy, only *running* Windows programs is
broken.

## It is not your fault

Nothing you changed in this distribution caused it. Not Nix, not the shell, not
a config file. **Another WSL distribution shut down and took it with it.**

Two afternoons went into blaming the wrong things here. Don't repeat them.

## Fix it — five seconds, needs root

```sh
echo ':WSLInterop:M::MZ::/init:P' | sudo tee /proc/sys/fs/binfmt_misc/register
```

Effective immediately, no restart. `wsl --shutdown` from a Windows terminal also
fixes it. You cannot run `wsl.exe` from in here to do that — it is an `.exe`.

## Why it happens

Every WSL distribution shares one kernel, and therefore one `binfmt_misc`
registry — the kernel table that says "a file starting with `MZ` is a Windows
program, hand it to `/init`". Interop is a single entry in it, and no
distribution owns it.

When a distribution running systemd shuts down, systemd's very last act flushes
that registry. Not its own entries — **all** of them, for every distribution
still running. There is no unit and no setting in that path; it is compiled into
`systemd-shutdown`.

## Who can do this to you

Only distributions running systemd. WSL states which in its own log
(`journalctl | grep 'WSL ('`):

```
WSL (2 - init-systemd(NixOS))      ← has systemd. can flush
WSL (1 - init(docker-desktop))     ← no systemd. cannot
```

This repository's NixOS flavour is immunised and is not a suspect. Anything else
running systemd is.

## If you add another distribution

Give it this, once per boot, as root — it is what `modules/wsl.nix` declares for
the NixOS flavour:

```sh
mount --make-private /proc/sys/fs/binfmt_misc      # don't propagate to the others
mount -o remount,bind,ro /proc/sys/fs/binfmt_misc  # bind: this mount, not the shared superblock
```

systemd skips the flush when it finds the registry read-only. The distribution
loses nothing — read-only blocks *writing* the table, not using it.

**Keep the `bind`.** Without it the read-only lands on the shared superblock and
every distribution loses the ability to register, which is the opposite of the
point. Check afterwards: `grep binfmt_misc /proc/mounts` should say `ro` in the
new distribution and `rw` everywhere else.

## Going deeper

- `docs/troubleshooting.md` — the same thing filed under its literal error text,
  plus how to tell a flush from a deletion.
- `docs/status.md` — the full investigation, including two fixes that looked
  right and were not.
