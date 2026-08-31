{
  lib,
  # All devices, in order: OS drive first, then the RAID5 members (any number
  # >= 1). At installer boot the raw /dev/sdX names do not identify the
  # physical drives, so pass stable paths (e.g. /dev/disk/by-id/...) — the
  # `install` app collects them interactively (see scripts/install-lib.sh).
  disks ? [
    "/dev/sda"
    "/dev/sdb"
    "/dev/sdc"
    "/dev/sdd"
    "/dev/sde"
  ],
  ...
}: let
  # Lazy (only evaluated when a device is forced) so the module system can
  # resolve the `disks` argument first; an eager assert at import time causes
  # an infinite recursion. At least one RAID member is required.
  assertSufficientDisks = d: assert lib.length disks >= 2; d;

  raidMembers = builtins.tail disks;

  # Each RAID drive: GPT with a single mdraid member partition.
  mkRaidMember = device: {
    type = "disk";
    device = assertSufficientDisks device;
    content = {
      type = "gpt";
      partitions = {
        mdadm = {
          size = "100%";
          content = {
            type = "mdraid";
            name = "raid5";
          };
        };
      };
    };
  };

  raidDisks = lib.listToAttrs (
    lib.imap1 (i: dev: lib.nameValuePair "disk${toString i}" (mkRaidMember dev)) raidMembers
  );
in {
  disko.devices = {
    disk =
      {
        # OS drive: GRUB MBR boot partition + btrfs root.
        main = {
          type = "disk";
          device = assertSufficientDisks (builtins.elemAt disks 0);
          content = {
            type = "gpt";
            partitions = {
              boot = {
                size = "1M";
                type = "EF02"; # for grub MBR
              };
              root = {
                size = "100%";
                content = {
                  type = "filesystem";
                  format = "btrfs";
                  mountpoint = "/";
                };
              };
            };
          };
        };
      }
      // raidDisks;
    mdadm = {
      raid5 = {
        type = "mdadm";
        level = 5;
        content = {
          type = "gpt";
          partitions = {
            primary = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "btrfs";
                mountpoint = "/data";
              };
            };
          };
        };
        # --assume-clean: skip the initial resync when creating a fresh array.
        # --bitmap=internal: enable the write-intent bitmap (faster recovery
        # after a drive failure) and skip mdadm's interactive bitmap prompt.
        # disko pipes a single 'y' to mdadm, which then answers the
        # "partition table exists... Continue creating array [y/N]?" prompt
        # that appears when the member partitions contain leftover signatures
        # (without the bitmap flag, that second prompt reads EOF and aborts).
        extraArgs = ["--assume-clean" "--bitmap=internal"];
      };
    };
  };
}
