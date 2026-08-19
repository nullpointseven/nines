{inputs, ...}: {
  nixpkgs = {
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "electron-39.8.10"
      ];
    };
    overlays = [
      (import ../../overlays {inherit inputs;})
    ];
  };

  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      flake-registry = "";
    };
  };

  time.timeZone = "Asia/Manila";

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

  environment.variables.EDITOR = "nvim";

  system.stateVersion = "26.05";
}
