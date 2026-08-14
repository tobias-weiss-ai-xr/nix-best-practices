# Reference flake.nix for opendesk-edu on SCS K3s
# Combines patterns from applicative-systems repos and nix.dev best practices.
#
# Features:
#   - treefmt formatter (nixfmt + statix + deadnix)
#   - checks (eval-only + integration tests)
#   - NixOS configurations with appliance image support
#   - Container images via dockerTools
#   - DevShell with pinned tooling
#   - Binary cache (Attic) configuration
#   - agenix secrets
#   - disko disk partitioning
#
# See docs/ for detailed guides on each topic.

{
  description = "opendesk-edu Nix configuration for SCS K3s";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Secrets
    agenix.url = "github:ryantm/agenix";

    # Disk partitioning
    disko.url = "github:nix-community/disko";

    # NixOS deployment
    colmena.url = "github:zhaofengli/colmena";

    # Formatter
    treefmt-nix.url = "github:numtide/treefmt-nix";

    # Follows
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    colmena.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {

      systems = [ "x86_64-linux" "aarch64-linux" ];

      flake = {
        # NixOS configurations (see examples/colmena-deployment.nix)
        nixosConfigurations = {
          scs-node = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              ./configuration.nix
              inputs.disko.nixosModules.disko
              inputs.agenix.nixosModules.default
            ];
          };
        };

        # Reusable NixOS modules
        nixosModules = {
          binary-cache = import ./modules/binary-cache.nix;
          secrets = import ./modules/secrets.nix;
          secure-boot = import ./modules/secure-boot.nix;
          appliance-image = import ./modules/appliance-image.nix;
        };

        # Overlays
        overlays.default = import ./overlay.nix;
      };

      perSystem = { pkgs, system, ... }:
        let
          treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
        in {
          # Formatter
          formatter = treefmtEval.config.build.wrapper;

          # Dev shell with pinned tooling
          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              kubectl
              helm
              helmfile
              ansible
              yq-go
              colmena.packages.${system}.colmena
              inputs.agenix.packages.${system}.default
            ];
            shellHook = ''
              export KUBECONFIG=$PWD/.kube/config
              export ANSIBLE_CONFIG=$PWD/ansible/ansible.cfg
              echo "opendesk-edu dev shell (SCS K3s)"
            '';
          };

          # Container images (see examples/docker-image.nix)
          packages = {
            mariadb = pkgs.callPackage ./packages/mariadb.nix { };
            postgresql = pkgs.callPackage ./packages/postgresql.nix { };
            redis = pkgs.callPackage ./packages/redis.nix { };
          };

          # Checks (see examples/integration-test.nix)
          checks = {
            # Eval-only check (fast)
            eval-scs-node = self.nixosConfigurations.scs-node.config.system.build.toplevel;

            # Integration test
            integration = pkgs.testers.runNixOSTest ./tests/integration.nix;

            # Formatting check
            formatting = treefmtEval.config.build.check self;
          };
        };
    };
}
