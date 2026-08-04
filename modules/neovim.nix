_: {
  modules.homeManager.shared = {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
      withRuby = false;
      withPython3 = false;
    };
  };
}
