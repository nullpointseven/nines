{lib, ...}: {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              type = "EF00"; # for grub MBR
              size = "512M";
			  content = {
				type = "filesystem";
				format = "vfat";
				mountpoint = "/boot";
				mountOptions = [ "umask=0077" ];
			  };
            };
			root = {
				size = "100%"
				content = {
					type = "filesystem";
					format = "btrfs";
					mountpoint = "/";
				}
			}
          };
        };
      };
      disk1 = {
        type = "disk";
        device = "/dev/sdb";
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02"; # for grub MBR
            };
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
            boot = {
              size = "1M";
              type = "EF02"; # for grub MBR
            };
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
                format = "btrfs";
                mountpoint = "/data";
              };
            };
          };
        };
        extraArgs = ["--assume-clean"];
      };
    };
  };
}
