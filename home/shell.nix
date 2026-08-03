{lib, ...}: {
  # The login shell moves from bash to zsh with M2. Everything below was in an
  # unmanaged ~/.bashrc, which home-manager does not touch — so nothing would
  # have carried over on its own, and the switch would have looked like the
  # environment regressing rather than moving.
  home.sessionVariables = {
    # The system default is C.UTF-8 (/etc/default/locale); en_US.UTF-8 was set
    # per-shell in ~/.bashrc. Declared here so it does not depend on which
    # shell happens to start.
    #
    # No LOCALE_ARCHIVE. The usual advice on a non-NixOS host is to pin
    # pkgs.glibcLocales, but it is not needed here: nix's glibc falls back to
    # /usr/lib/locale/locale-archive, which Ubuntu generates with en_US.UTF-8
    # in it. Verified by strace, and by `locale charmap` returning UTF-8 rather
    # than ANSI_X3.4-1968 — the latter is the symptom if this ever stops
    # holding, and pinning glibcLocales is the fix at that point.
    LANG = "en_US.UTF-8";
  };

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

      # ~/.zshrc sourced ~/.local/bin/env, and that was the only thing putting
      # this directory on PATH — but home-manager takes ~/.zshrc over, so
      # without this, activation silently removes claude, uv and uvx.
      #
      # Not home.sessionPath, which prepends:
      #   export PATH="$HOME/.local/bin''${PATH:+:}$PATH"
      # The directory holds standalone installers' output that overlaps what
      # packages.nix declares (bat), and the declared one should win. Appending
      # keeps that order while still resolving what lives only here.
      #
      # `typeset -U path` also fixes a pre-existing duplicate: the directory
      # appeared twice in PATH under bash.
      typeset -U path
      path+=("$HOME/.local/bin")
      path+=("$HOME/.opencode/bin")

      # Bridges to imperative installers, carried over from ~/.bashrc. Nix does
      # not manage any of these — they keep their own state directories and
      # update themselves — so what belongs here is only the hook that makes
      # them reachable, guarded so a shell still starts if one is uninstalled.
      #
      # conda: ~/.condarc sets auto_activate false, so this exposes the command
      # without putting base on PATH.
      if [ -x "$HOME/miniconda3/bin/conda" ]; then
        __conda_setup="$("$HOME/miniconda3/bin/conda" 'shell.zsh' 'hook' 2>/dev/null)"
        if [ $? -eq 0 ]; then
          eval "$__conda_setup"
        elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
          . "$HOME/miniconda3/etc/profile.d/conda.sh"
        fi
        unset __conda_setup
      fi

      # Interactive shells only. Without the guard the banner is written into
      # the stream used by scp, sftp and `ssh host <cmd>`, corrupting them.
      case $- in
        *i*) [ -t 1 ] && [ -x "$HOME/.local/bin/sysmetrics" ] && "$HOME/.local/bin/sysmetrics" ;;
      esac

      # SDKMAN insists on being last; it rewrites PATH and expects to win.
      export SDKMAN_DIR="$HOME/.sdkman"
      [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"
    '';
  };
}
