{user, ...}: {
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
    enableDefaultConfig = false;

    matchBlocks.local = {
      hostname = "localhost";
      identityFile = "~/.ssh/id_ed25519";
      inherit user;
    };
  };
}
