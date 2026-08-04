# One feature, two module classes, one file — and the clearest small example of
# what the pattern buys. These two options are related only in that both are
# state versions and both are easy to get wrong together; they belong to
# different evaluators and the old layout had them in different directories,
# where the comment explaining that they are *unrelated* had to be written twice.
_: {
  # Tracks home-manager's option defaults. Bump only after reading its release
  # notes for what else changes with it.
  modules.homeManager.shared.home.stateVersion = "25.05";

  # Tracks NixOS's, on a different release schedule — this is the release the
  # NixOS flavour was first installed with, not a number copied from above.
  modules.nixos.wsl.system.stateVersion = "26.05";
}
