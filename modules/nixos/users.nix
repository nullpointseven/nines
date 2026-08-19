{...}: {
  users.users.zero = {
    initialPassword = "password";
    isNormalUser = true;
    extraGroups = ["wheel" "dialout" "cdrom" "docker" "input" "uinput"];
  };

  system.activationScripts.dotfilesPermissions = {
    deps = ["users"];
    text = ''
      if [ -d /home/zero/.config/nixos/dotfiles ]; then
        chown -R zero:users /home/zero/.config/nixos/dotfiles
        chmod -R u+w /home/zero/.config/nixos/dotfiles
      fi
    '';
  };
}
