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

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    homeConfigurations.${user} = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = {inherit user gitname gitmail;};
      modules = [./home];
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
        ./system
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
