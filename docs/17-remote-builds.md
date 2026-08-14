# Remote Builds & Distributed Build Infrastructure

### 13.1 SSH Remote Builders (from nix.dev distributed-builds)

```nix
nix.buildMachines = [{
  hostName = "builder.example.com";
  sshUser = "remotebuild";
  sshKey = "/root/.ssh/id_ed25519";
  systems = [ "x86_64-linux" "aarch64-linux" ];
  maxJobs = 4;
  speedFactor = 2;
  supportedFeatures = [ "kvm" "nixos-test" "big-parallel" "cuda" ];
  mandatoryFeatures = [ ];
}];
nix.distributedBuilds = true;
nix.settings.builders-use-substitutes = true;
```

**Setup on the builder**:
```bash
# Create the remotebuild user
useradd -m remotebuild
# Add the public key to authorized_keys
mkdir -p /home/remotebuild/.ssh
echo "ssh-ed25519 AAA..." >> /home/remotebuild/.ssh/authorized_keys
# Ensure nix-daemon accepts builds from the user
# (add to trusted-users in nix.conf or configuration.nix)
```

### 13.2 vzvm — macOS Linux Builder (from applicative-systems)

For Apple Silicon developers:
```nix
nix.linux-builder = {
  enable = true;
  package = pkgs.darwin.linux-builder-vz;
  systems = [ "aarch64-linux" "x86_64-linux" ];  # x86_64 via Rosetta
};
```

**Advantages over QEMU**:
- 2.54x faster x86_64 builds (Rosetta vs TCG)
- Nested virtualization (/dev/kvm in guest → can run nixosTests)
- Predictable boot (12s vs 0.1-31.5s)
- Smaller closure (~1.2 GiB vs ~3.2 GiB)

### 13.3 Build Offloading for Air-Gapped SCS

In the air-gapped SCS environment:
1. **Dedicated build machine** inside the air-gapped network with high CPU/RAM
2. All SCS nodes and dev machines use it as a remote builder
3. Built paths are pushed to the Attic binary cache (S3-backed via Ceph)
4. All nodes pull from the Attic cache

```nix
# On each SCS node:
nix.buildMachines = [{
  hostName = "builder.internal";
  sshUser = "remotebuild";
  sshKey = "/etc/ssh/ssh_host_ed25519_key";
  systems = [ "x86_64-linux" ];
  maxJobs = 8;
  supportedFeatures = [ "kvm" "big-parallel" ];
}];
nix.distributedBuilds = true;
nix.settings.builders-use-substitutes = true;
nix.settings.substituters = [ "http://attic.internal:8080" ];
nix.settings.trusted-public-keys = [ "attic.internal:..." ];
```


---


---

## Additional: Distributed Builds (from Intel Report)

### 5.2 Distributed Builds

For building large closures (e.g., the full opendesk-edu service catalog) on a
more powerful machine:

```nix
nix.buildMachines = [{
  hostName = "builder.example.com";
  sshUser = "remotebuild";
  sshKey = "/root/.ssh/id_ed25519";
  systems = [ "x86_64-linux" ];
  maxJobs = 4;
  speedFactor = 2;
  supportedFeatures = [ "kvm" "nixos-test" "big-parallel" ];
}];
nix.distributedBuilds = true;
nix.settings.builders-use-substitutes = true;
```

**For opendesk-edu**: If builds are too slow on the development machine, a
dedicated build machine (or the vzvm macOS Linux builder for Apple Silicon
devs) can be used as a remote builder.

