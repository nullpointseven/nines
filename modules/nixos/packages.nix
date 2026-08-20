{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    docker
    ethtool
    pciutils
    strace
    ltrace
    lsof
    sysstat
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
    neovim
  ];
}
