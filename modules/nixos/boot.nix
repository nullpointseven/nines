{lib, ...}: {
  # Default to systemd-boot (EFI); hosts can override (e.g. deus-vault uses
  # GRUB on MBR disks).
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
}
