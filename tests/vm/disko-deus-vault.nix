# VM integration test for hosts/deus-vault/disk-config.nix: boots a test VM
# with five virtual disks (OS drive + four RAID members), runs disko's
# destroy/format/mount on the config and verifies the mdadm RAID5 array is
# assembled with all four members and both the OS root and the /data btrfs
# volumes are mounted. Boot is skipped (testBoot = false); this still
# exercises the whole disko pipeline against the real config.
{
  pkgs,
  lib ? pkgs.lib,
  inputs,
  ...
}: let
  diskoLib = inputs.disko.lib;
in
  diskoLib.testLib.makeDiskoTest {
    inherit pkgs;
    name = "deus-vault-os-plus-mdadm-raid5";
    disko-config = ../../hosts/deus-vault/disk-config.nix;
    efi = false;
    testBoot = false;
    extraTestScript = ''
      # the RAID5 array must exist and be assembled
      machine.succeed("test -b /dev/md/raid5")
      mdstat = machine.succeed("cat /proc/mdstat")
      assert "raid5" in mdstat, f"raid5 not in mdstat: {mdstat}"

      # all four member disks must be active in the array
      active = machine.succeed("mdadm --detail /dev/md/raid5 | grep -c 'active sync'")
      assert active.strip() == "4", f"expected 4 active drives in raid5, got: {active}"

      # the OS root (on the main disk) and the /data volume (on the array)
      # must both be mounted as btrfs
      machine.succeed("mountpoint /mnt")
      machine.succeed("mountpoint /mnt/data")
      fstype = machine.succeed("df -T /mnt /mnt/data")
      assert fstype.count("btrfs") == 2, f"expected btrfs on both mounts, got: {fstype}"
    '';
  }
