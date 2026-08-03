_: {
  # `gh` was a plain entry in packages.nix. Declaring the program instead is
  # what generates the git credential helper, and that turned out to matter:
  # the pre-activation inventory found the helper living in an unmanaged
  # ~/.gitconfig, which git.nix moves aside. Every remote here is HTTPS, so
  # without this, activation would take push authentication with it.
  #
  # The hosts are named explicitly rather than left to the default so that a
  # change in that default cannot silently drop one.
  programs.gh = {
    enable = true;

    gitCredentialHelper = {
      enable = true;
      hosts = [
        "https://github.com"
        "https://gist.github.com"
      ];
    };
  };
}
