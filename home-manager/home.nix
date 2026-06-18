# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)
{
  inputs,
  lib,
  config,
  pkgs,
  system,
  ...
}: {
  # You can import other home-manager modules here
  imports = [
    # You can also split up your configuration and import pieces of it here:
    ./apps
  ];

  nixpkgs = {
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  home = {
    username = "zero";
    homeDirectory = "/home/zero";
  };

  # Add stuff for your user as you see fit:
  home.packages = with pkgs; [
    darktable
    rawtherapee
    vesktop
    libreoffice
    tmux
    lua
    luarocks
    unzip
    python3
    brightnessctl
    playerctl
    waybar
    copyq
    joplin-desktop
    inputs.freesmlauncher.packages."x86_64-linux".freesmlauncher
  ];

  # Enable home-manager and git
  programs = {
    home-manager.enable = true;
    git = {
      enable = true;
      settings = {
        user = {
          name = "nullpointseven";
          email = "82100519+nullpointseven@users.noreply.github.com";
        };
      };
      aliases = {
        ci = "commit";
        co = "checkout";
        s = "status";
      };
    };
  };

  services.mpris-proxy.enable = true;
  services.udiskie = {
    enable = true;
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "26.05";
}
