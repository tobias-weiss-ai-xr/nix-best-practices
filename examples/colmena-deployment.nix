# Colmena multi-host NixOS deployment
# See docs/11-deployment.md for details.
#
# Colmena is a stateless NixOS deployment tool with parallel deployment,
# tag-based node selection, and flake support.

{ lib, ... }:

{
  meta = {
    nixpkgs = import <nixpkgs> { system = "x86_64-linux"; };

    # Per-node nixpkgs override (optional)
    # nodeNixpkgs = {
    #   node-b = ./another-nixpkgs-checkout;
    # };
  };

  # Defaults applied to all nodes
  defaults = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [
      vim
      wget
      curl
      htop
      iotop
    ];

    # Don't overwrite unknown remote profiles by default
    # deployment.replaceUnknownProfiles = true;

    # Common NixOS settings for all SCS nodes
    networking.firewall.enable = true;
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
      };
    };

    # Binary cache (see docs/05-binary-cache.md)
    nix.settings.substituters = [ "http://attic.internal:8080" ];
    nix.settings.trusted-public-keys = [ "attic.internal:1..." ];

    # Remote builder (see docs/17-remote-builds.md)
    nix.buildMachines = [{
      hostName = "builder.internal";
      sshUser = "remotebuild";
      sshKey = "/root/.ssh/id_ed25519";
      systems = [ "x86_64-linux" ];
      maxJobs = 8;
      supportedFeatures = [ "kvm" "big-parallel" ];
    }];
    nix.distributedBuilds = true;
    nix.settings.builders-use-substitutes = true;
  };

  # === Individual nodes ===

  scs-node-06 = { name, nodes, ... }: {
    networking.hostName = "scs-node-06";
    networking.interfaces.ens3.ipv4.addresses = [{
      address = "10.0.0.6";
      prefixLength = 24;
    }];

    imports = [
      ./modules/binary-cache.nix
      ./modules/secrets.nix
      ./modules/appliance-image.nix
    ];

    deployment = {
      targetHost = "scs-node-06.internal";
      targetPort = 22;
      buildOnTarget = false;  # build locally, copy closure
    };

    # K3s agent
    services.k3s = {
      enable = true;
      role = "agent";
      server = "https://k3s-server.internal:6443";
      tokenFile = "/run/agenix/k3s-token";
    };
  };

  scs-node-07 = { name, nodes, ... }: {
    networking.hostName = "scs-node-07";
    networking.interfaces.ens3.ipv4.addresses = [{
      address = "10.0.0.7";
      prefixLength = 24;
    }];

    imports = [
      ./modules/binary-cache.nix
      ./modules/secrets.nix
      ./modules/appliance-image.nix
    ];

    deployment = {
      targetHost = "scs-node-07.internal";
      targetPort = 22;
      buildOnTarget = false;
    };

    services.k3s = {
      enable = true;
      role = "agent";
      server = "https://k3s-server.internal:6443";
      tokenFile = "/run/agenix/k3s-token";
    };
  };

  # === Tag-based deployment ===
  # Deploy to all nodes tagged "k3s-agent":
  #   colmena apply --on @k3s-agent
  #
  # Deploy to a specific node:
  #   colmena apply --on scs-node-06
  #
  # Build without deploying:
  #   colmena build
  #
  # Evaluate without building:
  #   colmena eval
}

# === Alternative: nixos-rebuild (single host) ===
#
# nixos-rebuild switch --flake .#scs-node-06
# nixos-rebuild switch --flake .#scs-node-06 --target-host root@scs-node-06
# nixos-rebuild test --flake .#scs-node-06    # test without switching
# nixos-rebuild build --flake .#scs-node-06   # build only
