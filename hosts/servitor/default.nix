{inputs, ...}: {
  imports = [
    ./hardware-configuration.nix
    inputs.disko.nixosModules.disko
    ./disk-config.nix
    inputs.sops-nix.nixosModules.sops
    ./secrets.nix
    ../../modules/nixos
  ];

  networking.hostName = "servitor";

  my = {
    docker.enable = true;
    tailscale.enable = true;
    power.enable = true;
    intel.enable = true;
    networkMount = {
      enable = true;
      device = "192.168.1.100:/data";
      fsType = "nfs";
    };
  };

  services.openssh = {
    enable = true;
    openFirewall = false;
  };

  users.users.zero.extraGroups = ["networkmanager"];
}
