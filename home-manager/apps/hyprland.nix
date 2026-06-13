{config, ...}: let
  link = config.lib.file.mkOutOfStoreSymlink;
  hyprlandConfigPath = "${config.home.homeDirectory}/.config/nixos/dotfiles/hypr";
in {
  xdg.configFile = {
    "hypr" = {
      source = link hyprlandConfigPath;
      recursive = true;
      force = true;
    };
  };
}
