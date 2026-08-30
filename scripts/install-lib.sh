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
