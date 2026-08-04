# Imported by `homeConfigurations.user1` only, never by the NixOS flavour.
#
# Standalone home-manager is not a lesser version of the NixOS one to be phased
# out — it is the only thing that works on a machine whose distro you cannot
# replace, which is the case worth keeping it for. What it *cannot* do is reach
# outside `$HOME`, so the two flavours genuinely differ here rather than merely
# being configured differently.
#
# Everything below would either conflict with the NixOS module or be redundant
# under it. When something new turns out to be standalone-only, this is where it
# goes; keeping it out of `default.nix` is what makes that file shareable.
{user, ...}: {
  imports = [./nix.nix];

  home = {
    # The NixOS module derives both of these from the NixOS user account, and
    # defining them here as well is a conflict rather than a duplicate.
    username = user;
    homeDirectory = "/home/${user}";
  };

  # Under NixOS the system provides `home-manager`; here nothing else would.
  programs.home-manager.enable = true;
}
