# Development shell with direnv integration
# See docs/18-dev-workflow.md for details.
#
# Provides pinned tooling for opendesk-edu development.

{ pkgs, inputs, system, ... }:

let
  colmena = inputs.colmena.packages.${system}.colmena;
  agenix = inputs.agenix.packages.${system}.default;
in
{
  default = pkgs.mkShell {
    # Pinned tooling (from opendesk-edu/nix/flake.nix)
    packages = [
      # Kubernetes
      pkgs.kubectl
      pkgs.helm
      pkgs.helmfile
      pkgs.yq-go

      # Ansible orchestration
      pkgs.ansible

      # Nix tooling
      pkgs.nixfmt
      pkgs.statix
      pkgs.deadnix
      pkgs.treefmt
      pkgs.nix-output

      # Deployment
      colmena

      # Secrets
      agenix

      # Container tooling
      pkgs.docker
      pkgs.skopeo
      pkgs.cosign
      pkgs.syft  # SBOM generation

      # Development
      pkgs.git
      pkgs.jq
      pkgs.curl
      pkgs.wget
    ];

    # Environment setup
    shellHook = ''
      export KUBECONFIG=$PWD/.kube/config
      export ANSIBLE_CONFIG=$PWD/ansible/ansible.cfg
      export HELMFILE_ENV=internal

      # Attic cache (see docs/05-binary-cache.md)
      export ATTIC_SERVER=http://attic.internal:8080

      # HTTP proxy for air-gapped environment
      export HTTP_PROXY=http://www-proxy2.uni-marburg.de:3128
      export HTTPS_PROXY=http://www-proxy2.uni-marburg.de:3128
      export NO_PROXY=localhost,127.0.0.1,attic.internal,ceph-rgw.internal

      echo "opendesk-edu dev shell (SCS K3s)"
      echo "  kubectl: $(kubectl version --client --short 2>/dev/null || echo 'not found')"
      echo "  helm:    $(helm version --short 2>/dev/null || echo 'not found')"
      echo "  nix:     $(nix --version 2>/dev/null || echo 'not found')"
    '';

    # Share build dependencies with the package (from nix.dev recipes)
    # inputsFrom = [ (pkgs.callPackage ./package.nix { }) ];
  };

  # CI shell (minimal, for CI runners)
  ci = pkgs.mkShellNoCC {
    packages = [
      pkgs.nixfmt
      pkgs.statix
      pkgs.deadnix
      pkgs.treefmt
    ];
  };
}

# === .envrc (for direnv automatic activation) ===
#
# Create a .envrc file in the project root:
#   use flake
#
# Or for a specific devShell:
#   use flake .#default
#
# With nix-direnv (recommended for performance):
#   .envrc
#   use flake
#
# direnv will automatically activate the shell when you enter the directory
# and deactivate when you leave. nix-direnv caches the evaluation, so
# re-entry is instant after the first time.
