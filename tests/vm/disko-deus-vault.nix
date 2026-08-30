# VM integration test for hosts/deus-vault/disk-config.nix: boots a test VM
# with four virtual disks, runs disko's destroy/format/mount on the config and
# verifies the mdadm RAID5 array is assembled and the btrfs /data filesystem
# is mounted. Boot is skipped (testBoot = false) since the config uses LUKS
# for other hosts and MBR-only for this one; this still exercises the whole
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
    name = "deus-vault-mdadm-raid5";
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

      # the btrfs filesystem must be mounted as the root of the layout
      machine.succeed("mountpoint /mnt")
      fstype = machine.succeed("df -T /mnt")
      assert "btrfs" in fstype, f"expected btrfs on /mnt, got: {fstype}"
    '';
  }
