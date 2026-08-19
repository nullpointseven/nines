{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    docker
    hypridle
    hyprlock
    ethtool
    pciutils
    strace
    ltrace
    lsof
    sysstat
    kanata
    usbutils
    udisks2
    lm_sensors
    wget
    tlp
    xdg-user-dirs
    xz
    p7zip
    btop
    ripgrep
    fastfetch
    gawk
    wofi
    kitty
    neovim
    thunar
    nnn
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = with pkgs; [proton-ge-bin];
  };
}
