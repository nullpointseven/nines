# Evaluation tests for the disko disk configurations in hosts/*/disk-config.nix.
#
# Each config is evaluated through disko's NixOS module so that disko's own
# type checking applies, and the resulting `disko.devices` tree is asserted
# against the expected partition/layout structure. This catches config
# regressions (typos, invalid partition types/sizes, missing subvolumes)
# without needing to touch real disks or boot VMs.
{
  pkgs,
  lib ? pkgs.lib,
  inputs,
  ...
}: let
  helpers = import ./lib.nix {inherit pkgs lib;};
  evalNixOS = helpers.evalNixOS;
  runUnitTests = helpers.runUnitTests;

  diskoModule = inputs.disko.nixosModules.disko;

  # Evaluate a disk config with a given device list and return its
  # `disko.devices` tree.
  evalDisko = diskConfig: disks:
    (evalNixOS [
      diskoModule
      (diskConfig {
        inherit lib;
        disks = disks;
      })
    ]).config.disko.devices;

  horizon = evalDisko (import ../hosts/horizon/disk-config.nix) ["/dev/nvme0n1"];
  servitor = evalDisko (import ../hosts/servitor/disk-config.nix) ["/dev/nvme0n1"];
  deusVault = evalDisko (import ../hosts/deus-vault/disk-config.nix) [];
