# SSH remote builder configuration
# See docs/17-remote-builds.md for details.
#
# Offload builds to a dedicated build machine inside the air-gapped network.
# All SCS nodes and dev machines use it as a remote builder.

{ config, pkgs, lib, ... }:

{
  # === Client configuration (on each SCS node and dev machine) ===
  nix.buildMachines = [{
    hostName = "builder.internal";
    sshUser = "remotebuild";
    sshKey = "/root/.ssh/id_ed25519";
    systems = [ "x86_64-linux" "aarch64-linux" ];
    maxJobs = 8;
    speedFactor = 2;
    supportedFeatures = [ "kvm" "nixos-test" "big-parallel" "cuda" ];
    mandatoryFeatures = [ ];
  }];

  nix.distributedBuilds = true;

  # Use the remote builder's substituters (e.g., Attic cache)
  nix.settings.builders-use-substitutes = true;

  # === Builder configuration (on the build machine) ===
  # Create the remotebuild user:
  # useradd -m -s /bin/bash remotebuild
  # mkdir -p /home/remotebuild/.ssh
  # echo "ssh-ed25519 AAA..." >> /home/remotebuild/.ssh/authorized_keys
  #
  # Add to trusted-users in nix.conf or configuration.nix:
  # nix.settings.trusted-users = [ "remotebuild" ];

  # === macOS Linux builder via vzvm (for Apple Silicon developers) ===
  # On macOS:
  # nix.linux-builder = {
  #   enable = true;
  #   package = pkgs.darwin.linux-builder-vz;
  #   systems = [ "aarch64-linux" "x86_64-linux" ];  # x86_64 via Rosetta
  # };
  #
  # Advantages over QEMU:
  #   - 2.54x faster x86_64 builds (Rosetta vs TCG)
  #   - Nested virtualization (/dev/kvm in guest → can run nixosTests)
  #   - Predictable boot (12s vs 0.1-31.5s)
  #   - Smaller closure (~1.2 GiB vs ~3.2 GiB)

  # === Air-gapped build offloading ===
  #
  # Architecture:
  #   [Dev machines] --SSH--> [Build machine] --push--> [Attic cache]
  #        |                      |                           |
  #        +---pull---------------+---pull--------------------+
  #
  # 1. Dedicated build machine with high CPU/RAM inside the air-gapped network
  # 2. All SCS nodes and dev machines use it as a remote builder
  # 3. Built paths are pushed to the Attic binary cache (S3-backed via Ceph)
  # 4. All nodes pull from the Attic cache
}
