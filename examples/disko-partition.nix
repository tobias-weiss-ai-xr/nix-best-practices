# Declarative disk partitioning with disko
# See docs/07-disk-provisioning.md for details.
#
# disko provides declarative disk partitioning: GPT, MBR, LVM, LUKS, ZFS, btrfs.
# Combined with nixos-anywhere for SSH-based provisioning.

{ ... }:

{
  disko.devices = {
    disk = {
      main = {
        device = "/dev/sda";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            # EFI System Partition
            ESP = {
              size = "500M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            # LUKS-encrypted root
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted";
                # TPM2-bound encryption (see docs/09-secure-boot.md)
                settings = {
                  allowDiscards = true;
                  passwordFile = "/tmp/disko-password";
                };
                # Fallback: key file
                # keyFile = "/tmp/disko-key";
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ];
                  subvolumes = {
                    "/root" = {
                      mountpoint = "/";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "/home" = {
                      mountpoint = "/home";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "/nix" = {
                      mountpoint = "/nix";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "/var" = {
                      mountpoint = "/var";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "/persist" = {
                      mountpoint = "/persist";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  # Mount /persist for impermanence (see docs/08-immutable-systems.md)
  fileSystems."/persist" = {
    neededForBoot = true;
  };
}

# === Provisioning with nixos-anywhere ===
#
# 1. Generate a disko config (this file)
# 2. Run nixos-anywhere to install:
#    nix run github:nix-community/nixos-anywhere -- \
#      --flake .#scs-node --disk-encryption-password \
#      root@192.168.1.100
#
# Or with a disko config file:
#    nix run github:nix-community/nixos-anywhere -- \
#      --disko ./disko-config.nix \
#      --flake .#scs-node \
#      root@192.168.1.100
#
# === disko-install (combined disko + nixos-install) ===
#
#    nix run github:nix-community/disko -- \
#      --mode install,format \
#      --flake .#scs-node \
#      /dev/sda
