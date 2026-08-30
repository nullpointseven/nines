#!/usr/bin/env bash
# Shared logic for the `install` app (see flake.nix).
# Sourced by the generated install script and exercised directly by the
# tests in tests/install/.

# Parse install script arguments into the global variables HOST, DEVICE and
# EXTRA_ARGS.
#
# Usage: install [HOST] [DEVICE] [nixos-install flags...]
#
# - If the first non-flag argument starts with /dev it is the device and the
#   host stays at the default (INSTALL_HOST or "horizon").
# - Otherwise the first non-flag argument is the host and the second
#   non-flag argument (if any) is the device.
# - Everything else is forwarded to nixos-install.
parse_install_args() {
  HOST="${INSTALL_HOST:-horizon}"
  DEVICE="/dev/nvme0n1"
  EXTRA_ARGS=("$@")

  if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
    if [[ "$1" =~ ^/dev ]]; then
      DEVICE="$1"
      EXTRA_ARGS=("${@:2}")
    else
      HOST="$1"
      if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
        DEVICE="$2"
        EXTRA_ARGS=("${@:3}")
      else
        EXTRA_ARGS=("${@:2}")
      fi
    fi
  fi
}

# Render a disko `--arg disks` JSON array from device paths, validating that
# each is an absolute /dev path. Prints the JSON on stdout; errors on stderr.
# Prefer stable paths like /dev/disk/by-id/... over raw /dev/sdX names.
disko_disks_json() {
  local json="" dev
  for dev in "$@"; do
    if [[ ! "$dev" =~ ^/dev/ ]]; then
      echo "error: disk device '$dev' must be an absolute /dev path (prefer /dev/disk/by-id/...)" >&2
      return 1
    fi
    if [[ "$dev" == *'"'* || "$dev" == *'\'* ]]; then
      echo "error: disk device '$dev' contains invalid characters" >&2
      return 1
    fi
    json+="\"$dev\","
  done
  echo "[${json%,}]"
}

# deus-vault has five disks (1 OS drive + 4 RAID5 members) whose raw /dev/sdX
# names cannot be mapped to physical drives at installer boot. Print a disk
# inventory and ask which device is which, then print a disko `--arg disks`
# JSON array on stdout. The inventory goes to stderr so the JSON stays clean.
# Set DEUS_VAULT_DISKS (space separated, 5 devices) to skip the prompt.
select_deus_vault_disks() {
  local labels=("OS drive" "RAID member 1" "RAID member 2" "RAID member 3" "RAID member 4")
  local disks=() dev i

  echo "[install] $HOST needs 5 disks: 1 OS drive + 4 RAID5 members." >&2
  echo "[install] Identify the drives by MODEL/SERIAL (printed on the hardware):" >&2
  lsblk -o NAME,SIZE,MODEL,SERIAL,TRAN,PATH,MOUNTPOINTS >&2
  echo >&2
  echo "[install] Stable device names (preferred; match the SERIAL above):" >&2
  ls -l /dev/disk/by-id/ 2>/dev/null | grep -v -- '-part[0-9]' >&2 || true
  echo >&2

  for i in 0 1 2 3 4; do
    read -r -p "[install] ${labels[$i]} (e.g. /dev/disk/by-id/...): " dev
    disks+=("$dev")
  done
  disko_disks_json "${disks[@]}"
}
