{
  lib,
  config,
  ...
}: let
  cfg = config.my.docker;
in {
  options.my.docker = {
    enable = lib.mkEnableOption "Docker container runtime";
    user = lib.mkOption {
      type = lib.types.str;
      default = "zero";
      description = "User to add to the docker group";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true;

    users.users.${cfg.user} = {
      extraGroups = ["docker"];
    };
  };
}
