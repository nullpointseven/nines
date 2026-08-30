# VM integration test for the my.networkMount module: a real NFS server node
# exports a directory and the client node uses the module (x-systemd.automount
# fstab entry) to mount it on demand. Verifies the generated fstab options
# work end to end, including the automount-on-access behaviour.
{
  lib,
  pkgs,
  ...
}: {
  name = "my-network-mount-nfs";

  nodes = {
    server = {
      services.nfs.server.enable = true;
      services.nfs.server.exports = ''
        /export 192.168.1.0/24(rw,no_root_squash,no_subtree_check,fsid=0)
      '';
      services.nfs.server.createMountPoints = true;
      networking.firewall.enable = false; # test network only
      virtualisation.vlans = [1];
    };

    client = {
      imports = [../../modules/nixos/network-mount.nix];

      my.networkMount = {
        enable = true;
        # fsid=0 makes the export the NFSv4 pseudo-root
        device = "server:/";
        fsType = "nfs";
      };

      # Test VMs replace the whole `fileSystems` option with
      # `virtualisation.fileSystems` (mkVMOverride), so the mount must be
      # declared there. Use the same options the module generates (pinned
      # exactly by the module-eval check) to exercise the automount/NFS
      # semantics end to end.
      virtualisation.fileSystems."/mnt/nas" = {
        device = "server:/";
        fsType = "nfs";
        options = [
          "x-systemd.automount"
          "noauto"
          "x-systemd.idle-timeout=60"
          "x-systemd.device-timeout=5s"
          "x-systemd.mount-timeout=5s"
          "_netdev"
          "soft"
          "nofail"
        ];
      };

      networking.firewall.enable = false; # test network only
      virtualisation.vlans = [1];
    };
  };

  testScript = ''
    start_all()

    server.wait_for_unit("nfs-server")

    # The automount unit is generated from the fstab entry but is not pulled
    # in at boot in a minimal test VM (no network-online.target). Start it,
    # then verify on-demand mounting works.
    client.succeed("systemctl start mnt-nas.automount")
    client.wait_for_unit("mnt-nas.automount")

    # automount kicks in on first access
    client.wait_until_succeeds("ls /mnt/nas")
    client.succeed("mountpoint /mnt/nas")

    # the mount must be an NFS mount
    mounts = client.succeed("mount | grep /mnt/nas")
    assert "nfs" in mounts, f"expected NFS mount, got: {mounts}"

    # writes must reach the server
    client.succeed("echo hello-from-client > /mnt/nas/from-client")
    server.succeed("grep -q hello-from-client /export/from-client")
  '';
}
