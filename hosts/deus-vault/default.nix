{
  inputs,
  myLib,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    inputs.disko.nixosModules.disko
    ./disk-config.nix
    inputs.home-manager.nixosModules.home-manager
    ../../modules/nixos
  ];

  networking.hostName = "deus-vault";

  # The disk layout (disk-config.nix) uses GPT/MBR with EF02 partitions and
  # GRUB, not the EFI systemd-boot default from modules/nixos/boot.nix.
  # GRUB devices are derived from the disk config by the disko module.
  boot.loader = {
    systemd-boot.enable = false;
    grub.enable = true;
  };

  # disko enables boot.swraid for the mdadm array; mdadm requires a
  # MAILADDR or PROGRAM in /etc/mdadm.conf or the mdmon service crashes.
  # PROGRAM /bin/true is a no-op alert handler (no mail setup needed).
  boot.swraid.mdadmConf = "PROGRAM /bin/true";

  my = {
    docker.enable = true;
    tailscale = {
      enable = true;
      useNftables = true;
    };
    power.enable = true;
    intel.enable = true;
  };

  services.openssh = {
    enable = true;
    openFirewall = false;
  };

  users.users.zero.extraGroups = ["networkmanager"];
}
