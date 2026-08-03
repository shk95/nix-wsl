{lib, ...}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    completionInit = ''
      autoload -Uz compinit
      compinit
    '';

    initContent = lib.mkOrder 1000 "zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'";
  };
}
