{user, ...}: {
  wsl = {
    enable = true;
    # The account WSL logs into. Same unix account as the standalone
    # home-manager configuration, passed through specialArgs from flake.nix so
    # the two cannot drift apart — but note that nothing here manages that
    # account's dotfiles. See system/README-first.md.
    defaultUser = user;
  };

  # Not 1000, and this is load-bearing rather than taste. Every WSL
  # distribution shares one cgroup v2 hierarchy, so two of them whose users
  # have the same UID both want `/user.slice/user-<uid>.slice/user@<uid>.service`
  # — the second to boot gets EBUSY and its `systemd --user` never starts, which
  # surfaces as WSL's "Failed to start the systemd user session". The Ubuntu
  # side of this machine has user1 at 1000.
  #
  # Not 1001 either: that is precisely what Ubuntu's next `useradd` hands out.
  # Its accounts are 1000 and then nixbld at 30001+, so 2000 is clear of both
  # now and of anything either side adds in the near future.
  #
  # Verified inside the running distro before being written here: a normal user
  # at an unclaimed UID brings up `user@<uid>.service` *and* its
  # `/run/user/<uid>/bus` socket, while UID 1000 cannot start at all.
  # See docs/troubleshooting.md under WSL's message.
  users.users.${user}.uid = 2000;

  # A fresh install, so this is the release it was installed with rather than a
  # number copied from home/default.nix. They are unrelated: home.stateVersion
  # tracks home-manager's option defaults, this one tracks NixOS's, and the two
  # projects release on different schedules.
  system.stateVersion = "26.05";

  # Deliberately almost empty. The experiment is whether a system layer earns
  # its place here, and starting it with packages and services already moved in
  # would answer that question by assumption. Anything added here should be
  # something standalone home-manager genuinely cannot declare.
}
