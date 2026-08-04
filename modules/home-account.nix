# Which account this home belongs to, and the tool that manages it.
#
# Standalone only, and for one reason in two forms: under NixOS both of these
# come from the system. `home.username` and `home.homeDirectory` are derived from
# the user account, so defining them again there is a conflict rather than a
# duplicate; and `programs.home-manager` installs the very tool the NixOS module
# already provides.
{config, ...}: let
  inherit (config.identity) user;
in {
  modules.homeManager.standalone = {
    home = {
      username = user;
      homeDirectory = "/home/${user}";
    };

    programs.home-manager.enable = true;
  };
}
