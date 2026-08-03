{lib, ...}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    completionInit = ''
      autoload -Uz compinit
      compinit
    '';

    initContent = lib.mkOrder 1000 ''
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

      # ~/.zshrc sources ~/.local/bin/env today, and that is the only thing
      # putting this directory on PATH — but home-manager takes ~/.zshrc over,
      # so without this, activation silently removes claude, uv and uvx.
      #
      # Not home.sessionPath, which prepends:
      #   export PATH="$HOME/.local/bin''${PATH:+:}$PATH"
      # The directory holds standalone installers' output that overlaps what
      # packages.nix declares (bat), and the declared one should win. Appending
      # keeps that order while still resolving what lives only here.
      typeset -U path
      path+=("$HOME/.local/bin")
    '';
  };
}
