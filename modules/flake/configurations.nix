# The one place that decides which fragments reach which flavour.
#
# That sentence is the point of the restructure. The rule it enforces used to
# live in a comment — `home/` was shared, `home/standalone.nix` was not, and
# nothing but prose stopped the next reader from adding the second to the first
# and quietly breaking the NixOS flavour. Now the rule is three lines of code in
# one file, and a fragment's path says nothing about which flavour gets it.
#
# Containment still runs one way and still reads backwards. NixOS-WSL is a
# *superset*: it can express everything home-manager can, plus `users.*`,
# `services.*` and the rest, none of which standalone has any equivalent for. So
# a fragment written for `nixos` can be impossible to run standalone, while one
# written for `homeManager.shared` runs under both. Standalone is not a test rig
# on the way out — it is the only thing that works on a machine whose distro you
# cannot replace, and what `homeManager.shared` holds is the whole of it.
{
  config,
  inputs,
  withSystem,
  ...
}: let
  inherit (config.identity) user;
  home = config.modules.homeManager;
in {
  flake = {
    # Standalone: no system layer, so `shared` plus the fragments that only make
    # sense when nothing is underneath.
    homeConfigurations.${user} = withSystem "x86_64-linux" ({pkgs, ...}:
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [home.shared home.standalone];
      });

    # The NixOS flavour gets `shared` and deliberately not `standalone`: the
    # things in there either conflict with what the system already provides
    # (`home.username` is derived from the user account) or are redundant under
    # it (`programs.home-manager`).
    nixosConfigurations.wsl = inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        inputs.nixos-wsl.nixosModules.default
        inputs.home-manager.nixosModules.home-manager
        config.modules.nixos.wsl
        {
          nixpkgs.config = config.nixpkgsConfig;

          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.${user} = home.shared;
          };
        }
      ];
    };
  };
}
