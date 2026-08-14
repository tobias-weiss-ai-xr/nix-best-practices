# NixOS appliance image with systemd-repart
# See docs/19-appliance-images.md for details.
#
# Builds a bootable NixOS appliance image with:
#   - UKI (Unified Kernel Image) boot via systemd-boot
#   - Squashfs read-only nix-store partition
#   - A/B OTA update slots via systemd-sysupdate
#   - Runtime partition growth via systemd-repart in initrd

{ modulesPath, pkgs, config, lib, ... }:

let
  efiArch = lib.removeSuffix "-linux" config.nixpkgs.hostPlatform.system;
in
{
  imports = [
    (modulesPath + "/image/repart.nix")
    (modulesPath + "/profiles/image-based-appliance.nix")
  ];

  # === Image definition ===
  image.repart = {
    name = config.system.image.id;
    split = true;  # Separate nix-store image for A/B updates

    partitions = {
      # EFI System Partition (boot)
      esp = {
        contents = {
          "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
            "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
          "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
            "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
        };
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          Label = "boot";
          SizeMinBytes = "200M";
          SplitName = "-";
        };
      };

      # Nix store (read-only squashfs, A/B updateable)
      nix-store = {
        storePaths = [ config.system.build.toplevel ];
        nixStorePrefix = "/";
        repartConfig = {
          Type = "linux-generic";
          Format = "squashfs";
          ReadOnly = "yes";
          Label = "nix-store_${config.system.image.version}";
          SizeMinBytes = "2G";
          SizeMaxBytes = "2G";
          SplitName = "nix-store";
        };
      };

      # Root (writable, grows at runtime)
      root.repartConfig = {
        Type = "root";
        Format = "ext4";
        Label = "root";
        SizeMinBytes = "5G";
        SizeMaxBytes = "5G";
        SplitName = "-";
      };
    };
  };

  # === A/B OTA updates via systemd-sysupdate ===
  systemd.sysupdate = {
    enable = true;

    transfers = {
      # Nix store image (A/B slots)
      "10-nix-store" = {
        Source = {
          Path = "http://cache.internal/";
          Type = "url-file";
          MatchPattern = [ "${config.system.image.id}_@v.nix-store.raw" ];
        };
        Target = {
          InstancesMax = 2;  # A/B slots
          Path = "auto";
          MatchPattern = "nix-store_@v";
          Type = "partition";
          MatchPartitionType = "linux-generic";
          ReadOnly = "yes";
        };
      };

      # UKI boot image (A/B slots)
      "20-boot-image" = {
        Source = {
          MatchPattern = [ "${config.boot.uki.name}_@v.efi" ];
        };
        Target = {
          InstancesMax = 2;
          Path = "/EFI/Linux";
          Type = "regular-file";
        };
      };
    };
  };

  # === Boot assessment (auto-revert on failed boot) ===
  boot.loader.systemd-boot = {
    enable = true;
    # Try new slot, revert to previous if it fails
    configurationLimit = 2;
  };

  # === Runtime partition growth (home, var) ===
  boot.initrd.systemd.repart.enable = true;
  boot.initrd.systemd.repart.device = "/dev/sda";

  systemd.repart.partitions = {
    home = {
      Format = "ext4";
      Label = "home";
      Type = "home";
      Weight = 2000;
    };
    var = {
      Format = "ext4";
      Label = "var";
      Type = "var";
      Weight = 1000;
    };
  };

  # === sysupdate-package (distribution artifact) ===
  # Bundles UKI + nix-store image + SHA256SUMS
  system.build.sysupdate-package = pkgs.runCommand "sysupdate-package-${config.system.image.version}" { } ''
    mkdir $out
    cp ${config.system.build.uki}/${config.system.boot.loader.ukiFile} $out/
    cp ${config.system.build.image}/${config.system.image.id}_${config.system.image.version}.nix-store.raw $out/
    cd $out
    sha256sum * > SHA256SUMS
  '';
}
