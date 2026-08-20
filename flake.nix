{
  description = "Nullpointseven NixOS and Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    freesmlauncher = {
      url = "github:FreesmTeam/FreesmLauncher";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    inherit (nixpkgs) lib;
    myLib = import ./lib {inherit lib;};

    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    forEachSystem = lib.genAttrs systems;

    mkPkgs = system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
  in {
    formatter = forEachSystem (system: (mkPkgs system).alejandra);

    packages = forEachSystem (
      system:
        import ./pkgs {
          pkgs = mkPkgs system;
        }
    );

    nixosConfigurations = {
      horizon = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs myLib;};
        modules = [./hosts/horizon];
      };

      servitor = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs myLib;};
        modules = [./hosts/servitor];
      };
    };

    homeConfigurations = {
      "zero@horizon" = inputs.home-manager.lib.homeManagerConfiguration {
        pkgs = mkPkgs "x86_64-linux";
        extraSpecialArgs = {inherit inputs myLib;};
        modules = [./home-manager/home.nix];
      };
    };

    apps = lib.genAttrs ["x86_64-linux"] (system: let
      pkgs = mkPkgs system;
      installScript = pkgs.writeShellScriptBin "install" ''
        set -euo pipefail
        host="''${INSTALL_HOST:-horizon}"
        device="/dev/nvme0n1"
        if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
          device="$1"
          shift
        fi
        extraArgs=()
        if [ "$host" = "horizon" ]; then
          extraArgs+=(--extra-files ${self}/dotfiles /home/zero/.config/nixos/dotfiles)
        fi
        exec ${inputs.disko.packages.${system}.disko-install}/bin/disko-install \
          --write-efi-boot-entries \
          --flake ${self}#"$host" \
          --disk main "$device" \
          "''${extraArgs[@]}" \
          "$@"
      '';
    in {
      install = {
        type = "app";
        program = "${installScript}/bin/install";
        meta = {
          description = "Install a NixOS host with disko-formatting from the NixOS installer";
          mainProgram = "install";
        };
      };
    });
  };
}
