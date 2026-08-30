# Regression checks for the real host configurations in hosts/.
#
# These force a curated set of options on each `nixosConfiguration` to make
# sure the host modules still wire together (options exist, imports resolve,
# custom `my.*` modules are enabled as intended). They do not build the
# system closure, so they stay fast.
{
  pkgs,
  lib ? pkgs.lib,
  self,
  ...
}: let
  helpers = import ./lib.nix {inherit pkgs lib;};
  runUnitTests = helpers.runUnitTests;

  # Force a list of option paths and return their values.
  optionsOf = config: paths:
    builtins.listToAttrs (map (p: {
        name = lib.strings.concatStringsSep "." p;
        value = lib.attrByPath p null config;
      })
      paths);

  commonPaths = [
    ["system" "stateVersion"]
    ["networking" "hostName"]
  ];
in
  runUnitTests "host-eval" {
    testHorizonHostname = {
      expr = (optionsOf self.nixosConfigurations.horizon.config commonPaths)."networking.hostName";
      expected = "horizon";
    };

    testHorizonStateVersion = {
      expr = (optionsOf self.nixosConfigurations.horizon.config commonPaths)."system.stateVersion";
      expected = "26.05";
    };

    testHorizonEnablesDesktop = {
      expr = self.nixosConfigurations.horizon.config.my.desktop.enable;
      expected = true;
    };

    testHorizonUsesSystemdBoot = {
      expr = self.nixosConfigurations.horizon.config.boot.loader.systemd-boot.enable;
      expected = true;
    };

    testHorizonEnablesTailscaleWithNftables = {
      expr = let
        cfg = self.nixosConfigurations.horizon.config.my.tailscale;
      in {
        enable = cfg.enable;
        useNftables = cfg.useNftables;
      };
      expected = {
        enable = true;
        useNftables = true;
      };
    };

    testHorizonWiresHomeManagerForZero = {
      expr = let
        hm = self.nixosConfigurations.horizon.config.home-manager;
      in {
        hasZero = hm.users ? zero;
        useGlobalPkgs = hm.useGlobalPkgs;
        useUserPackages = hm.useUserPackages;
        backupFileExtension = hm.backupFileExtension;
      };
      expected = {
        hasZero = true;
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "bak";
      };
    };

    testServitorHostname = {
      expr = (optionsOf self.nixosConfigurations.servitor.config commonPaths)."networking.hostName";
      expected = "servitor";
    };

    testServitorUsesSystemdBoot = {
      expr = self.nixosConfigurations.servitor.config.boot.loader.systemd-boot.enable;
      expected = true;
    };

    testServitorEnablesDockerPowerIntel = {
      expr = let
        cfg = self.nixosConfigurations.servitor.config.my;
      in {
        docker = cfg.docker.enable;
        power = cfg.power.enable;
        intel = cfg.intel.enable;
        networkMount = cfg.networkMount.enable;
        networkMountFsType = cfg.networkMount.fsType;
        networkMountDevice = cfg.networkMount.device;
      };
      expected = {
        docker = true;
        power = true;
        intel = true;
        networkMount = true;
        networkMountFsType = "nfs";
        networkMountDevice = "192.168.1.100:/data";
      };
    };

    testServitorEnablesTailscale = {
      expr = self.nixosConfigurations.servitor.config.my.tailscale.enable;
      expected = true;
    };

    testServitorEnablesOpenSsh = {
      expr = self.nixosConfigurations.servitor.config.services.openssh.enable;
      expected = true;
    };

    testDeusVaultHostname = {
      expr = (optionsOf self.nixosConfigurations.deus-vault.config commonPaths)."networking.hostName";
      expected = "deus-vault";
    };

    testDeusVaultEnablesDockerTailscalePowerIntel = {
      expr = let
        cfg = self.nixosConfigurations.deus-vault.config.my;
      in {
        docker = cfg.docker.enable;
        power = cfg.power.enable;
        intel = cfg.intel.enable;
        tailscale = cfg.tailscale.enable;
        tailscaleNftables = cfg.tailscale.useNftables;
      };
      expected = {
        docker = true;
        power = true;
        intel = true;
        tailscale = true;
        tailscaleNftables = true;
      };
    };

    testDeusVaultEnablesOpenSsh = {
      expr = self.nixosConfigurations.deus-vault.config.services.openssh.enable;
      expected = true;
    };

    testDeusVaultUsesGrubOnMbr = {
      expr = let
        loader = self.nixosConfigurations.deus-vault.config.boot.loader;
      in {
        systemdBoot = loader.systemd-boot.enable;
        grub = loader.grub.enable;
        # disko derives the GRUB devices from the disk config's EF02
        # partitions; they must cover all four member disks, without
        # duplicates.
        grubDevices = builtins.sort (a: b: a < b) loader.grub.devices;
        noDuplicates = builtins.length loader.grub.devices == builtins.length (lib.lists.unique loader.grub.devices);
      };
      expected = {
        systemdBoot = false;
        grub = true;
        grubDevices = ["/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd"];
        noDuplicates = true;
      };
    };
  }
