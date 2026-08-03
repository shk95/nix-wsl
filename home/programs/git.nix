{
  lib,
  gitname,
  gitmail,
  ...
}: {
  # `programs.git` generates ~/.config/git/config; for it to take effect,
  # ~/.gitconfig must not exist (git prefers it over the XDG path).
  home.activation.removeExistingGitconfig = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    rm -f ~/.gitconfig
  '';

  programs = {
    git = {
      enable = true;
      lfs.enable = false;

      ignores = [
        ".direnv"
        ".envrc"
        "*.pem"
      ];

      settings = {
        user = {
          name = gitname;
          email = gitmail;
        };

        init.defaultBranch = "master";
        push.autoSetupRemote = true;
        pull.rebase = true;
        log.date = "iso";

        aliases = {
          br = "branch";
          co = "checkout";
          st = "status";
          ls = ''log --pretty=format:"%C(yellow)%h%Cred%d\\ %Creset%s%Cblue\\ [%cn]" --decorate'';
          cm = "commit -m";
          ca = "commit -am";
          dc = "diff --cached";
          amend = "commit --amend -m";
        };
      };
    };

    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        line-numbers = true;
        true-color = "always";
      };
    };
  };
}
