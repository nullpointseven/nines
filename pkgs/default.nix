{
  pkgs,
  lib ? pkgs.lib,
}: let
  callPackage = pkgs.callPackage;
in {
  # example = callPackage ./example {};
}
