{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    appimage-run
    docker
    ethtool
    exfat
    pciutils
    strace
    ltrace
    lsof
    sysstat
    usbutils
    udiskie
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
