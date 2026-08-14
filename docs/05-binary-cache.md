# Binary Cache Architecture for Air-Gapped Environments

### 1.1 Three Binary Cache Solutions Compared

| Feature | nix-serve | **Attic** | **Harmonia** |
|---|---|---|---|
| Language | Perl | Rust | Rust |
| Storage | Local nix store | S3-compatible (dedup) | Local /nix/store |
| Deduplication | No | Global (NAR + chunk store) | No |
| Signing | On-the-fly | Server-side (user doesn't need key) | On-the-fly |
| Multi-tenancy | No | Yes (mutually untrusting tenants) | No |
| Scalability | Single machine | Serverless-ready (fly.io), replicable | Single machine |
| GC | Manual | LRU-based | Manual |
| Compression | No | No (NAR format) | zstd |
| TLS | Via nginx | Via nginx | Built-in or nginx |
| NixOS module | `services.nix-serve` | `services.atticd` | `services.harmonia` |

**Recommendation for air-gapped SCS**: **Attic** is the best choice because:
- **S3-compatible storage** can use the existing Ceph cluster (RBD or CephFS via S3 gateway)
- **Global deduplication** saves storage in air-gapped environments where bandwidth is precious
- **Server-side signing** means build machines don't need the signing key (security win)
- **Multi-tenancy** allows separate caches for different teams/environments
- **LRU garbage collection** automatically cleans up unused paths

### 1.2 Attic Setup (Recommended)

```nix
# On the cache server (inside the air-gapped network):
services.atticd = {
  enable = true;
  settings = {
    listen = "0.0.0.0:8080";
    database.url = "postgres:///atticd";
    storage = {
      type = "s3";
      region = "local";
      endpoint = "http://rook-ceph-rgw:8080";  # Ceph RGW
      bucket = "nix-cache";
    };
    chunking = {
      nar-size-threshold = 128 * 1024;  # 128 KiB
      min-size = 64 * 1024;               # 64 KiB
      max-size = 4 * 1024 * 1024;         # 4 MiB
    };
  };
};
```

**Client configuration on SCS nodes**:
```nix
nix.settings.substituters = [ "http://attic.internal:8080" ];
nix.settings.trusted-public-keys = [ "attic.internal:..." ];
# If behind the HTTP proxy:
networking.proxy.httpProxy = "http://proxy.internal:3128";
```

### 1.3 nix-serve (Simplest, for Small Setups)

```nix
services.nix-serve = {
  enable = true;
  listenAddress = "0.0.0.0";
  port = 5000;
  secretKeyFile = "/var/cache-priv-key.pem";  # nix-store --generate-binary-cache-key
};
services.nginx.virtualHosts."cache.internal" = {
  locations."/" = { proxyPass = "http://127.0.0.1:5000"; };
};
```

### 1.4 Harmonia (Rust, Fast, Simple)

```nix
services.harmonia.enable = true;
services.harmonia.signKeyPaths = [ "/var/lib/secrets/harmonia.secret" ];
# With sops-nix for key management:
# services.harmonia.signKeyPaths = [ config.sops.secrets.harmonia-key.path ];
# sops.secrets.harmonia-key = { };
```

### 1.5 Post-Build Hook (Auto-Upload to Cache)

```nix
nix.settings.post-build-hook = "/run/current-system/bin/upload-to-cache";
# upload-to-cache script:
# #!/bin/sh
# set -eu
# exec ${pkgs.attic}/bin/attic push internal $OUT_PATHS
```

### 1.6 Binary Cache Priority

```nix
# Lower priority = preferred (default is 41 for cache.nixos.org)
nix.settings.substituters = [
  "http://attic.internal:8080?priority=10"  # internal cache first
  "https://cache.nixos.org"                   # fallback (via proxy)
];
nix.settings.trusted-public-keys = [
  "attic.internal:..."
  "cache.nixos.org-1:6NCHdD59X431o0gWypbMrrURJU2NMxYfSY0..."  # official
];
```


---


---

## Additional: Binary Cache for Air-Gapped SCS (from Intel Report)

### 5.1 Binary Cache for Air-Gapped SCS

**Problem**: The SCS K3s cluster is air-gapped with an HTTP proxy
(`proxy.internal:3128`). Nix cannot reach `cache.nixos.org` directly.
Binary caches must be self-hosted or proxied.

**Solution**: Self-hosted `nix-serve` + nginx + signing keys (from nix.dev
`binary-cache-setup.md`), combined with the post-build-hook pattern for
automatic upload.

**Architecture**:
```
[Build machine] --nix-build--> [nix-serve cache] --HTTP--> [SCS K3s nodes]
       |                              |
       +--post-build-hook-------------+
```

**Build machine config**:
```nix
# Sign and upload
nix.settings.post-build-hook = "/run/current-system/bin/upload-to-cache";
# nix-serve on the cache host:
services.nix-serve = {
  enable = true;
  listenAddress = "0.0.0.0";
  port = 5000;
  secretKeyFile = "/var/cache-priv-key.pem";
};
services.nginx.virtualHosts."cache.example.com" = {
  locations."/" = { proxyPass = "http://127.0.0.1:5000"; };
};
# Generate keys:
# nix-store --generate-binary-cache-key cache.example.com pub.pem priv.pem
```

**SCS K3s node config**:
```nix
nix.settings.substituters = [ "http://cache.internal:5000" ];
nix.settings.trusted-public-keys = [ "cache.internal:..." ];
# If proxy is required:
nix.settings.extra-substituters = [ "http://cache.internal:5000" ];
# HTTP proxy for fetching from the cache:
networking.proxy.httpProxy = "http://proxy.internal:3128";
```

**Alternative**: If NixOS is not the base OS on K3s nodes (they run K3s on
whatever Linux), use `dockerTools.buildImage` to build container images with
Nix and push to the local registry. The opendesk-edu stack already uses Helmfile
+ ArgoCD, so Nix-built container images can integrate directly.

