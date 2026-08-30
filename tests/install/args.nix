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

  # --- disko_disks_json ---
  run_json() {
    local name="$1" expected="$2"
    shift 2
    local out
    if out=$(disko_disks_json "$@" 2>/dev/null); then
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

  run_json "json-single" '["/dev/sda"]' /dev/sda
  run_json "json-five" '["/dev/sda","/dev/sdb","/dev/sdc","/dev/sdd","/dev/sde"]' /dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde
  run_json "json-by-id" '["/dev/disk/by-id/ata-FOO","/dev/disk/by-id/ata-BAR"]' /dev/disk/by-id/ata-FOO /dev/disk/by-id/ata-BAR

  # invalid: not an absolute /dev path
  if got=$(disko_disks_json "sda" 2>/dev/null); then
    echo "FAIL: json-rejects-relative-path (got '$got')"
    failures=$((failures + 1))
  else
    echo "PASS: json-rejects-relative-path"
  fi

  # invalid: embedded quote
  if got=$(disko_disks_json '/dev/sd"a' 2>/dev/null); then
    echo "FAIL: json-rejects-quote (got '$got')"
    failures=$((failures + 1))
  else
    echo "PASS: json-rejects-quote"
  fi

  # --- select_deus_vault_disks (interactive disk identification) ---
  stub_dir=$(mktemp -d)
  # avoid a heredoc: alejandra re-indents Nix string contents and would
  # break the <<EOF terminator; /bin/sh shebang: /usr/bin/env is absent
  # in the Nix build sandbox
  printf '%s\n' \
    '#!/bin/sh' \
    "echo 'NAME SIZE MODEL SERIAL TRAN PATH MOUNTPOINTS'" \
    "echo 'sda  4T   WDC   WD40 FOO  /dev/sda '" \
    "echo 'sdb  4T   WDC   WD40 BAR  /dev/sdb '" > "$stub_dir/lsblk"
  chmod +x "$stub_dir/lsblk"
  PATH="$stub_dir:$PATH" got=$(
    printf '%s\n' \
      /dev/disk/by-id/ata-OS \
      /dev/disk/by-id/ata-R1 \
      /dev/disk/by-id/ata-R2 \
      /dev/disk/by-id/ata-R3 \
      /dev/disk/by-id/ata-R4 |
      HOST=deus-vault select_deus_vault_disks
  )
  if [[ "$got" == '["/dev/disk/by-id/ata-OS","/dev/disk/by-id/ata-R1","/dev/disk/by-id/ata-R2","/dev/disk/by-id/ata-R3","/dev/disk/by-id/ata-R4"]' ]]; then
    echo "PASS: select-deus-vault-disks"
  else
    echo "FAIL: select-deus-vault-disks (got '$got')"
    failures=$((failures + 1))
  fi
  rm -rf "$stub_dir"

  if [[ $failures -gt 0 ]]; then
    echo "$failures install-args test(s) failed" >&2
    exit 1
  fi

  echo "install-args: all tests passed" > $out
''
