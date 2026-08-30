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

  if [[ $failures -gt 0 ]]; then
    echo "$failures install-args test(s) failed" >&2
    exit 1
  fi

  echo "install-args: all tests passed" > $out
''
