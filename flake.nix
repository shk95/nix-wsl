{
  description = "Reproducible dev environment for WSL, managed by Nix + standalone home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # M3's first experiment. `follows` is not optional housekeeping here:
    # NixOS-WSL pins its own nixpkgs, and without this the flake evaluates two
    # of them.
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    home-manager,
    nixos-wsl,
    ...
  }: let
    system = "x86_64-linux";

    # unix account this config is applied to (this WSL instance's login user)
    user = "user1";
    # identity used for git commits, independent of the unix account above
    gitname = "shk";
    gitmail = "101378576+shk95@users.noreply.github.com";

    # One nixpkgs configuration, read by both flavours. It used to be written
    # inline in the `import nixpkgs` below, which reached the standalone flavour
    # only: `nixosConfigurations.wsl` builds its own pkgs from `nixpkgs.config`
    # and so evaluated the *shared* `home/` with allowUnfree = false. Nothing in
    # `home/` needs an unfree package today, which is exactly why it went
    # unnoticed — the first one added would have built standalone and failed
    # under NixOS, for no visible reason.
    nixpkgsConfig = {
      allowUnfree = true;
    };

    # What `home/` expects to be handed. Defined once for the same reason: it is
    # imported by both flavours, so the two must agree on the arguments or one
    # of them stops evaluating.
    homeArgs = {inherit user gitname gitmail;};

    pkgs = import nixpkgs {
      inherit system;
      config = nixpkgsConfig;
    };
  in {
    # Standalone: no system layer, so this is what runs on a machine whose
    # distro cannot be replaced. `./home` is shared with the NixOS flavour
    # below; `./home/standalone.nix` is the part that only makes sense here.
    homeConfigurations.${user} = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = homeArgs;
      modules = [./home ./home/standalone.nix];
    };

    # M3's first experiment, and a second flavour for the checks. Nothing here
    # can activate this — `nixos-rebuild switch` needs a NixOS host, and this
    # one is Ubuntu — so `tool/checks/test` evaluates it and reports the build
    # it skipped. `CHECKS_BUILD_ALL=1` builds it anyway.
    nixosConfigurations.wsl = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit user;};
      modules = [
        nixos-wsl.nixosModules.default
        home-manager.nixosModules.home-manager
        ./system
        {
          # `useGlobalPkgs` makes home-manager use this system's pkgs rather
          # than importing its own, so this is the only place the shared
          # `home/` can be told about allowUnfree — the equivalent
          # `nixpkgs.config` under home-manager is refused outright when
          # `useGlobalPkgs` is on.
          nixpkgs.config = nixpkgsConfig;

          # The same `./home` the standalone flavour uses. Sharing it here is
          # the whole point: one set of modules, evaluated under both, so
          # neither drifts from the other by neglect.
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = homeArgs;
            users.${user} = ./home;
          };
        }
      ];
    };

    # `nix develop` gives you a shell with everything needed to edit this
    # flake. `just` is in here as well as in home.packages, so the command
    # runner is available before anything has been activated.
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [just alejandra nixd statix deadnix];
    };

    formatter.${system} = pkgs.alejandra;
  };
}
