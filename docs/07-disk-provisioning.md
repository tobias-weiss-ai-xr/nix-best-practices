# Declarative Disk Partitioning & Provisioning

### 3.1 disko — Declarative Disk Partitioning

**disko** replaces manual partitioning with a Nix configuration that can be
reused for identical servers, re-installation, or unattended installation.

```nix
# disko config
disko.devices = {
  disk = {
    main = {
      device = "/dev/sda";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            type = "EF00";
            size = "500M";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "crypted";
              settings = {
                allowDiscards = true;
                keyFile = "/tmp/disk-key";
              };
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "/root"    = { mountpoint = "/";     mountOptions = [ "compress=zstd" "noatime" ]; };
                  "/nix"     = { mountpoint = "/nix";  mountOptions = [ "compress=zstd" "noatime" ]; };
                  "/persist" = { mountpoint = "/persist"; mountOptions = [ "compress=zstd" "noatime" ]; };
                };
              };
            };
          };
        };
      };
    };
  };
};
```

**Supported types**: GPT, MBR, mixed; LVM, mdadm, LUKS, ZFS, bcachefs, btrfs,
ext4, tmpfs, vfat.

**disko-install** combines disko + nixos-install in one step:
```bash
disko-install --flake .#myhost --disk main /dev/sda
```

### 3.2 nixos-anywhere — Install NixOS Everywhere via SSH

**nixos-anywhere** combines disko + NixOS installation into a single SSH command:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#myhost root@192.168.1.100
```

**What it does**:
1. Connects via SSH
2. Detects or boots a NixOS installer via kexec
3. Runs disko to partition and format
4. Installs NixOS
5. Optionally copies additional files

**For air-gapped SCS**: nixos-anywhere can provision nodes via the management
network. The kexec image and NixOS closure can be served from the local binary
cache.

### 3.3 LUKS + TPM (Disk Encryption)

For SCS nodes with TPM:
```nix
boot.initrd.luks.devices."crypted" = {
  device = "/dev/disk/by-partlabel/crypted";
  allowDiscards = true;
  crypttabExtraOpts = [ "tpm2-device=auto" ];
};
```

Combined with lanzaboote (Secure Boot), this provides a full trusted boot chain.


---


---

## Additional: Provisioning with nixos-anywhere + disko (from Intel Report)

### 5.3 Provisioning with nixos-anywhere + disko

For provisioning bare-metal SCS nodes with NixOS:

```bash
# 1. Declare disk layout with disko
# 2. Provision with nixos-anyhere
nix run github:nix-community/nixos-anywhere -- \
  --flake .#myhost root@192.168.1.100
```

**disko config example**:
```nix
disko.devices.disk.main = {
  device = "/dev/sda";
  type = "disk";
  content = {
    type = "gpt";
    partitions = {
      ESP = { type = "EF00"; size = "500M"; content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; }; };
      root = { size = "100%"; content = { type = "filesystem"; format = "ext4"; mountpoint = "/"; }; };
    };
  };
};
```

**For opendesk-edu**: If SCS nodes should run NixOS as the base OS (instead of
Ubuntu/Debian), `nixos-anywhere` + `disko` provides reproducible, declarative
provisioning. The appliance image pattern (Part II.1) is an alternative for
truly immutable base OS.

