{config, ...}: let
  link = config.lib.file.mkOutOfStoreSymlink;
  nvimConfigPath = "${config.home.homeDirectory}/.config/nixos/dotfiles/nvim-config";
in {
  xdg.configFile = {
    "nvim" = {
      source = link nvimConfigPath;
      recursive = true;
      force = true;
    };
  };
}
