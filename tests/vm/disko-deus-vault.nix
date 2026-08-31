# VM integration test for hosts/deus-vault/disk-config.nix: boots a test VM
# with three virtual disks (OS drive + two RAID1 members), runs disko's
# destroy/format/mount on the config and verifies the mdadm RAID1 array is
# assembled with both members and the OS root and /data btrfs volumes are
# mounted. Boot is skipped (testBoot = false); this still exercises the whole
# disko pipeline against the real config.
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
    name = "deus-vault-efi-raid1";
    disko-config = ../../hosts/deus-vault/disk-config.nix;
    efi = true;
    testBoot = false;
    extraTestScript = ''
      # the RAID1 array must exist and be assembled
      machine.succeed("test -b /dev/md/data")
      mdstat = machine.succeed("cat /proc/mdstat")
      assert "raid1" in mdstat, f"raid1 not in mdstat: {mdstat}"

      # both member disks must be active in the array
      active = machine.succeed("mdadm --detail /dev/md/data | grep -c 'active sync'")
      assert active.strip() == "2", f"expected 2 active drives in raid1, got: {active}"

      # the OS root (on the main disk) and the /data volume (on the array)
      # must both be mounted as btrfs
      machine.succeed("mountpoint /mnt")
      machine.succeed("mountpoint /mnt/data")
      fstype = machine.succeed("df -T /mnt /mnt/data")
      assert fstype.count("btrfs") == 2, f"expected btrfs on both mounts, got: {fstype}"
    '';
  }
