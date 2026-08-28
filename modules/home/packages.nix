{
  inputs,
  pkgs,
  ...
}: let
  logseq-patch = pkgs.logseq.override {
	electron_27 = pkgs.electron_39;
  };
in {
  home.packages = with pkgs; [
    darktable
    rawtherapee
    vesktop
    libreoffice
    tmux
	logseq-patch
    lua
    luarocks
    mpv
    unzip
    python3
    brightnessctl
    playerctl
    waybar
    copyq
    zathura
    qimgv
    slurp
    grim
    wl-clipboard
    joplin-desktop
    inputs.freesmlauncher.packages."x86_64-linux".freesmlauncher
  ];
}
