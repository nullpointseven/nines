# Evaluation tests for the custom NixOS modules under modules/nixos.
#
# Each case evaluates the module under test against the full NixOS option set
# (`_module.check` is enabled, so setting undeclared options is an error) and
# asserts on the resulting `config`.
{
  pkgs,
  lib ? pkgs.lib,
  ...
}: let
  helpers = import ./lib.nix {inherit pkgs lib;};
  evalNixOS = helpers.evalNixOS;
  runUnitTests = helpers.runUnitTests;
  testThrows = helpers.testThrows;

  docker = import ../modules/nixos/docker.nix;
  tailscale = import ../modules/nixos/tailscale.nix;
  networkMount = import ../modules/nixos/network-mount.nix;
  intel = import ../modules/nixos/intel.nix;
  power = import ../modules/nixos/power.nix;
  desktop = import ../modules/nixos/desktop.nix;
  # modules that pull in pkgs.allowUnfree etc. are built with the same pkgs
  # the flake uses (allowUnfree = true), so desktop/steam tests work.
in
  runUnitTests "module-eval" {
    # ------------------------------------------------------------------
    # my.docker
    # ------------------------------------------------------------------
    testDockerDisabledByDefault = {
      expr = (evalNixOS [docker]).config.virtualisation.docker.enable;
      expected = false;
    };

    testDockerDisabledAddsNoDockerGroupMembers = {
      expr = let
        cfg = (evalNixOS [docker]).config;
        withDockerGroup = lib.filterAttrs (_: u: builtins.elem "docker" (u.extraGroups or [])) cfg.users.users;
      in
        builtins.attrNames withDockerGroup;
      expected = [];
    };

    testDockerEnableTurnsOnVirtualisation = {
      expr = (evalNixOS [docker {my.docker.enable = true;}]).config.virtualisation.docker.enable;
      expected = true;
    };

    testDockerAddsDefaultUserToDockerGroup = {
      expr = (evalNixOS [docker {my.docker.enable = true;}]).config.users.users.zero.extraGroups;
      expected = ["docker"];
    };

    testDockerCustomUserIsAddedToDockerGroup = {
      expr =
        (evalNixOS [
          docker
          {
            my.docker = {
              enable = true;
              user = "alice";
            };
          }
        ]).config.users.users.alice.extraGroups;
      expected = ["docker"];
    };

    testDockerCustomUserKeepsDefaultUserOutOfGroup = {
      expr = let
        cfg =
          (evalNixOS [
            docker
            {
              my.docker = {
                enable = true;
                user = "alice";
              };
            }
          ]).config;
        withDockerGroup = lib.filterAttrs (_: u: builtins.elem "docker" (u.extraGroups or [])) cfg.users.users;
      in
        builtins.attrNames withDockerGroup;
      expected = ["alice"];
    };

    testDockerRejectsNonStringUser = testThrows (
      builtins.seq (evalNixOS [docker {my.docker.user = 42;}]).config.my.docker.user "no error"
    );

    testDockerRejectsUndeclaredOption = testThrows (
      builtins.seq (evalNixOS [docker {my.dockerr.enable = true;}]).config.system.stateVersion "no error"
    );

    # ------------------------------------------------------------------
    # my.tailscale
    # ------------------------------------------------------------------
    testTailscaleDisabledByDefault = {
      expr = (evalNixOS [tailscale]).config.services.tailscale.enable;
      expected = false;
    };

    testTailscaleEnableTurnsOnService = {
      expr = (evalNixOS [tailscale {my.tailscale.enable = true;}]).config.services.tailscale.enable;
      expected = true;
    };

    testTailscaleWithoutAuthKeyDoesNotSetAuthKeyFile = {
      expr = (evalNixOS [tailscale {my.tailscale.enable = true;}]).config.services.tailscale.authKeyFile or null;
      expected = null;
    };

    testTailscaleWithAuthKeySetsAuthKeyFile = {
      expr =
        (evalNixOS [
          tailscale
          {
            my.tailscale = {
              enable = true;
              authKeyFile = "/run/secrets/tailscale-key";
            };
          }
        ]).config.services.tailscale.authKeyFile;
      expected = "/run/secrets/tailscale-key";
    };

    testTailscaleDefaultsToIptablesBackend = {
      expr = (evalNixOS [tailscale {my.tailscale.enable = true;}]).config.networking.nftables.enable;
      expected = false;
    };

    testTailscaleNftablesBackendEnablesNftables = {
      expr =
        (evalNixOS [
          tailscale
          {
            my.tailscale = {
              enable = true;
              useNftables = true;
            };
          }
        ]).config.networking.nftables.enable;
      expected = true;
    };

    testTailscaleNftablesBackendSetsDebugEnv = {
      expr = let
        env =
          (evalNixOS [
            tailscale
            {
              my.tailscale = {
                enable = true;
                useNftables = true;
              };
            }
          ]).config.systemd.services.tailscaled.serviceConfig.Environment;
      in
        builtins.elem "TS_DEBUG_FIREWALL_MODE=nftables" env;
      expected = true;
    };

    testTailscaleNftablesOpensFirewallPort = let
      cfg =
        (evalNixOS [
          tailscale
          {
            my.tailscale = {
              enable = true;
              useNftables = true;
            };
          }
        ]).config;
    in {
      expr = {
        udp = builtins.elem cfg.services.tailscale.port cfg.networking.firewall.allowedUDPPorts;
        trusted = builtins.elem cfg.services.tailscale.interfaceName cfg.networking.firewall.trustedInterfaces;
      };
      expected = {
        udp = true;
        trusted = true;
      };
    };

    testTailscaleRejectsNonBoolNftablesFlag = testThrows (
      builtins.seq
      (evalNixOS [
        tailscale
        {
          my.tailscale = {
            enable = true;
            useNftables = "yes";
          };
        }
      ]).config.my.tailscale.useNftables "no error"
    );

    # ------------------------------------------------------------------
    # my.networkMount
    # ------------------------------------------------------------------
    testNetworkMountDisabledByDefault = {
      expr = (evalNixOS [networkMount]).config ? fileSystems."/mnt/nas";
      expected = false;
    };

    testNetworkMountDefaults = {
      expr = let
        cfg = (evalNixOS [networkMount {my.networkMount.enable = true;}]).config.my.networkMount;
      in {
        inherit (cfg) mountPoint device fsType uid gid;
        credentialsFile = cfg.credentialsFile == null;
      };
      expected = {
        mountPoint = "/mnt/nas";
        device = "192.168.1.100:/data";
        fsType = "nfs";
        uid = "1000";
        gid = "100";
        credentialsFile = true;
      };
    };

    testNetworkMountAddsFileSystem = {
      expr = (evalNixOS [networkMount {my.networkMount.enable = true;}]).config.fileSystems."/mnt/nas".fsType;
      expected = "nfs";
    };

    testNetworkMountAddsAutomountOptions = {
      expr = (evalNixOS [networkMount {my.networkMount.enable = true;}]).config.fileSystems."/mnt/nas".options;
      expected = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=60"
        "x-systemd.device-timeout=5s"
        "x-systemd.mount-timeout=5s"
        "_netdev"
        "soft"
        "nofail"
      ];
    };

    testNetworkMountCifsAddsUidGidOptions = {
      expr = let
        cfg =
          (evalNixOS [
            networkMount
            {
              my.networkMount = {
                enable = true;
                fsType = "cifs";
              };
            }
          ]).config;
      in
        cfg.fileSystems."/mnt/nas".options;
      expected = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=60"
        "x-systemd.device-timeout=5s"
        "x-systemd.mount-timeout=5s"
        "_netdev"
        "uid=1000"
        "gid=100"
        "file_mode=0644"
        "dir_mode=0755"
      ];
    };

    testNetworkMountCifsAddsCredentialsOption = {
      expr = let
        cfg =
          (evalNixOS [
            networkMount
            {
              my.networkMount = {
                enable = true;
                fsType = "cifs";
                credentialsFile = "/run/secrets/nas";
              };
            }
          ]).config;
      in
        cfg.fileSystems."/mnt/nas".options;
      expected = [
        "x-systemd.automount"
        "noauto"
        "x-systemd.idle-timeout=60"
        "x-systemd.device-timeout=5s"
        "x-systemd.mount-timeout=5s"
        "_netdev"
        "uid=1000"
        "gid=100"
        "file_mode=0644"
        "dir_mode=0755"
        "credentials=/run/secrets/nas"
      ];
    };

    testNetworkMountCifsDoesNotAddCredentialsWhenUnset = {
      expr = let
        cfg =
          (evalNixOS [
            networkMount
            {
              my.networkMount = {
                enable = true;
                fsType = "cifs";
              };
            }
          ]).config;
      in
        lib.lists.any (opt: lib.strings.hasPrefix "credentials=" opt) cfg.fileSystems."/mnt/nas".options;
      expected = false;
    };

    testNetworkMountAddsFsUtilsToSystemPackages = {
      expr = let
        cfg = (evalNixOS [networkMount {my.networkMount.enable = true;}]).config;
        names = builtins.map (p: p.pname or p.name or "") cfg.environment.systemPackages;
      in
        builtins.elem "nfs-utils" names;
      expected = true;
    };

    testNetworkMountCifsAddsCifsUtilsToSystemPackages = {
      expr = let
        cfg =
          (evalNixOS [
            networkMount
            {
              my.networkMount = {
                enable = true;
                fsType = "cifs";
              };
            }
          ]).config;
        names = builtins.map (p: p.pname or p.name or "") cfg.environment.systemPackages;
      in
        builtins.elem "cifs-utils" names;
      expected = true;
    };

    testNetworkMountAddsSupportedFilesystem = {
      expr = (evalNixOS [networkMount {my.networkMount.enable = true;}]).config.boot.supportedFilesystems.nfs or false;
      expected = true;
    };

    testNetworkMountCustomMountPoint = {
      expr =
        (evalNixOS [
          networkMount
          {
            my.networkMount = {
              enable = true;
              mountPoint = "/mnt/media";
            };
          }
        ]).config ? fileSystems."/mnt/media";
      expected = true;
    };

    testNetworkMountRejectsNonStringMountPoint = testThrows (
      builtins.seq
      (evalNixOS [
        networkMount
        {
          my.networkMount = {
            enable = true;
            mountPoint = 42;
          };
        }
      ]).config.my.networkMount.mountPoint "no error"
    );

    # ------------------------------------------------------------------
    # my.intel
    # ------------------------------------------------------------------
    testIntelDisabledByDefault = {
      expr = (evalNixOS [intel]).config.hardware.cpu.intel.updateMicrocode;
      expected = false;
    };

    testIntelEnableUpdatesMicrocode = {
      expr = (evalNixOS [intel {my.intel.enable = true;}]).config.hardware.cpu.intel.updateMicrocode;
      expected = true;
    };

    testIntelEnableAddsGraphicsPackages = {
      expr = let
        cfg = (evalNixOS [intel {my.intel.enable = true;}]).config;
      in
        builtins.map (p: p.pname or p.name or "") cfg.hardware.graphics.extraPackages;
      expected = ["intel-media-driver" "intel-vaapi-driver"];
    };

    testIntelEnableSetsVaDriver = {
      expr = (evalNixOS [intel {my.intel.enable = true;}]).config.environment.sessionVariables.LIBVA_DRIVER_NAME;
      expected = "iHD";
    };

    testIntelEnableLoadsKernelModule = {
      expr = let
        cfg = (evalNixOS [intel {my.intel.enable = true;}]).config;
      in
        builtins.elem "i915" cfg.boot.kernelModules;
      expected = true;
    };

    testIntelEnableSetsKernelParams = {
      expr = let
        cfg = (evalNixOS [intel {my.intel.enable = true;}]).config;
      in
        builtins.elem "i915.enable_guc=3" cfg.boot.kernelParams;
      expected = true;
    };

    testIntelRejectsNonBoolEnable = testThrows (
      builtins.seq (evalNixOS [intel {my.intel.enable = "yes";}]).config.my.intel.enable "no error"
    );

    # ------------------------------------------------------------------
    # my.power
    # ------------------------------------------------------------------
    testPowerDisabledByDefault = {
      expr = (evalNixOS [power]).config.services.tlp.enable;
      expected = false;
    };

    testPowerEnableTurnsOnTlp = {
      expr = (evalNixOS [power {my.power.enable = true;}]).config.services.tlp.enable;
      expected = true;
    };

    testPowerEnableSetsChargeThresholds = {
      expr = (evalNixOS [power {my.power.enable = true;}]).config.services.tlp.settings;
      expected = {
        START_CHARGE_THRESH_BAT0 = 40;
        STOP_CHARGE_THRESH_BAT0 = 80;
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      };
    };

    testPowerEnableDisablesPowerProfilesDaemon = {
      expr = (evalNixOS [power {my.power.enable = true;}]).config.services.power-profiles-daemon.enable;
      expected = false;
    };

    testPowerEnableIgnoresLidSwitch = {
      expr = let
        login = (evalNixOS [power {my.power.enable = true;}]).config.services.logind.settings.Login;
      in {
        HandleLidSwitch = login.HandleLidSwitch;
        HandleLidSwitchExternalPower = login.HandleLidSwitchExternalPower;
        HandleLidSwitchDocked = login.HandleLidSwitchDocked;
      };
      expected = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchExternalPower = "ignore";
        HandleLidSwitchDocked = "ignore";
      };
    };

    testPowerEnableTurnsOnThermald = {
      expr = (evalNixOS [power {my.power.enable = true;}]).config.services.thermald.enable;
      expected = true;
    };

    # ------------------------------------------------------------------
    # my.desktop
    # ------------------------------------------------------------------
    testDesktopDisabledByDefault = {
      expr = (evalNixOS [desktop]).config.programs.hyprland.enable;
      expected = false;
    };

    testDesktopEnableTurnsOnHyprland = {
      expr = (evalNixOS [desktop {my.desktop.enable = true;}]).config.programs.hyprland.enable;
      expected = true;
    };

    testDesktopEnableTurnsOnXServer = {
      expr = (evalNixOS [desktop {my.desktop.enable = true;}]).config.services.xserver.enable;
      expected = true;
    };

    testDesktopEnableTurnsOnLightdm = {
      expr = (evalNixOS [desktop {my.desktop.enable = true;}]).config.services.xserver.displayManager.lightdm.enable;
      expected = true;
    };

    testDesktopEnableSetsXkbLayout = {
      expr = (evalNixOS [desktop {my.desktop.enable = true;}]).config.services.xserver.xkb.layout;
      expected = "us";
    };

    testDesktopEnableTurnsOnInputMethod = {
      expr = (evalNixOS [desktop {my.desktop.enable = true;}]).config.i18n.inputMethod.type;
      expected = "fcitx5";
    };

    testDesktopEnableTurnsOnPortals = {
      expr = (evalNixOS [desktop {my.desktop.enable = true;}]).config.xdg.portal.enable;
      expected = true;
    };

    testDesktopEnableTurnsOnSteam = {
      expr = (evalNixOS [desktop {my.desktop.enable = true;}]).config.programs.steam.enable;
      expected = true;
    };
  }
