{config, ...}: let
  inherit (config.identity) user;
in {
  modules.homeManager.shared = {
    # Carried over from an unmanaged ~/.ssh/config, which held one host alias.
    #
    # Enabling this makes home-manager own ~/.ssh/config — it does *not* touch
    # keys, known_hosts or authorized_keys, which stay where they are and stay
    # unmanaged. That split is deliberate: the config is declarative, the key
    # material is not something this repository should ever hold.
    programs.ssh = {
      enable = true;

      # Without this, home-manager writes a `Host *` block of its own defaults,
      # and a user config is read before /etc/ssh/ssh_config with first match
      # winning — so those defaults silently replace Ubuntu's. One of them is
      # real: Ubuntu sets HashKnownHosts yes and this host's known_hosts is
      # already hashed, so the block would start appending unhashed entries to a
      # hashed file. Declaring one host alias should not change how ssh behaves
      # everywhere else.
      #
      # home-manager documents this option as heading for deprecation; when it
      # goes, the replacement is to declare settings."*" explicitly rather than
      # to accept the block.
      enableDefaultConfig = false;

      # `settings` rather than `matchBlocks`, which is deprecated and warns on
      # every activation. The keys are upstream OpenSSH directive names, not the
      # camelCase the old option used.
      settings.local = {
        HostName = "localhost";
        User = user;
        IdentityFile = "~/.ssh/id_ed25519";
      };
    };
  };
}
