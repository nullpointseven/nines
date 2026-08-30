# Regression test for interactive `mdadm --create` aborts during a real
# deus-vault install: when the RAID member partitions contain leftover
# signatures (e.g. reused disks), mdadm asks "Continue creating array [y/N]?"
# and disko's single piped 'y' has already been consumed by the write-intent
# bitmap prompt, so the create aborts (non-interactive stdin reads EOF).
#
# This replicates disko's exact mdadm invocation with the extraArgs from
# hosts/deus-vault/disk-config.nix on disks with leftover partition tables and
# asserts the array is created with the write-intent bitmap enabled.
{
  pkgs,
  lib ? pkgs.lib,
  ...
}: let
  extraArgs = (import ../../hosts/deus-vault/disk-config.nix {inherit lib;}).disko.devices.mdadm.raid5.extraArgs;

  # mirror of disko's lib/types/mdadm.nix _create script
  createCmd = lib.concatStringsSep " " ([
      "echo y | mdadm --create /dev/md/raid5 --level=5 --raid-devices=4"
      "--metadata=default --force --homehost=any"
    ]
    ++ extraArgs ++ ["/dev/vdb1" "/dev/vdc1" "/dev/vdd1" "/dev/vde1"]);
in {
  name = "deus-vault-mdadm-create";
  nodes.machine = {
    virtualisation.emptyDiskImages = [512 512 512 512];
    environment.systemPackages = [pkgs.mdadm pkgs.gptfdisk pkgs.parted];
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")

    # simulate reused disks: GPT on each disk, plus a GPT partition table
    # written inside each member partition
    for d in ["vdb", "vdc", "vdd", "vde"]:
        machine.succeed(f"sgdisk --zap-all /dev/{d}")
        machine.succeed(f"sgdisk -n 1:2048:+100M -t 1:fd00 /dev/{d}")
        machine.succeed(f"partprobe /dev/{d}")
        machine.succeed(f"sgdisk --zap-all /dev/{d}1")
        machine.succeed(f"sgdisk -n 1:2048:4096 -t 1:8300 /dev/{d}1")
    machine.succeed("partprobe")

    # must not abort on the interactive prompts (bitmap + partition table)
    machine.succeed(${lib.escapeShellArg createCmd})
    mdstat = machine.succeed("cat /proc/mdstat")
    assert "active raid5" in mdstat, mdstat
    assert "bitmap:" in mdstat, f"write-intent bitmap missing: {mdstat}"
  '';
}
