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

    mkChecks = system: let
      pkgs = mkPkgs system;
      testArgs = {inherit inputs myLib pkgs;};

      # Fast, pure evaluation checks: run on every supported system.
      fast = {
        unit = import ./tests/unit.nix testArgs;
        module-eval = import ./tests/module-eval.nix testArgs;
        disko-eval = import ./tests/disko-eval.nix testArgs;
        overlay = import ./tests/overlay.nix testArgs;
        install-args = import ./tests/install/args.nix testArgs;
      };

      # Checks tied to x86_64-linux configurations (all hosts, the home
      # configuration and the VM/integration tests are x86_64-only).
      x86Only = lib.optionalAttrs (system == "x86_64-linux") {
        host-eval = import ./tests/host-eval.nix (testArgs // {inherit self;});
        home-eval = import ./tests/home-eval.nix testArgs;

        install-app-syntax =
          pkgs.runCommand "install-app-syntax" {
            nativeBuildInputs = [pkgs.bash];
          } ''
            bash -n ${self.apps.x86_64-linux.install.program}
            echo "install app script is syntactically valid" > $out
          '';

        vm-tailscale = pkgs.testers.runNixOSTest (import ./tests/vm/tailscale.nix {
          inherit pkgs lib;
        });
        vm-network-mount = pkgs.testers.runNixOSTest (import ./tests/vm/network-mount.nix {
          inherit pkgs lib;
        });
        vm-disko-deus-vault = import ./tests/vm/disko-deus-vault.nix testArgs;
      };
    in
      fast // x86Only;
  in {
    formatter = forEachSystem (system: (mkPkgs system).alejandra);

    packages = forEachSystem (
      system:
        import ./pkgs {
          pkgs = mkPkgs system;
        }
    );

    checks = forEachSystem mkChecks;

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

      deus-vault = lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {inherit inputs myLib;};
        modules = [./hosts/deus-vault];
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

        source "${self}/scripts/install-lib.sh"
        parse_install_args "$@"

        PATH="${pkgs.nix}/bin:${pkgs.nixos-install-tools}/bin:${pkgs.coreutils}/bin:${pkgs.util-linux}/bin:$PATH"

        mount=/mnt
        disko_config="${self}/hosts/$HOST/disk-config.nix"
        disko_disks="[\"$DEVICE\"]"

        echo "[install] partitioning and mounting with disko for host '$HOST' on '$DEVICE'..."
        DISKO_SKIP_SWAP=1 ${disko}/bin/disko \
          --mode destroy,format,mount \
          --root-mountpoint "$mount" \
          --arg disks "$disko_disks" \
          --yes-wipe-all-disks \
          "$disko_config"

        if [[ "$HOST" == "horizon" ]]; then
          echo "[install] copying dotfiles into target home..."
          target="$mount/home/zero/.config/nixos/dotfiles"
          mkdir -p "$target"
          cp -r "${self}/dotfiles/." "$target/"
        fi

        echo "[install] building system closure for '$HOST'..."
        closure=$(${pkgs.nix}/bin/nix --extra-experimental-features 'nix-command flakes' build \
          --no-link \
          --no-write-lock-file \
          --print-out-paths \
          "${self}#nixosConfigurations.$HOST.config.system.build.toplevel")

        echo "[install] running nixos-install in $mount (nixos-install will chroot into the install mount)..."
        nixos-install \
          --no-channel-copy \
          --no-root-passwd \
          --system "$closure" \
          --root "$mount" \
          "''${EXTRA_ARGS[@]}"
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
