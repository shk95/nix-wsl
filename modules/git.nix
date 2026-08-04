{config, ...}: let
  inherit (config.identity) gitName gitEmail;
in {
  modules.homeManager.shared = {lib, ...}: {
    # `programs.git` generates ~/.config/git/config; for it to take effect,
    # ~/.gitconfig must not exist (git reads both, and the later one wins).
    #
    # Moved rather than deleted. home-manager refuses to clobber unmanaged files
    # everywhere else, and this activation script is the one place that escapes
    # that rule — the file it removes is exactly the kind nobody has a copy of.
    # The inventory before M2 found a gh credential helper in it that nothing
    # here reproduced; the next surprise will not be caught by reading.
    home.activation.backupExistingGitconfig = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      if [ -e "$HOME/.gitconfig" ]; then
        backup="$HOME/.gitconfig.before-home-manager.$(date +%Y%m%d%H%M%S)"
        run mv $VERBOSE_ARG "$HOME/.gitconfig" "$backup"
        echo "Moved an unmanaged ~/.gitconfig to $backup"
      fi
    '';

    programs = {
      git = {
        enable = true;
        lfs.enable = false;

        ignores = [
          ".direnv"
          ".envrc"
          "*.pem"

          # Carried over from an unmanaged ~/.config/git/ignore, which
          # programs.git generates and would otherwise have replaced wholesale.
          "**/.claude/settings.local.json"
          "**/.claude/.cc-writes/"
        ];

        settings = {
          user = {
            name = gitName;
            email = gitEmail;
          };

          # Carried over from the unmanaged ~/.gitconfig this replaces: without
          # it git escapes non-ASCII paths as octal in status and diff output.
          core.quotepath = false;

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
  };
}
