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

    useNftables = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use the nftables backend for Tailscale instead of iptables.";
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

    networking.nftables.enable = cfg.useNftables;

    systemd.services.tailscaled.serviceConfig.Environment = lib.mkIf cfg.useNftables [
      "TS_DEBUG_FIREWALL_MODE=nftables"
    ];

    networking.firewall = lib.mkIf (cfg.useNftables && config.networking.firewall.enable) {
      allowedUDPPorts = [config.services.tailscale.port];
      trustedInterfaces = [config.services.tailscale.interfaceName];
    };
  };
}
