{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.my.desktop;
in {
  options.my.desktop.enable = lib.mkEnableOption "desktop environment (Hyprland, X, Steam, etc.)";

  config = lib.mkIf cfg.enable {
    services.xserver = {
      enable = true;
      xkb.layout = "us";
      xkb.options = "eurosign:e,caps:escape";
      displayManager.lightdm.enable = true;
    };

    programs.hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };

    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = with pkgs; [
        fcitx5-mozc
        fcitx5-gtk
      ];
    };

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gnome
        xdg-desktop-portal-gtk
      ];
      config = {
        common.default = ["*"];
        hyprland.default = ["gtk" "hyprland"];
      };
      xdgOpenUsePortal = true;
    };

    fonts.packages = [pkgs.nerd-fonts.jetbrains-mono];

    environment.systemPackages = with pkgs; [
      hypridle
      hyprlock
      wofi
      kitty
      thunar
      nnn
      kanata
    ];

    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      extraCompatPackages = with pkgs; [proton-ge-bin];
    };
  };
}
