{...}: {
  users.users.zero = {
    initialPassword = "password";
    isNormalUser = true;
    extraGroups = ["wheel" "dialout" "cdrom" "docker" "input" "uinput"];
  };
}
