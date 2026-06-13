{
  pkgs,
  lib,
  ...
}: {
  programs.firefox = {
    enable = true;

    languagePacks = ["en-US"];

    policies = {
      # Updates & Background Services
      AppAutoUpdate = false;
      BackgroundAppUpdate = false;

      # Feature Disabling
      DisableFirefoxStudies = true;
      DisableFirefoxAccounts = true;
      DisableForgetButton = true;
      DisableMasterPasswordCreation = true;
      DisableProfileImport = true;
      DisableProfileRefresh = true;
      DisableSetDesktopBackground = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DisableFormHistory = true;

      # Access Restrictions
      BlockAboutConfig = false;
      BlockAboutProfiles = true;
      BlockAboutSupport = true;

      # UI and Behavior
      DisplayMenuBar = "never";
      DontCheckDefaultBrowser = true;
      HardwareAcceleration = true;
      OfferToSaveLogins = false;
      DefaultDownloadDirectory = "$HOME/Downloads";

      # Extensions
      ExtensionSettings = let
        moz = short: "https://addons.mozilla.org/firefox/downloads/latest/${short}/latest.xpi";
      in {
        "*".installation_mode = "blocked";

        "uBlock0@raymondhill.net" = {
          install_url = moz "ublock-origin";
          installation_mode = "force_installed";
          private_browsing = true;
        };

        "{f3b4b962-34b4-4935-9eee-45b0bce58279}" = {
          install_url = moz "animated-purple-moon-lake";
          installation_mode = "force_installed";
          private_browsing = true;
        };

        "{73a6fe31-595d-460b-a920-fcc0f8843232}" = {
          install_url = moz "noscript";
          installation_mode = "force_installed";
          private_browsing = true;
        };

        "tridactyl.vim@cmcaine.co.uk" = {
          install_url = moz "tridactyl-vim";
          installation_mode = "force_installed";
          private_browsing = true;
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          install_url = moz "bitwarden-password-manager";
          installation_mode = "force_installed";
          private_browsing = true;
        };
        "{74145f27-f039-47ce-a470-a662b129930a}" = {
          install_url = moz "clearurls";
          installation_mode = "force_installed";
          private_browsing = true;
        };
        "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}" = {
          install_url = moz "violentmonkey";
          installation_mode = "force_installed";
          private_browsing = true;
        };
        "{9063c2e9-e07c-4c2c-9646-cfe7ca8d0498}" = {
          install_url = moz "old-reddit-redirect";
          installation_mode = "force_installed";
          private_browsing = true;
        };
        "jid1-xUfzOsOFlzSOXg@jetpack" = {
          install_url = moz "reddit-enhancement-suite";
          installation_mode = "force_installed";
          private_browsing = true;
        };

        # Extension configuration
        "3rdparty".Extensions = {
          "uBlock0@raymondhill.net".adminSettings = {
            userSettings = rec {
              uiTheme = "dark";
              uiAccentCustom = true;
              uiAccentCustom0 = "#8300ff";
              cloudStorageEnabled = lib.mkForce false;

              importedLists = [
                "https:#filters.adtidy.org/extension/ublock/filters/3.txt"
                "https:#github.com/DandelionSprout/adfilt/raw/master/LegitimateURLShortener.txt"
              ];

              externalLists = lib.concatStringsSep "\n" importedLists;
            };

            selectedFilterLists = [
              "CZE-0"
              "adguard-generic"
              "adguard-annoyance"
              "adguard-social"
              "adguard-spyware-url"
              "easylist"
              "easyprivacy"
              "https:#github.com/DandelionSprout/adfilt/raw/master/LegitimateURLShortener.txt"
              "plowe-0"
              "ublock-abuse"
              "ublock-badware"
              "ublock-filters"
              "ublock-privacy"
              "ublock-quick-fixes"
              "ublock-unbreak"
              "urlhaus-1"
            ];
          };
        };
      };

      profiles.default.search = {
        force = true;
        default = "ddg";
        privateDefault = "ddg";

        engines = {
          "Nix Packages" = {
            urls = [
              {
                template = "https://search.nixos.org/packages";
                params = [
                  {
                    name = "channel";
                    value = "unstable";
                  }
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["@np"];
          };

          "Nix Options" = {
            urls = [
              {
                template = "https://search.nixos.org/options";
                params = [
                  {
                    name = "channel";
                    value = "unstable";
                  }
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["@no"];
          };

          "NixOS Wiki" = {
            urls = [
              {
                template = "https://wiki.nixos.org/w/index.php";
                params = [
                  {
                    name = "search";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = ["@nw"];
          };
        };
      };

      profiles.default.containers = {
        Personal = {
          id = 1;
          color = "blue";
          icon = "fingerprint";
        };
        Programming = {
          id = 2;
          color = "turquoise";
          icon = "fingerprint";
        };
        Work = {
          id = 3;
          color = "orange";
          icon = "briefcase";
        };
        Social = {
          id = 4;
          color = "green";
          icon = "chill";
        };
        Entertainment = {
          id = 5;
          color = "purple";
          icon = "vacation";
        };
        Shopping = {
          id = 6;
          color = "pink";
          icon = "cart";
        };
      };
    };
  };
}
