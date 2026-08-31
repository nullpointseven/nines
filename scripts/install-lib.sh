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

# Print a numbered list of candidate disks as "N|by-id-name|size|raw-device"
# lines. One entry per disk (by-id symlinks pointing at the same device are
# deduped); by-id names embed the MODEL/SERIAL so drives can be matched to
# the hardware. $1: by-id directory (defaults to /dev/disk/by-id, overridable
# for tests via DEUS_VAULT_BYID_DIR).
list_candidate_disks() {
  local byid_dir="$1"
  local -A seen=()
  local i=0 link_path name raw size

  for link_path in "$byid_dir"/*; do
    [[ -L "$link_path" || -e "$link_path" ]] || continue
    name=$(basename "$link_path")
    [[ "$name" != *-part[0-9]* ]] || continue
    raw=$(readlink -f "$link_path" 2>/dev/null || true)
    [[ -n "$raw" ]] || continue
    case "$raw" in
      /dev/sd* | /dev/vd* | /dev/nvme* | /dev/hd*) ;;
      *) continue ;;
    esac
    [[ -n "${seen[$raw]:-}" ]] && continue
    seen[$raw]=1
    size=$(lsblk -d -n -o SIZE "$raw" 2>/dev/null || echo "?")
    i=$((i + 1))
    printf '%s|%s|%s|%s\n' "$i" "$name" "$size" "$raw"
  done
}

# deus-vault has one OS drive plus an arbitrary number (>= 1) of RAID5 member
# disks whose raw /dev/sdX names cannot be mapped to physical drives at
# installer boot. Print a numbered menu of candidate disks (by-id names embed
# the MODEL/SERIAL) and let the user pick by number, then print a disko
# `--arg disks` JSON array on stdout (first device = OS drive, the rest =
# RAID members). The menu goes to stderr so the JSON stays clean. Set
# DEUS_VAULT_DISKS (space separated devices) to skip the prompt.
select_deus_vault_disks() {
  local byid_dir="${DEUS_VAULT_BYID_DIR:-/dev/disk/by-id}"
  local total=0 num name size raw
  local -a byid=() size_of=() raw_of=()
  local os_num count i member_num dup j
  local -a selected=() disks=()

  echo "[install] $HOST needs 1 OS drive + N RAID5 members (N >= 1)." >&2
  echo "[install] Candidate disks (match the MODEL/SERIAL on the hardware):" >&2
  while IFS='|' read -r num name size raw; do
    [[ -n "$num" ]] || continue
    byid[$num]="$name"
    size_of[$num]="$size"
    raw_of[$num]="$raw"
    printf '  [%s] %s (%s, %s)\n' "$num" "$name" "$raw" "$size" >&2
    total=$num
  done < <(list_candidate_disks "$byid_dir")

  if [[ $total -eq 0 ]]; then
    echo "[install] error: no candidate disks found under $byid_dir" >&2
    return 1
  fi

  while true; do
    read -r -p "[install] OS drive (number 1-$total): " os_num
    if [[ "$os_num" =~ ^[0-9]+$ ]] && ((os_num >= 1 && os_num <= total)); then
      break
    fi
    echo "[install] please enter a number between 1 and $total" >&2
  done
  selected+=("$os_num")

  while true; do
    read -r -p "[install] number of RAID5 member disks: " count
    if [[ "$count" =~ ^[0-9]+$ ]] && ((count >= 1)); then
      if ((total >= count + 1)); then
        break
      fi
      echo "[install] not enough disks: need $((count + 1)) (OS + $count members), found $total" >&2
    else
      echo "[install] please enter a positive integer (>= 1)" >&2
    fi
  done

  for ((i = 1; i <= count; i++)); do
    while true; do
      read -r -p "[install] RAID member $i (number 1-$total): " member_num
      if [[ "$member_num" =~ ^[0-9]+$ ]] && ((member_num >= 1 && member_num <= total)); then
        dup=0
        for j in "${selected[@]}"; do
          if ((j == member_num)); then
            dup=1
            break
          fi
        done
        if ((dup == 0)); then
          break
        fi
        echo "[install] disk $member_num is already selected; pick another" >&2
      else
        echo "[install] please enter a number between 1 and $total" >&2
      fi
    done
    selected+=("$member_num")
  done

  for num in "${selected[@]}"; do
    disks+=("/dev/disk/by-id/${byid[$num]}")
  done
  disko_disks_json "${disks[@]}"
}

# Print a disko `--arg disks` JSON array from the DEUS_VAULT_DISKS environment
# variable (space separated devices; first = OS drive, the rest = RAID members).
deus_vault_disks_from_env() {
  local disks=()
  read -r -a disks <<< "${DEUS_VAULT_DISKS:-}"
  if [[ "${#disks[@]}" -lt 2 ]]; then
    echo "error: DEUS_VAULT_DISKS must list the OS drive plus at least 1 RAID member (space separated)" >&2
    return 1
  fi
  disko_disks_json "${disks[@]}"
}
