{lib, ...}: {
  disko.devices = {
    disk = {
      # OS drive: EFI System Partition (systemd-boot) + ext4 root.
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              type = "EF00"; # EFI system partition
              size = "512M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
      # Two RAID1 member drives (data only, no boot partitions).
      disk1 = {
        type = "disk";
        device = "/dev/sdb";
        content = {
          type = "gpt";
          partitions = {
            mdadm = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "data";
              };
            };
          };
        };
      };
      disk2 = {
        type = "disk";
        device = "/dev/sdc";
        content = {
          type = "gpt";
          partitions = {
            mdadm = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "data";
              };
            };
          };
        };
      };
    };
    mdadm = {
      data = {
        type = "mdadm";
        level = 1;
        content = {
          type = "gpt";
          partitions = {
            primary = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
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
