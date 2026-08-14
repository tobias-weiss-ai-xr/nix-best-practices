# A/B OTA updates with systemd-sysupdate
# See docs/19-appliance-images.md for details.
#
# This is the update-side configuration that complements appliance-image.nix.
# systemd-sysupdate downloads new nix-store images and UKIs from a cache server
# and writes them to the inactive A/B slot. Boot assessment auto-reverts on failure.
#
# Architecture:
#   [Cache server] --HTTP--> [sysupdate] --> [inactive slot] --> [reboot] --> [new slot]
#                                                                            |
#                                                                            v
#                                                                   [boot assessment]
#                                                                   (marks good/bad)
#                                                                            |
#                                                                   [bad → revert to old]

{ config, lib, ... }:

{
  # === Enable systemd-sysupdate ===
  systemd.sysupdate = {
    enable = true;

    # Automatic update checks
    timer = {
      OnCalendar = "daily";
      Persistent = true;
      AccuracySec = "1h";
    };

    transfers = {
      # === Nix store image (A/B slots) ===
      "10-nix-store" = {
        Source = {
          # URL to the cache server serving update artifacts
          Path = "http://cache.internal/updates/";
          Type = "url-file";
          MatchPattern = [
            "${config.system.image.id}_@v.nix-store.raw"
          ];
        };
        Target = {
          # Keep 2 instances (A/B slots)
          InstancesMax = 2;
          # Auto-detect partition
          Path = "auto";
          MatchPattern = "nix-store_@v";
          Type = "partition";
          MatchPartitionType = "linux-generic";
          # Read-only squashfs
          ReadOnly = "yes";
        };
      };

      # === UKI boot image (A/B slots) ===
      "20-boot-image" = {
        Source = {
          Path = "http://cache.internal/updates/";
          Type = "url-file";
          MatchPattern = [
            "${config.boot.uki.name}_@v.efi"
          ];
        };
        Target = {
          InstancesMax = 2;
          Path = "/EFI/Linux";
          Type = "regular-file";
          MatchPattern = "${config.boot.uki.name}_@v.efi";
        };
      };
    };
  };

  # === Boot assessment (auto-revert on failed boot) ===
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 2;
  };

  # Boot assessment configuration
  boot.bootspec = {
    enable = true;
  };

  # === Image versioning ===
  # The system.image.id and system.image.version are used in the update artifact
  # filenames. Set them in your configuration.nix:
  #
  # system.image.id = "opendesk-scs";
  # system.image.version = "24.11.1";
  #
  # Artifacts on the cache server:
  #   opendesk-scs_24.11.1.nix-store.raw
  #   opendesk-scs_24.11.1.efi
  #   SHA256SUMS

  # === Signing (optional, for verified updates) ===
  # systemd-sysupdate can verify GPG signatures:
  # systemd.sysupdate.transfers."10-nix-store".Source.Verification = {
  #   Certificate = "/etc/ssl/certs/update-ca.pem";
  # };

  # === Manual update commands ===
  # Check for updates:
  #   sysupdate check
  # Apply updates:
  #   sysupdate update
  # List installed versions:
  #   sysupdate components
  #
  # === Building update artifacts ===
  # nix build .#sysupdate-package
  # # Produces: UKI + nix-store.raw + SHA256SUMS
  # # Upload to cache server:
  # scp result/* cache.internal:/var/www/updates/
}
