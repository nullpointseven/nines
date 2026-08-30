# NixOS configuration

Flake-based NixOS and Home Manager configuration for the author's machines
("Nullpointseven"), managed declaratively with Nixpkgs `nixos-26.05`,
Home Manager, Disko, sops-nix and a few custom NixOS modules.

## Hosts

| Host | Role | Highlights |
|------|------|------------|
| `horizon` | Desktop | AMD, Hyprland desktop (X/Wayland, LightDM, fcitx5, Steam), Tailscale (nftables), Home Manager for `zero` |
| `servitor` | Laptop | Intel (iGPU/VA-API), TLP power management + lid handling, Docker, Tailscale, NFS network mount, sops-nix secrets |
| `deus-vault` | Server | OS on `/dev/sda` (btrfs), 4-drive mdadm RAID5 (btrfs) at `/data`, GRUB on MBR, Docker, Tailscale (nftables), Intel, TLP |

All hosts are `x86_64-linux`; the flake also evaluates pure checks for
`aarch64-linux`.

## Repository layout

```
flake.nix                 # inputs, hosts, home config, checks, install app
hosts/<host>/             # per-host configuration (incl. disko disk configs)
modules/nixos/            # reusable NixOS modules (my.* options), auto-imported
modules/home/             # reusable Home Manager modules, auto-imported
home-manager/home.nix     # the shared home configuration for user `zero`
lib/                      # small pure Nix helpers (scanPaths)
overlays/                 # overlay adding an `unstable` package set
pkgs/                     # custom packages (callPackage)
scripts/install-lib.sh    # arg parsing shared by the `install` app
tests/                    # test suite (see tests/README.md)
dotfiles/                 # git submodule with dotfiles (nvim, hypr, ...)
```

Custom NixOS functionality lives behind `my.*` options (e.g.
`my.docker.enable`, `my.tailscale.useNftables`, `my.networkMount`) so hosts
stay small and behaviour is testable.

## Prerequisites

- Nix 2.19+ with flakes enabled, or NixOS itself
- For VM tests: a machine with KVM

## Common commands

```console
# Build/switch a host
sudo nixos-rebuild switch --flake .#horizon

# Rebuild the Home Manager configuration (also managed inside horizon)
home-manager switch --flake .#zero@horizon

# Update the lock file
nix flake update

# Run the test suite (fast checks + VM tests; requires KVM)
nix flake check

# Fast, evaluation-only checks (no VMs)
nix build .#checks.x86_64-linux.unit \
  .#checks.x86_64-linux.module-eval \
  .#checks.x86_64-linux.disko-eval \
  .#checks.x86_64-linux.overlay \
  .#checks.x86_64-linux.install-args \
  .#checks.x86_64-linux.host-eval \
  .#checks.x86_64-linux.home-eval

# Format the tree with alejandra (CI enforces this)
# (Some Nix versions do not pass file arguments to `nix fmt`, so invoke
# alejandra directly — this is also what CI does.)
FORMATTER="$(nix build .#formatter.x86_64-linux --print-out-paths)"
"$FORMATTER/bin/alejandra" $(git ls-files '*.nix')
```

See [tests/README.md](tests/README.md) for details about the test suite.

## Installing a new host

From the NixOS installer, the `install` app partitions and mounts the target
disk with Disko and then runs `nixos-install`:

```console
# defaults: host=horizon, device=/dev/nvme0n1
nix run .#install

# explicit host and device (plus extra nixos-install flags)
nix run .#install -- servitor /dev/sdb --no-bootloader

# or via the INSTALL_HOST environment variable
INSTALL_HOST=deus-vault nix run .#install
```

`deus-vault` needs five disks (1 OS drive + 4 RAID5 members). Because the raw
`/dev/sdX` names don't identify the physical drives at installer boot, the app
prints a disk inventory (`lsblk` with model/serial) and asks which device is
the OS drive and which four are the RAID members — enter stable paths such as
`/dev/disk/by-id/...`. The selected drives are also injected into the system
build, so the baked-in GRUB devices point at the real OS drive. To skip the
prompt in a scripted install:

```console
DEUS_VAULT_DISKS="/dev/disk/by-id/ata-OS /dev/disk/by-id/ata-R1 /dev/disk/by-id/ata-R2 /dev/disk/by-id/ata-R3 /dev/disk/by-id/ata-R4" nix run .#install
```

For `horizon` the dotfiles submodule is copied into the target home during
installation.

## Secrets

`sops-nix` is used on `servitor` (see `hosts/servitor/secrets.nix`); secrets
are decrypted at activation time from the configured sops files.

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs:

1. **format** — alejandra formatting check (`git diff --exit-code` after formatting)
2. **fast** — all non-VM checks
3. **vm** — the three NixOS VM/integration tests
