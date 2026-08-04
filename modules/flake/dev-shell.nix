# `nix develop` gives a shell for editing this flake without activating
# anything. `just` is in here as well as in the declared packages, so the command
# runner is available on a machine where nothing has been switched yet — which is
# what the README's setup path depends on.
_: {
  perSystem = {pkgs, ...}: {
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [just alejandra nixd statix deadnix];
    };

    formatter = pkgs.alejandra;
  };
}
