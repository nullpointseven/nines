{
  pkgs,
  lib ? pkgs.lib,
  stateVersion ? "26.05",
}: let
  # The complete NixOS module list so that `evalModules` understands every
  # option the custom modules under `modules/nixos` set (services.*,
  # users.users.*, ...).
  nixosModuleList = import "${pkgs.path}/nixos/modules/module-list.nix";
in {
  # Evaluate a list of NixOS modules with the full NixOS option set and
  # strict checking (`_module.check` throws on options that are defined but
  # never declared, catching typos and wiring regressions).
  evalNixOS = modules:
    lib.evalModules {
      modules =
        [
          {
            _module.args.pkgs = lib.mkDefault pkgs;
            nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
            system.stateVersion = stateVersion;
          }
        ]
        ++ nixosModuleList
        ++ modules;
    };

  # Wrap `lib.runTests` (a list of `{ expr, expected }` cases) into a check
  # derivation that fails the build when any case fails.
  runUnitTests = name: tests: let
    failures = lib.runTests tests;
    testNames = builtins.attrNames tests;
  in
    pkgs.runCommand "${name}-tests" {} (
      if failures == []
      then "echo '${name}: all ${toString (builtins.length testNames)} tests passed' > $out"
      else
        throw ''
          ${name} failed:
          ${builtins.toJSON failures}
        ''
    );

  # Test helper for cases that are expected to fail evaluation.
  # Usage: testThrows (builtins.seq expr "did not throw")
  testThrows = expr: {
    expr = builtins.tryEval expr;
    expected = {
      success = false;
      value = false;
    };
  };
}
