# Shell tests for the argument parsing in scripts/install-lib.sh (used by the
# `install` app defined in flake.nix). Sources the real script and asserts on
# the HOST / DEVICE / EXTRA_ARGS variables for a matrix of invocations.
{
  pkgs,
  lib ? pkgs.lib,
  installLib ? ../../scripts/install-lib.sh,
  ...
}:
pkgs.runCommand "install-args-tests" {nativeBuildInputs = [pkgs.bash];} ''
  set -euo pipefail

  source ${installLib}

  failures=0

  # run <name> <expected-host> <expected-device> <expected-extra> -- <args...>
  run() {
    local name="$1"
    local expected_host="$2"
    local expected_device="$3"
    local expected_extra="$4"
    shift 4
    # skip until the literal `--` separator, then keep everything after it
    while [[ $# -gt 0 && "$1" != "--" ]]; do shift; done
    shift || true
    local args=("$@")

    parse_install_args "''${args[@]}"

    local ok=1
    [[ "$HOST" == "$expected_host" ]] || ok=0
    [[ "$DEVICE" == "$expected_device" ]] || ok=0
    [[ "''${EXTRA_ARGS[*]:-}" == "$expected_extra" ]] || ok=0

    if [[ $ok -eq 1 ]]; then
      echo "PASS: $name"
    else
      echo "FAIL: $name (args=''${args[*]:-}; got host='$HOST' device='$DEVICE' extra=''${EXTRA_ARGS[*]:-}; expected host='$expected_host' device='$expected_device' extra='$expected_extra')"
      failures=$((failures + 1))
    fi
  }

  # no arguments -> defaults
  run "no-args" horizon /dev/nvme0n1 "" --

  # host only
  run "host-only" servitor /dev/nvme0n1 "" -- servitor

  # device only (first arg starts with /dev)
  run "device-only" horizon /dev/sda "" -- /dev/sda

  # host + device
  run "host-and-device" servitor /dev/sdb "" -- servitor /dev/sdb

  # host + flags
  run "host-with-flags" servitor /dev/nvme0n1 "--foo bar" -- servitor --foo bar

  # device + flags
  run "device-with-flags" horizon /dev/sda "--foo bar" -- /dev/sda --foo bar

  # host + device + flags
  run "host-device-flags" servitor /dev/sdb "--foo bar --baz" -- servitor /dev/sdb --foo bar --baz

  # flags only
  run "flags-only" horizon /dev/nvme0n1 "--foo bar" -- --foo bar

  # multiple flags
  run "multiple-flags" horizon /dev/nvme0n1 "-v --foo" -- -v --foo

  # a non-/dev second arg is still treated as the device (historical behavior)
  run "bare-device-string" servitor sdb "" -- servitor sdb

  # INSTALL_HOST environment variable provides the default host
  INSTALL_HOST=deus-vault parse_install_args
  [[ "$HOST" == "deus-vault" && "$DEVICE" == "/dev/nvme0n1" && "''${EXTRA_ARGS[*]:-}" == "" ]] \
    && echo "PASS: env-host-default" \
    || { echo "FAIL: env-host-default (got host='$HOST' device='$DEVICE')"; failures=$((failures + 1)); }

  # an explicit host argument overrides INSTALL_HOST
  INSTALL_HOST=deus-vault parse_install_args servitor
  [[ "$HOST" == "servitor" ]] \
    && echo "PASS: explicit-host-overrides-env" \
    || { echo "FAIL: explicit-host-overrides-env (got host='$HOST')"; failures=$((failures + 1)); }

  # --- disko_disks_nix (renders a Nix list, not JSON!) ---
  run_nix() {
    local name="$1" expected="$2"
    shift 2
    local out
    if out=$(disko_disks_nix "$@" 2>/dev/null); then
      if [[ "$out" == "$expected" ]]; then
        echo "PASS: $name"
      else
        echo "FAIL: $name (got '$out', expected '$expected')"
        failures=$((failures + 1))
      fi
    else
      echo "FAIL: $name (expected success)"
      failures=$((failures + 1))
    fi
  }

  run_nix "nix-single" '[ "/dev/sda" ]' /dev/sda
  run_nix "nix-five" '[ "/dev/sda" "/dev/sdb" "/dev/sdc" "/dev/sdd" "/dev/sde" ]' /dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde
  run_nix "nix-by-id" '[ "/dev/disk/by-id/ata-FOO" "/dev/disk/by-id/ata-BAR" ]' /dev/disk/by-id/ata-FOO /dev/disk/by-id/ata-BAR

  # the rendered list must be valid Nix (space separated, no commas)
  got=$(disko_disks_nix /dev/sda /dev/sdb)
  if ! printf '%s' "$got" | grep -q ','; then
    echo "PASS: nix-no-commas"
  else
    echo "FAIL: nix-no-commas (got '$got')"
    failures=$((failures + 1))
  fi

  # invalid: not an absolute /dev path
  if got=$(disko_disks_nix "sda" 2>/dev/null); then
    echo "FAIL: nix-rejects-relative-path (got '$got')"
    failures=$((failures + 1))
  else
    echo "PASS: nix-rejects-relative-path"
  fi

  # invalid: embedded quote
  if got=$(disko_disks_nix '/dev/sd"a' 2>/dev/null); then
    echo "FAIL: nix-rejects-quote (got '$got')"
    failures=$((failures + 1))
  else
    echo "PASS: nix-rejects-quote"
  fi

  # --- list_candidate_disks (numbered disk enumeration) ---
  stub_dir=$(mktemp -d)
  mkdir -p "$stub_dir/by-id"
  ln -s /dev/sda "$stub_dir/by-id/ata-WDC_OS"
  ln -s /dev/sdb "$stub_dir/by-id/ata-WDC_R1"
  ln -s /dev/sdc "$stub_dir/by-id/ata-WDC_R2"
  ln -s /dev/sdd "$stub_dir/by-id/ata-WDC_R3"
  ln -s /dev/sde "$stub_dir/by-id/ata-WDC_R4"
  # a second symlink to the same device must be deduped
  ln -s /dev/sdc "$stub_dir/by-id/wwn-0xDUPLICATE"
  # a partition symlink must be skipped
  ln -s /dev/sda1 "$stub_dir/by-id/ata-WDC_OS-part1"
  # /bin/sh shebang: /usr/bin/env is absent in the Nix build sandbox
  printf '%s\n' '#!/bin/sh' "echo '4T'" > "$stub_dir/lsblk"
  chmod +x "$stub_dir/lsblk"

  got=$(PATH="$stub_dir:$PATH" list_candidate_disks "$stub_dir/by-id")
  lines=$(printf '%s\n' "$got" | wc -l)
  if [[ "$lines" -eq 5 ]] \
    && printf '%s\n' "$got" | grep -q '^1|ata-WDC_OS|4T|/dev/sda$' \
    && printf '%s\n' "$got" | grep -q '^5|ata-WDC_R4|4T|/dev/sde$' \
    && ! printf '%s\n' "$got" | grep -q 'DUPLICATE' \
    && ! printf '%s\n' "$got" | grep -q 'part1'; then
    echo "PASS: list-candidate-disks (deduped, partitions skipped)"
  else
    echo "FAIL: list-candidate-disks (got: $got)"
    failures=$((failures + 1))
  fi

  # --- select_deus_vault_disks (numbered interactive selection) ---
  # 4 RAID members: OS=1, count=4, members=2 3 4 5
  PATH="$stub_dir:$PATH" DEUS_VAULT_BYID_DIR="$stub_dir/by-id" got=$(
    printf '%s\n' 1 4 2 3 4 5 | HOST=deus-vault select_deus_vault_disks
  )
  if [[ "$got" == '[ "/dev/disk/by-id/ata-WDC_OS" "/dev/disk/by-id/ata-WDC_R1" "/dev/disk/by-id/ata-WDC_R2" "/dev/disk/by-id/ata-WDC_R3" "/dev/disk/by-id/ata-WDC_R4" ]' ]]; then
    echo "PASS: select-deus-vault-disks-4-members"
  else
    echo "FAIL: select-deus-vault-disks-4-members (got '$got')"
    failures=$((failures + 1))
  fi

  # 1 RAID member: OS=1, count=1, member=2
  PATH="$stub_dir:$PATH" DEUS_VAULT_BYID_DIR="$stub_dir/by-id" got=$(
    printf '%s\n' 1 1 2 | HOST=deus-vault select_deus_vault_disks
  )
  if [[ "$got" == '[ "/dev/disk/by-id/ata-WDC_OS" "/dev/disk/by-id/ata-WDC_R1" ]' ]]; then
    echo "PASS: select-deus-vault-disks-1-member"
  else
    echo "FAIL: select-deus-vault-disks-1-member (got '$got')"
    failures=$((failures + 1))
  fi

  # bad count re-prompted (nope, 0, then 2): OS=1, members=3 4
  PATH="$stub_dir:$PATH" DEUS_VAULT_BYID_DIR="$stub_dir/by-id" got=$(
    printf '%s\n' 1 nope 0 2 3 4 | HOST=deus-vault select_deus_vault_disks 2>/dev/null
  )
  if [[ "$got" == '[ "/dev/disk/by-id/ata-WDC_OS" "/dev/disk/by-id/ata-WDC_R2" "/dev/disk/by-id/ata-WDC_R3" ]' ]]; then
    echo "PASS: select-deus-vault-disks-rejects-bad-count"
  else
    echo "FAIL: select-deus-vault-disks-rejects-bad-count (got '$got')"
    failures=$((failures + 1))
  fi

  # duplicate selection rejected (member=1 == OS, then 2): OS=1, count=1
  PATH="$stub_dir:$PATH" DEUS_VAULT_BYID_DIR="$stub_dir/by-id" got=$(
    printf '%s\n' 1 1 1 2 | HOST=deus-vault select_deus_vault_disks 2>/dev/null
  )
  if [[ "$got" == '[ "/dev/disk/by-id/ata-WDC_OS" "/dev/disk/by-id/ata-WDC_R1" ]' ]]; then
    echo "PASS: select-deus-vault-disks-rejects-duplicate"
  else
    echo "FAIL: select-deus-vault-disks-rejects-duplicate (got '$got')"
    failures=$((failures + 1))
  fi

  # out-of-range numbers re-prompted (OS=9 -> 1, member=9 -> 2)
  PATH="$stub_dir:$PATH" DEUS_VAULT_BYID_DIR="$stub_dir/by-id" got=$(
    printf '%s\n' 9 1 1 9 2 | HOST=deus-vault select_deus_vault_disks 2>/dev/null
  )
  if [[ "$got" == '[ "/dev/disk/by-id/ata-WDC_OS" "/dev/disk/by-id/ata-WDC_R1" ]' ]]; then
    echo "PASS: select-deus-vault-disks-rejects-out-of-range"
  else
    echo "FAIL: select-deus-vault-disks-rejects-out-of-range (got '$got')"
    failures=$((failures + 1))
  fi

  # count larger than the available disks is rejected (9 -> 2), members=3 4
  PATH="$stub_dir:$PATH" DEUS_VAULT_BYID_DIR="$stub_dir/by-id" got=$(
    printf '%s\n' 1 9 2 3 4 5 2 | HOST=deus-vault select_deus_vault_disks 2>/dev/null
  )
  if [[ "$got" == '[ "/dev/disk/by-id/ata-WDC_OS" "/dev/disk/by-id/ata-WDC_R2" "/dev/disk/by-id/ata-WDC_R3" ]' ]]; then
    echo "PASS: select-deus-vault-disks-rejects-too-many"
  else
    echo "FAIL: select-deus-vault-disks-rejects-too-many (got '$got')"
    failures=$((failures + 1))
  fi

  rm -rf "$stub_dir"

  # --- deus_vault_disks_from_env ---
  got=$(DEUS_VAULT_DISKS="/dev/disk/by-id/ata-OS /dev/disk/by-id/ata-R1 /dev/disk/by-id/ata-R2 /dev/disk/by-id/ata-R3 /dev/disk/by-id/ata-R4" deus_vault_disks_from_env)
  if [[ "$got" == '[ "/dev/disk/by-id/ata-OS" "/dev/disk/by-id/ata-R1" "/dev/disk/by-id/ata-R2" "/dev/disk/by-id/ata-R3" "/dev/disk/by-id/ata-R4" ]' ]]; then
    echo "PASS: env-disks-five"
  else
    echo "FAIL: env-disks-five (got '$got')"
    failures=$((failures + 1))
  fi

  got=$(DEUS_VAULT_DISKS="/dev/disk/by-id/ata-OS /dev/disk/by-id/ata-R1 /dev/disk/by-id/ata-R2" deus_vault_disks_from_env)
  if [[ "$got" == '[ "/dev/disk/by-id/ata-OS" "/dev/disk/by-id/ata-R1" "/dev/disk/by-id/ata-R2" ]' ]]; then
    echo "PASS: env-disks-three"
  else
    echo "FAIL: env-disks-three (got '$got')"
    failures=$((failures + 1))
  fi

  # env with only the OS drive (no RAID member) must be rejected
  if got=$(DEUS_VAULT_DISKS="/dev/disk/by-id/ata-OS" deus_vault_disks_from_env 2>/dev/null); then
    echo "FAIL: env-disks-rejects-no-raid-member (got '$got')"
    failures=$((failures + 1))
  else
    echo "PASS: env-disks-rejects-no-raid-member"
  fi

  if [[ $failures -gt 0 ]]; then
    echo "$failures install-args test(s) failed" >&2
    exit 1
  fi

  echo "install-args: all tests passed" > $out
''
