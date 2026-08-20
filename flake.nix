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
      disko = inputs.disko.packages.${system}.disko;
      installScript = pkgs.writeShellScriptBin "install" ''
        set -euo pipefail

        PATH="${pkgs.nix}/bin:${pkgs.nixos-install-tools}/bin:${pkgs.coreutils}/bin:${pkgs.util-linux}/bin:$PATH"

        host="''${INSTALL_HOST:-horizon}"
        device="/dev/nvme0n1"
        extra_args=("$@")

        # Parse optional positional host/device arguments.
        # Usage: install [HOST] [DEVICE] [nixos-install flags...]
        # If the first non-flag arg starts with /dev it is the device and the host stays at the default.
        if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
          if [[ "$1" =~ ^/dev ]]; then
            device="$1"
            extra_args=("''${@:2}")
          else
            host="$1"
            if [[ $# -gt 1 && ! "$2" =~ ^- ]]; then
              device="$2"
              extra_args=("''${@:3}")
            else
              extra_args=("''${@:2}")
            fi
          fi
        fi

        mount=/mnt
        disko_config="${self}/hosts/''${host}/disk-config.nix"
        disko_disks="[\"$device\"]"

        echo "[install] partitioning and mounting with disko for host '$host' on '$device'..."
        DISKO_SKIP_SWAP=1 ${disko}/bin/disko \
          --mode destroy,format,mount \
          --root-mountpoint "$mount" \
          --arg disks "$disko_disks" \
          --yes-wipe-all-disks \
          "$disko_config"

        if [[ "$host" == "horizon" ]]; then
          echo "[install] copying dotfiles into target home..."
          target="$mount/home/zero/.config/nixos/dotfiles"
          mkdir -p "$target"
          cp -r "${self}/dotfiles/." "$target/"
        fi

        echo "[install] building system closure for '$host'..."
        closure=$(${pkgs.nix}/bin/nix --extra-experimental-features 'nix-command flakes' build \
          --no-link \
          --no-write-lock-file \
          --print-out-paths \
          "${self}#nixosConfigurations.''${host}.config.system.build.toplevel")

        echo "[install] running nixos-install in $mount (nixos-install will chroot into the install mount)..."
        nixos-install \
          --no-channel-copy \
          --no-root-passwd \
          --system "$closure" \
          --root "$mount" \
          "''${extra_args[@]}"
      '';
    in {
      install = {
        type = "app";
        program = "${installScript}/bin/install";
        meta = {
          description = "Install a NixOS host: disko partitions/mounts, then nixos-install chroots and installs";
          mainProgram = "install";
        };
      };
    });
  };
}
