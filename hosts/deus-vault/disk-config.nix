{
  lib,
  # All five devices, in order: OS drive first, then the four RAID5 members.
  # At installer boot the raw /dev/sdX names do not identify the physical
  # drives, so pass stable paths (e.g. /dev/disk/by-id/...) — the `install`
  # app collects them interactively (see scripts/install-lib.sh).
  disks ? [
    "/dev/sda"
    "/dev/sdb"
    "/dev/sdc"
    "/dev/sdd"
    "/dev/sde"
  ],
  ...
}: {
  disko.devices = {
    disk = {
      # OS drive: GRUB MBR boot partition + btrfs root.
      main = {
        type = "disk";
        device = assert lib.length disks == 5; builtins.elemAt disks 0;
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
      disk1 = {
        type = "disk";
        device = assert lib.length disks == 5; builtins.elemAt disks 1;
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
      disk2 = {
        type = "disk";
        device = assert lib.length disks == 5; builtins.elemAt disks 2;
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
      disk3 = {
        type = "disk";
        device = assert lib.length disks == 5; builtins.elemAt disks 3;
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
      disk4 = {
        type = "disk";
        device = assert lib.length disks == 5; builtins.elemAt disks 4;
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
    };
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
