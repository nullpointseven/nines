# Tests for the overlay in overlays/default.nix, which adds an `unstable`
# package set (nixos-unstable) to the package set.
{
  pkgs,
  lib ? pkgs.lib,
  inputs,
  ...
}: let
  helpers = import ./lib.nix {inherit pkgs lib;};
  runUnitTests = helpers.runUnitTests;

  overlay = import ../overlays {inherit inputs;};
  final = overlay pkgs pkgs;
in
  runUnitTests "overlay" {
    testOverlayAddsUnstableAttr = {
      expr = final ? unstable;
      expected = true;
    };

    testOverlayUnstableIsAPackageSet = {
      expr = final.unstable ? hello;
      expected = true;
    };

    testOverlayUnstableHelloIsPackage = {
      expr = final.unstable.hello.pname or final.unstable.hello.name or "";
      expected = "hello";
    };

    testOverlayUnstableDiffersFromStable = {
      expr = final.unstable.hello.outPath != pkgs.hello.outPath;
      expected = true;
    };

    testOverlayTakesInputsArg = {
      expr = lib.isFunction (import ../overlays);
      expected = true;
    };
  }
