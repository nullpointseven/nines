{
  # Add secrets here once the host has an age/ssh key:
  # sops.secrets.nas-credentials = {};
  # sops.secrets.tailscale-authkey = {};

  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
}
