{
  description = "Reproducible dev environment for WSL, managed by Nix + standalone home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    home-manager,
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

    # `nix develop` gives you a shell with everything needed to edit this flake
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [alejandra nixd statix deadnix];
    };

    formatter.${system} = pkgs.alejandra;
  };
}
