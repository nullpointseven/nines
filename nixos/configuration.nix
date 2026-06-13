# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix

    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    users = {
      zero = import ../home-manager/home.nix;
    };
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      flake-registry = "";
    };
  };

  networking = {
    hostName = "horizon";
    networkmanager.enable = true;
  };

  users.users = {
    zero = {
      initialPassword = "password";
      isNormalUser = true;
      extraGroups = ["wheel" "dialout" "cdrom" "docker" "input" "uinput"];
    };
  };

  services.openssh = {
    enable = true;

    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
  };

  # Set your time zone.
  time.timeZone = "Asia/Manila";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Configure keymap in X11
  services.xserver.xkb.layout = "us";
  services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  networking.firewall.enable = false;

  environment.variables.EDITOR = "nvim";

  environment.systemPackages = with pkgs; [
    hyprland
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
    (pkgs.wrapFirefox (pkgs.firefox-unwrapped.override {pipewireSupport = true;}) {})
    xdg-user-dirs
    xz
    p7zip
    btop
    ripgrep
    fastfetch
    gawk
    wofi
    waybar
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

    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  services.blueman.enable = true;
  services.udisks2.enable = true;
  services.xserver = {
    displayManager.lightdm.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [xdg-desktop-portal-hyprland];
  };

  hardware.amdgpu.opencl.enable = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  hardware.bluetooth.settings = {
    General = {
      Experimental = true;
    };
  };

  fonts.packages = [pkgs.nerd-fonts.jetbrains-mono];

  system.stateVersion = "26.05";
}
