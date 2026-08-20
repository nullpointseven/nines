{
  lib,
  config,
  ...
}: let
  cfg = config.my.power;
in {
  options.my.power = {
    enable = lib.mkEnableOption "laptop power management and lid-switch handling";
  };

  config = lib.mkIf cfg.enable {
    services.tlp = {
      enable = true;
      settings = {
        START_CHARGE_THRESH_BAT0 = 40;
        STOP_CHARGE_THRESH_BAT0 = 80;
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      };
    };

    services.power-profiles-daemon.enable = lib.mkForce false;

    services.logind.settings.Login = {
      HandleLidSwitch = "ignore";
      HandleLidSwitchExternalPower = "ignore";
      HandleLidSwitchDocked = "ignore";
    };

    services.thermald.enable = true;
  };
}
