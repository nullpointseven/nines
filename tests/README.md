# Tests

This flake ships a test suite that runs via `nix flake check` (or per-check
`nix build .#checks.<system>.<name>`). Checks are defined in
`flake.nix` under the `checks` output and live in this directory.

## Running

```console
# everything (fast checks + VM tests)
nix flake check

# only the fast, evaluation-only checks
nix build \
  .#checks.x86_64-linux.unit \
  .#checks.x86_64-linux.module-eval \
  .#checks.x86_64-linux.disko-eval \
  .#checks.x86_64-linux.overlay \
  .#checks.x86_64-linux.install-args \
  .#checks.x86_64-linux.host-eval \
  .#checks.x86_64-linux.home-eval \
  .#checks.x86_64-linux.install-app-syntax

# a single VM/integration test
nix build .#checks.x86_64-linux.vm-tailscale
```

VM tests boot real QEMU machines, so they require KVM on the host (and a few
minutes of build time on first run).

## What is covered

| Check | Kind | What it verifies |
|-------|------|------------------|
| `unit` | pure Nix unit tests | `lib.scanPaths` filtering (`.nix` files, `default.nix` exclusion, directories, empty dirs, importability, determinism) |
| `module-eval` | NixOS module evaluation | Every custom `my.*` module (`docker`, `tailscale`, `networkMount`, `intel`, `power`, `desktop`) evaluated against the full NixOS option set: defaults, enabled behaviour, edge cases (custom users, CIFS credentials, nftables backend, firewall wiring) and failure cases (wrong option types, undeclared options rejected via `_module.check`) |
| `disko-eval` | disko module evaluation | All three `hosts/*/disk-config.nix` validate against disko's own type system and produce the expected partition/subvolume/raid layout |
| `overlay` | evaluation | The `unstable` overlay adds a distinct package set |
| `install-args` | shell test | Argument parsing in `scripts/install-lib.sh` (host/device/flags matrix, `INSTALL_HOST` handling) |
| `install-app-syntax` | shell check | The generated `install` app is syntactically valid bash |
| `host-eval` | configuration evaluation | Each `nixosConfiguration` (horizon/servitor/deus-vault) evaluates with the expected hostname, stateVersion, custom-module flags and service wiring |
| `home-eval` | home-manager evaluation | The home configuration evaluates: firefox policies/extensions/search/containers, git config, udiskie/mpris-proxy services, and `home.packages` resolves |
| `vm-tailscale` | NixOS VM test | Boots a machine with `my.tailscale` + nftables backend: tailscaled runs, nftables backend env is set, firewall opens the tailscale port/interface |
| `vm-network-mount` | NixOS VM test | Two machines: a real NFS server and a client using `my.networkMount`; verifies the automount fstab entry actually mounts the export and writes reach the server |
| `vm-disko-deus-vault` | disko VM test | Runs disko destroy/format/mount for the deus-vault config on virtual disks (EFI OS drive + 2 RAID1 members); verifies the array is assembled with 2 active drives and both OS root and `/data` btrfs volumes are mounted |

## Conventions

- **Pure evaluation checks** use `lib.runTests` wrapped into a check
  derivation by `tests/lib.nix` (`runUnitTests`), with `lib.evalModules`
  against the full NixOS module list (`evalNixOS`) so that
  `_module.check` catches undeclared options and option types are enforced.
- **Failure cases** use `builtins.tryEval` (see `testThrows` in `tests/lib.nix`).
- **VM tests** use `pkgs.testers.runNixOSTest`; the disko test uses
  `inputs.disko.lib.testLib.makeDiskoTest`.
- Checks run on `x86_64-linux`; the pure checks (`unit`, `module-eval`,
  `disko-eval`, `overlay`, `install-args`) also run on `aarch64-linux`.

CI (`.github/workflows/ci.yml`) runs the fast checks first and the VM tests
in a second job.

## Test helpers

`tests/lib.nix` provides:

- `evalNixOS modules` — evaluate NixOS modules against the full option set.
- `runUnitTests name tests` — turn `lib.runTests` cases into a check derivation.
- `testThrows expr` — assert that evaluating `expr` fails.
