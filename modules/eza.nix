_: {
  # a modern replacement for `ls`
  modules.homeManager.shared = {
    programs.eza = {
      enable = true;
      git = true;
      icons = "auto";
      enableZshIntegration = true;
    };
  };
}
