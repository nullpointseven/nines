# Evaluation tests for the home-manager configuration (home-manager/home.nix
# and modules/home/*). Uses the same `homeManagerConfiguration` machinery as
# the flake, then asserts on the evaluated config. Nothing is built, but
# forcing `config.home.packages` still catches broken package references.
{
  pkgs,
  lib ? pkgs.lib,
  inputs,
  myLib,
  ...
}: let
  helpers = import ./lib.nix {inherit pkgs lib;};
  runUnitTests = helpers.runUnitTests;

  hm = inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = pkgs;
    extraSpecialArgs = {
      inherit inputs myLib;
    };
    modules = [../home-manager/home.nix];
  };

  packages = hm.config.home.packages;
  pnames = builtins.map (p: p.pname or p.name or "") packages;
in
  runUnitTests "home-eval" {
    testHomeUsername = {
      expr = hm.config.home.username;
      expected = "zero";
    };

    testHomeStateVersion = {
      expr = hm.config.home.stateVersion;
      expected = "26.05";
    };

    testFirefoxEnabled = {
      expr = hm.config.programs.firefox.enable;
      expected = true;
    };

    testFirefoxDisablesTelemetry = {
      expr = hm.config.programs.firefox.policies.DisableTelemetry;
      expected = true;
    };

    testFirefoxBlocksExtensionInstallationByDefault = {
      expr = hm.config.programs.firefox.policies.ExtensionSettings."*".installation_mode;
      expected = "blocked";
    };

    testFirefoxForceInstallsExtensions = {
      expr = let
        ext = hm.config.programs.firefox.policies.ExtensionSettings;
      in {
        ublock = ext."uBlock0@raymondhill.net".installation_mode;
        noscript = ext."{73a6fe31-595d-460b-a920-fcc0f8843232}".installation_mode;
        tridactyl = ext."tridactyl.vim@cmcaine.co.uk".installation_mode;
      };
      expected = {
        ublock = "force_installed";
        noscript = "force_installed";
        tridactyl = "force_installed";
      };
    };

    testFirefoxExtensionsAllowedInPrivateBrowsing = {
      expr = let
        ext = hm.config.programs.firefox.policies.ExtensionSettings;
      in {
        ublock = ext."uBlock0@raymondhill.net".private_browsing;
        sponsorblock = ext."sponsorBlocker@ajay.app".private_browsing;
      };
      expected = {
        ublock = true;
        sponsorblock = true;
      };
    };

    testFirefoxDefaultSearchEngine = {
      expr = hm.config.programs.firefox.profiles.default.search.default;
      expected = "ddg";
    };

    testFirefoxSearchEnginesDefined = {
      expr = let
        engines = hm.config.programs.firefox.profiles.default.search.engines;
      in
        builtins.attrNames engines;
      expected = ["Nix Options" "Nix Packages" "NixOS Wiki"];
    };

    testFirefoxHasSixContainers = {
      expr = let
        containers = hm.config.programs.firefox.profiles.default.containers;
      in
        builtins.attrNames containers;
      expected = ["Entertainment" "Personal" "Programming" "Shopping" "Social" "Work"];
    };

    testGitConfigured = {
      expr = let
        settings = hm.config.programs.git.settings;
      in {
        name = settings.user.name;
        email = settings.user.email;
        aliases = settings.alias;
      };
      expected = {
        name = "nullpointseven";
        email = "82100519+nullpointseven@users.noreply.github.com";
        aliases = {
          ci = "commit";
          co = "checkout";
          s = "status";
        };
      };
    };

    testUdiskieServiceEnabled = {
      expr = hm.config.services.udiskie.enable;
      expected = true;
    };

    testMprisProxyServiceEnabled = {
      expr = hm.config.services.mpris-proxy.enable;
      expected = true;
    };

    testHomePackagesIncludeCoreTools = {
      expr = let
        present = builtins.filter (n: builtins.elem n ["libreoffice" "mpv-with-scripts" "zathura-with-plugins" "tmux" "waybar"]) pnames;
      in
        builtins.sort (a: b: a < b) present;
      expected = builtins.sort (a: b: a < b) ["libreoffice" "mpv-with-scripts" "tmux" "waybar" "zathura-with-plugins"];
    };

    testHomePackagesIncludeCustomInputPackage = {
      expr = builtins.elem "freesmlauncher" pnames;
      expected = true;
    };

    testHomePackagesNonEmpty = {
      expr = builtins.length packages > 0;
      expected = true;
    };
  }
