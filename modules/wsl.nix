{config, ...}: let
  inherit (config.identity) user;
in {
  modules.nixos.wsl = {
    wsl = {
      enable = true;
      # The account WSL logs into. The same unix account the home-manager
      # fragments configure, read from one declared option so the two cannot
      # drift — but note that nothing here manages that account's dotfiles.
      defaultUser = user;
    };

    # Not 1000, and this is load-bearing rather than taste. Every WSL
    # distribution shares one cgroup v2 hierarchy, so two of them whose users
    # have the same UID both want
    # `/user.slice/user-<uid>.slice/user@<uid>.service` — the second to boot gets
    # EBUSY and its `systemd --user` never starts, which surfaces as WSL's
    # "Failed to start the systemd user session". The Ubuntu side of this machine
    # has this user at 1000.
    #
    # Not 1001 either: that is precisely what Ubuntu's next `useradd` hands out.
    # Its accounts are 1000 and then nixbld at 30001+, so 2000 is clear of both
    # now and of anything either side adds in the near future.
    #
    # Verified inside the running distro before being written, and then verified
    # again by a fresh import: `systemctl --user is-system-running` answers
    # `running`, where UID 1000 could not start the manager at all. See
    # docs/troubleshooting.md under WSL's message.
    users.users.${user}.uid = 2000;

    # The second shared-kernel collision, and the same shape as the UID one
    # above — except this one breaks the *other* distribution rather than this
    # one, which is why it took a day to attribute.
    #
    # Every WSL distribution also shares one `binfmt_misc` registry. WSL's
    # interop — running `.exe` from Linux — is one entry in it,
    # `:WSLInterop:M::MZ::/init:P`, registered by whichever distro booted first.
    # It is global state that no distro owns and any distro can empty.
    #
    # Upstream defaults `wsl.interop.register` to false, commented "use the
    # existing registration". That is a bet that somebody else registered
    # WSLInterop and will keep it registered. On 2026-08-04 the bet lost: this
    # flavour was imported and booted, and Ubuntu could not exec a `.exe`
    # afterwards — for a day, across no reboot, until the entry was written back
    # by hand.
    #
    # So: own the registration rather than consume one we did not declare. This
    # writes /etc/binfmt.d/nixos.conf and pulls in systemd-binfmt.service, which
    # puts the entry back on every boot of this distro.
    #
    # !! TESTED 2026-08-05 AND IT IS IRRELEVANT. Kept only so the next session
    # does not retry the same idea.
    #
    # Measured from Ubuntu at each step: booting this distro leaves Ubuntu's
    # entry **unharmed** — WSL's generated drop-in re-registers its own
    # `/init:P` line as a second ExecStart, after the rule below, so the rule
    # below never survives to matter. What breaks interop is this distro's
    # *shutdown*, and the journal rules out every mechanism that could be
    # configured: no flush (status never written), no unmount, no ExecStop
    # process. The deletion is by name, done by WSL outside this distro's
    # systemd. Nothing declarable here sits in that path — which is also why
    # 2026-08-04 broke identically with `register` at its default false.
    #
    # See docs/status.md, "The measurement that settled it".
    #
    # What it writes is *not* WSL's line. nixpkgs routes every interpreter
    # through a tmpfiles symlink, so the entry reads
    #
    #   :WSLInterop:M::MZ::/run/binfmt/WSLInterop:PF   (+ L+ /run/binfmt/WSLInterop → /init)
    #
    # and `/run/binfmt/WSLInterop` exists only in *this* distro's mount
    # namespace. That looks like a bug for a registry every distro reads, and it
    # is why the `F` in `PF` is load-bearing rather than tidy: `fixBinary` makes
    # the kernel open the interpreter once, at registration, and exec the pinned
    # inode with no path lookup afterwards. Without it a process in another
    # distro would resolve that path in its own namespace, find nothing, and be
    # no better off than before. Do not "simplify" this to interpreter = "/init".
    wsl.interop.register = true;

    # ...and, having taken the unit, disarm its stop action. Upstream's
    # systemd-binfmt.service carries `ExecStop=systemd-binfmt --unregister`,
    # which *is* a whole-registry flush — `-1` into `.../binfmt_misc/status`,
    # discarding every entry, because binfmt_misc offers no way to unregister
    # selectively. In a registry shared with every other running distribution,
    # that is somebody else's state being discarded at our shutdown.
    #
    # !! But read systemd's own comment on `disable_binfmt()` before deciding
    # this is free: the flush is there "to cover for rules using F, since those
    # might pin a file and thus block us from unmounting stuff cleanly". WSL can
    # disarm it for Ubuntu safely because WSL's own rule is `P` with no `F` and
    # pins nothing. The rule above is `PF`. Disarming the flush while
    # introducing an F rule is the combination systemd is warning about, and it
    # is untested.
    #
    # WSL knows: it generates precisely this override into
    # /run/systemd/generator/systemd-binfmt.service.d/override.conf on the
    # Ubuntu side, headed "to prevent binfmt.d from overriding WSL's binfmt
    # interpreter", and offers `[boot] protectBinfmt` in wsl.conf to turn it
    # off. Declaring it here rather than relying on that generator having fired
    # inside this distro, which is not something the flush evidence lets us
    # assume.
    systemd.services.systemd-binfmt.serviceConfig.ExecStop = [""];

    # Deliberately almost empty. The experiment is whether a system layer earns
    # its place, and starting it with packages and services already moved in
    # would answer that question by assumption. What belongs here is what
    # standalone home-manager genuinely cannot declare — and note that moving a
    # package here does not "share" it, it *removes* it from the standalone
    # flavour, which has no `environment.systemPackages` at all.
  };
}
