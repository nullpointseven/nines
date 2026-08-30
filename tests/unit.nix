# Unit tests for the pure Nix helpers in lib/utils.nix.
{
  pkgs,
  lib ? pkgs.lib,
  ...
}: let
  scanPaths = (import ../lib {inherit lib;}).scanPaths;
  helpers = import ./lib.nix {inherit pkgs lib;};
  fixtures = ./unit/fixtures;

  # scanPaths sees: a.nix (keep), default.nix (skip), not-nix.txt (skip),
  # empty/ (keep), only-default/ (keep), sub/ (keep). attrNames is sorted, so
  # the expected order is deterministic.
  expected = map (f: fixtures + "/${f}") ["a.nix" "empty" "only-default" "sub"];
in
  helpers.runUnitTests "unit" {
    testScanPathsFiltersFilesAndKeepsDirectories = {
      expr = scanPaths fixtures;
      inherit expected;
    };

    testScanPathsIsSortedAlphabetically = {
      expr = map (p: builtins.baseNameOf p) (scanPaths fixtures);
      expected = ["a.nix" "empty" "only-default" "sub"];
    };

    testScanPathsExcludesDefaultNix = {
      expr = lib.any (p: builtins.baseNameOf p == "default.nix") (scanPaths fixtures);
      expected = false;
    };

    testScanPathsExcludesNonNixFiles = {
      expr = lib.any (p: builtins.baseNameOf p == "not-nix.txt") (scanPaths fixtures);
      expected = false;
    };

    testScanPathsEmptyDirectory = {
      expr = scanPaths ./unit/fixtures/empty;
      expected = [];
    };

    testScanPathsDirWithOnlyDefaultYieldsNothingInside = {
      expr = scanPaths ./unit/fixtures/only-default;
      expected = [];
    };

    testScanPathsDiscoveredDirectoryCanBeImported = {
      expr = let
        onlyDefault = builtins.head (
          builtins.filter (p: builtins.baseNameOf p == "only-default") (scanPaths fixtures)
        );
      in
        (import onlyDefault).value;
      expected = 3;
    };

    testScanPathsScansNestedDirectoryContents = {
      expr = scanPaths ./unit/fixtures/sub;
      expected = [./unit/fixtures/sub/c.nix];
    };

    testScanPathsResultsExist = {
      expr = builtins.all (p: builtins.pathExists p) (scanPaths fixtures);
      expected = true;
    };
  }
