{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.my.networkMount;
in {
  options.my.networkMount = {
    enable = lib.mkEnableOption "automatic network mount for a NAS";
    mountPoint = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/nas";
      description = "Local mount point for the NAS share";
    };
    device = lib.mkOption {
      type = lib.types.str;
      default = "//192.168.1.100/data";
      description = "Remote share path (e.g. //nas/share)";
    };
    fsType = lib.mkOption {
      type = lib.types.str;
      default = "cifs";
      description = "Filesystem type (usually cifs or nfs)";
    };
    credentialsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a credentials file (e.g. from sops-nix).
        For CIFS this should contain `username=...` and `password=...` lines.
      '';
    };
    uid = lib.mkOption {
      type = lib.types.str;
      default = "1000";
      description = "UID to map the mounted files to";
    };
    gid = lib.mkOption {
      type = lib.types.str;
      default = "100";
      description = "GID to map the mounted files to";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [cfg.fsType];

    environment.systemPackages = with pkgs; [
      cifs-utils
      nfs-utils
    ];

    fileSystems.${cfg.mountPoint} = {
      device = cfg.device;
      fsType = cfg.fsType;
      options = let
        automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
        net_opts = "_netdev";
        creds = lib.optionalString (cfg.credentialsFile != null) ",credentials=${toString cfg.credentialsFile}";
      in [
        "${automount_opts},${net_opts},uid=${cfg.uid},gid=${cfg.gid},file_mode=0644,dir_mode=0755${creds}"
      ];
    };
  };
}
