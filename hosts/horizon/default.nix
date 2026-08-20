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

  networking.hostName = "horizon";

  my.desktop.enable = true;
  my.tailscale = {
    enable = true;
    useNftables = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {inherit inputs myLib;};
    backupFileExtension = "bak";
    users.zero = import ../../home-manager/home.nix;
  };
}