in
  runUnitTests "disko-eval" {
    # ------------------------------------------------------------------
    # horizon / servitor share the same layout: LUKS-on-GPT, btrfs
    # subvolumes, 8G swapfile.
    # ------------------------------------------------------------------
    testHorizonMainDiskDevice = {
      expr = horizon.disk.main.device;
      expected = "/dev/nvme0n1";
    };

    testHorizonDiskArgOverridesDevice = {
      expr = (evalDisko (import ../hosts/horizon/disk-config.nix) ["/dev/sdz"]).disk.main.device;
      expected = "/dev/sdz";
    };

    testHorizonEspPartition = {
      expr = let
        esp = horizon.disk.main.content.partitions.ESP;
      in {
        size = esp.size;
        type = esp.type;
        format = esp.content.format;
        mountpoint = esp.content.mountpoint;
        mountOptions = esp.content.mountOptions;
      };
      expected = {
        size = "512M";
        type = "EF00";
        format = "vfat";
        mountpoint = "/boot";
        mountOptions = ["umask=0077"];
      };
    };

    testHorizonLuksPartition = {
      expr = let
        luks = horizon.disk.main.content.partitions.luks.content;
      in {
        name = luks.name;
        allowDiscards = luks.settings.allowDiscards;
        fsType = luks.content.type;
      };
      expected = {
        name = "crypted";
        allowDiscards = true;
        fsType = "btrfs";
      };
    };

    testHorizonBtrfsSubvolumes = {
      expr = let
        subvols = horizon.disk.main.content.partitions.luks.content.content.subvolumes;
      in
        builtins.attrNames subvols;
      expected = ["/home" "/nix" "/root" "/swap"];
    };

    testHorizonSubvolumeMountpoints = {
      expr = let
        subvols = horizon.disk.main.content.partitions.luks.content.content.subvolumes;
      in {
        root = subvols."/root".mountpoint;
        home = subvols."/home".mountpoint;
        nix = subvols."/nix".mountpoint;
        swap = subvols."/swap".mountpoint;
      };
      expected = {
        root = "/";
        home = "/home";
        nix = "/nix";
        swap = "/.swapvol";
      };
    };

    testHorizonSubvolumeMountOptions = {
      expr = let
        subvols = horizon.disk.main.content.partitions.luks.content.content.subvolumes;
      in {
        root = subvols."/root".mountOptions;
        nix = subvols."/nix".mountOptions;
      };
      expected = {
        root = ["compress=zstd" "noatime"];
        nix = ["compress=zstd" "noatime"];
      };
    };

    testHorizonSwapfileSize = {
      expr = horizon.disk.main.content.partitions.luks.content.content.subvolumes."/swap".swap.swapfile.size;
      expected = "8G";
    };

    testServitorMatchesHorizonLayout = {
      expr = let
        esp = servitor.disk.main.content.partitions.ESP;
        luks = servitor.disk.main.content.partitions.luks.content;
      in {
        device = servitor.disk.main.device;
        espSize = esp.size;
        luksName = luks.name;
        btrfs = luks.content.type;
        subvols = builtins.attrNames luks.content.subvolumes;
      };
      expected = {
        device = "/dev/nvme0n1";
        espSize = "512M";
        luksName = "crypted";
        btrfs = "btrfs";
        subvols = ["/home" "/nix" "/root" "/swap"];
      };
    };

    # ------------------------------------------------------------------
    # deus-vault: OS drive on /dev/sda (btrfs root), 4-disk mdadm RAID5
    # array (/dev/sdb..sde) with btrfs on top at /data, grub MBR.
    # ------------------------------------------------------------------
    testDeusVaultHasFiveDisks = {
      expr = builtins.attrNames deusVault.disk;
      expected = ["disk1" "disk2" "disk3" "disk4" "main"];
    };

    testDeusVaultDiskDevices = {
      expr = builtins.map (d: deusVault.disk.${d}.device) ["main" "disk1" "disk2" "disk3" "disk4"];
      expected = ["/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde"];
    };

    testDeusVaultMainDiskIsOsDrive = {
      expr = let
        main = deusVault.disk.main;
        root = main.content.partitions.root.content;
      in {
        device = main.device;
        rootFormat = root.format;
        rootMountpoint = root.mountpoint;
      };
      expected = {
        device = "/dev/sda";
        rootFormat = "btrfs";
        rootMountpoint = "/";
      };
    };

    # Every one of the four RAID drives must carry an mdraid member of the
    # same `raid5` array (a disk that is not a member would silently shrink
    # the array to 3 drives).
    testDeusVaultAllFourDisksJoinRaid5 = {
      expr = builtins.map (d: let
        member = deusVault.disk.${d}.content.partitions.mdadm.content;
      in {
        device = deusVault.disk.${d}.device;
        type = member.type;
        array = member.name;
      }) ["disk1" "disk2" "disk3" "disk4"];
      expected = [
        {
          device = "/dev/sdb";
          type = "mdraid";
          array = "raid5";
        }
        {
          device = "/dev/sdc";
          type = "mdraid";
          array = "raid5";
        }
        {
          device = "/dev/sdd";
          type = "mdraid";
          array = "raid5";
        }
        {
          device = "/dev/sde";
          type = "mdraid";
          array = "raid5";
        }
      ];
    };

    # The OS drive must not be a RAID member.
    testDeusVaultOsDriveIsNotRaidMember = {
      expr = deusVault.disk.main.content.partitions ? mdadm;
      expected = false;
    };

    testDeusVaultGrubMbrPartitions = {
      expr = let
        main = deusVault.disk.main.content.partitions;
        raidDisk = deusVault.disk.disk1.content.partitions;
      in {
        mainType = main.boot.type;
        mainSize = main.boot.size;
        # RAID drives only carry the mdraid member, no boot partition
        raidDiskPartitions = builtins.attrNames raidDisk;
      };
      expected = {
        mainType = "EF02";
        mainSize = "1M";
        raidDiskPartitions = ["mdadm"];
      };
    };

    testDeusVaultMdadmArray = {
      expr = {
        type = deusVault.mdadm.raid5.type;
        level = deusVault.mdadm.raid5.level;
      };
      expected = {
        type = "mdadm";
        level = 5;
      };
    };

    testDeusVaultMdadmExtraArgs = {
      expr = deusVault.mdadm.raid5.extraArgs;
      expected = ["--assume-clean"];
    };

    testDeusVaultDataFilesystem = {
      expr = let
        primary = deusVault.mdadm.raid5.content.partitions.primary;
      in {
        format = primary.content.format;
        mountpoint = primary.content.mountpoint;
      };
      expected = {
        format = "btrfs";
        mountpoint = "/data";
      };
    };
  }
