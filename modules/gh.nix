_: {
  # `gh` was a plain entry in the package list. Declaring the program instead is
  # what generates the git credential helper, and that turned out to matter: the
  # pre-activation inventory found the helper living in an unmanaged ~/.gitconfig,
  # which modules/git.nix moves aside. Every remote here is HTTPS, so without
  # this, activation would take push authentication with it.
  #
  # The hosts are named explicitly rather than left to the default so that a
  # change in that default cannot silently drop one.
  modules.homeManager.shared = {
    programs.gh = {
      enable = true;

      settings.aliases = {
        # Was in an unmanaged ~/.config/gh/config.yml, which this replaces.
        # home-manager writes `aliases: {}` when nothing is declared, so leaving
        # it out is not neutral — it deletes the alias.
        co = "pr checkout";
      };

      gitCredentialHelper = {
        enable = true;
        hosts = [
          "https://github.com"
          "https://gist.github.com"
        ];
      };
    };
  };
}
