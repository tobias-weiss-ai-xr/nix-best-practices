# Attic binary cache for air-gapped SCS K3s
# See docs/05-binary-cache.md for details.
#
# Attic is recommended over nix-serve and harmonia for air-gapped environments
# because it supports S3-compatible storage (Ceph RGW), global deduplication,
# multi-tenancy, and server-side signing.

{ config, pkgs, lib, ... }:

{
  # === Attic server (on the cache host inside the air-gapped network) ===
  services.atticd = {
    enable = true;

    # Use S3-compatible storage (Ceph RGW in SCS)
    settings = {
      listen = "0.0.0.0:8080";

      # S3 backend (Ceph RGW)
      storage = {
        type = "s3";
        region = "local";
        endpoint = "http://ceph-rgw.internal:7480";
        bucket = "nix-cache";
      };

      # Compression
      compression = {
        type = "zstd";
        level = 9;
      };

      # Garbage collection
      garbage-collection = {
        interval = "12 hours";
        default-retention-period = "30 days";
      };

      # Signing
      database.url = "postgresql:///atticd?host=/run/postgresql";
    };
  };

  # === Client configuration (on all SCS nodes and build machines) ===
  nix.settings = {
    substituters = [
      "http://attic.internal:8080"
      # Keep cache.nixos.org as fallback (via proxy)
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "attic.internal:1思考hM3H+gZj0WfP9xyz="
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
    # Lower priority = preferred (default is 41 for cache.nixos.org)
    extra-substituters = [
      "http://attic.internal:8080?priority=10"
    ];
  };

  # === HTTP proxy for initial cache.nixos.org pull-through ===
  networking.proxy = {
    httpProxy = "http://www-proxy2.uni-marburg.de:3128";
    httpsProxy = "http://www-proxy2.uni-marburg.de:3128";
    noProxy = "localhost,127.0.0.1,attic.internal,ceph-rgw.internal";
  };

  # === Post-build hook: auto-upload to Attic ===
  nix.settings.post-build-hook = "/run/current-system/bin/upload-to-attic";

  systemd.services.upload-to-attic = {
    description = "Upload built paths to Attic cache";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "upload-to-attic" ''
        set -eu
        # $OUT_PATHS is set by nix-daemon
        ${pkgs.attic}/bin/attic push internal $OUT_PATHS
      '';
    };
  };

  # === Alternative: nix-serve (simpler, for small setups) ===
  # services.nix-serve = {
  #   enable = true;
  #   listenAddress = "0.0.0.0";
  #   port = 5000;
  #   secretKeyFile = "/var/cache-priv-key.pem";
  # };
  # # Generate keys:
  # # nix-store --generate-binary-cache-key cache.internal pub.pem priv.pem
}
