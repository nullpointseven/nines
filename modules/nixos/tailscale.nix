{
  lib,
  config,
  ...
}: let
  cfg = config.my.tailscale;
in {
  options.my.tailscale = {
    enable = lib.mkEnableOption "Tailscale mesh VPN";
    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing the Tailscale auth key.
        Usually provided by sops-nix as `config.sops.secrets.tailscale-authkey.path`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale =
      {
        enable = true;
      }
      // lib.optionalAttrs (cfg.authKeyFile != null) {
        authKeyFile = cfg.authKeyFile;
      };
  };
}
