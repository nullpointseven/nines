{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.my.intel;
in {
  options.my.intel = {
    enable = lib.mkEnableOption "Intel CPU and iGPU optimizations";
  };

  config = lib.mkIf cfg.enable {
    hardware.cpu.intel.updateMicrocode = true;

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-vaapi-driver
      ];
    };

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    };

    boot.kernelModules = ["i915"];
    boot.kernelParams = ["i915.enable_guc=3"];
  };
}
