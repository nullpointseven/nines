# VM integration test for the my.tailscale module with the nftables backend:
# boots a machine with the module enabled and verifies the tailscaled service
# runs, the nftables backend is active, and the firewall rules are wired to
# the tailscale port/interface.
{
  lib,
  pkgs,
  ...
}: {
  name = "my-tailscale-nftables";

  nodes.machine = {
    imports = [../../modules/nixos/tailscale.nix];

    my.tailscale = {
      enable = true;
      useNftables = true;
    };

    networking.firewall.enable = true;
    virtualisation.vlans = [1];
  };

  testScript = {nodes, ...}: let
    port = toString nodes.machine.services.tailscale.port;
    iface = nodes.machine.services.tailscale.interfaceName;
  in ''
    start_all()

    machine.wait_for_unit("tailscaled.service")
    machine.wait_for_unit("nftables.service")

    # the nftables backend must be reflected in the service environment
    env = machine.succeed(
        "systemctl show tailscaled.service -p Environment --value"
    )
    assert "TS_DEBUG_FIREWALL_MODE=nftables" in env, f"missing nftables env: {env}"

    # the firewall must open the tailscale port and trust the tailscale interface
    ruleset = machine.succeed("nft list ruleset")
    assert "${port}" in ruleset, f"tailscale port ${port} missing from ruleset: {ruleset}"
    assert "${iface}" in ruleset, f"tailscale interface ${iface} missing from ruleset: {ruleset}"
  '';
}
