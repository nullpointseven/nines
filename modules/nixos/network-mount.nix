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
      default = "192.168.1.100:/data";
      description = "Remote share path (e.g. //nas/share for CIFS or nas:/export for NFS)";
    };
    fsType = lib.mkOption {
      type = lib.types.str;
      default = "nfs";
      description = "Filesystem type (cifs or nfs)";
    };
    credentialsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a credentials file (e.g. from sops-nix).
        Only used for CIFS; it should contain `username=...` and `password=...` lines.
      '';
    };
    uid = lib.mkOption {
      type = lib.types.str;
      default = "1000";
      description = "UID to map CIFS files to";
    };
    gid = lib.mkOption {
      type = lib.types.str;
      default = "100";
      description = "GID to map CIFS files to";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [cfg.fsType];

    environment.systemPackages = with pkgs;
      [
      ]
      ++ lib.optional (cfg.fsType == "cifs") cifs-utils
      ++ lib.optional (cfg.fsType == "nfs") nfs-utils;

    fileSystems.${cfg.mountPoint} = {
      device = cfg.device;
      fsType = cfg.fsType;
      options = let
        isCifs = cfg.fsType == "cifs";
        isNfs = cfg.fsType == "nfs";
      in
        lib.flatten [
          [
            "x-systemd.automount"
            "noauto"
            "x-systemd.idle-timeout=60"
            "x-systemd.device-timeout=5s"
            "x-systemd.mount-timeout=5s"
            "_netdev"
          ]
          (lib.optionals isCifs [
            "uid=${cfg.uid}"
            "gid=${cfg.gid}"
            "file_mode=0644"
            "dir_mode=0755"
          ])
          (lib.optional (isCifs && cfg.credentialsFile != null) "credentials=${toString cfg.credentialsFile}")
          (lib.optionals isNfs [
            "soft"
            "nofail"
          ])
        ];
    };
  };
}
