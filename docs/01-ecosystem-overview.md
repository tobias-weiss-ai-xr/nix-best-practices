# Ecosystem Tooling Reference

### 19.1 Binary Cache

| Tool | Type | Key Feature |
|---|---|---|
| **Attic** | Self-hosted | S3-compatible, global dedup, multi-tenancy, server-side signing |
| **Harmonia** | Self-hosted | Rust, fast, serves /nix/store directly, zstd compression, built-in TLS |
| **nix-serve** | Self-hosted | Simplest, Perl, on-the-fly signing |
| **Cachix** | Hosted | Cloud-hosted, CI integration, free for open source |
| **Nixery** | Ad-hoc | Builds Docker images on-demand from Nix packages |

### 19.2 Deployment

| Tool | Type | Key Feature |
|---|---|---|
| **Colmena** | NixOS deployment | Stateless, parallel, tag-based, flakes |
| **nixos-rebuild** | NixOS deployment | Standard, simple, single-host |
| **nixos-anywhere** | Provisioning | SSH-based, kexec, disko integration |
| **deploy-rs** | NixOS deployment | Multi-profile, flake-native |
| **comin** | GitOps | Continuously pulls from Git, rebuilds |
| **Nixinate** | NixOS deployment | Flake-based, SSH |
| **terraform-nixos** | Terraform | Deploy NixOS via Terraform |
| **KubeNix** | Kubernetes | K8s resource builder using Nix |

### 19.3 Secrets

| Tool | Encryption | Key Type | Storage |
|---|---|---|---|
| **agenix** | age | SSH Ed25519/RSA | Encrypted .age in Nix store |
| **sops-nix** | sops | GPG or age | Encrypted sops files, multiple formats |
| **LoadCredential=** | None | None | Runtime files (complement to above) |

### 19.4 Disk & Provisioning

| Tool | Purpose |
|---|---|
| **disko** | Declarative disk partitioning (GPT, MBR, LVM, LUKS, ZFS, btrfs) |
| **nixos-anywhere** | SSH-based NixOS provisioning with disko |
| **disko-install** | Combined disko + nixos-install in one step |
| **impermanence** | Ephemeral root, persistent state declaration |
| **lanzaboote** | UEFI Secure Boot & Measured Boot |

### 19.5 Testing

| Tool | Purpose |
|---|---|
| **testers.runNixOSTest** | NixOS integration tests (QEMU VMs) |
| **Container tests** | systemd-nspawn-based tests (25% faster, no KVM) |
| **driverInteractive** | Interactive debugging of test scripts |
| **overrideTestDerivation** | Add requiredSystemFeatures to tests |

### 19.6 Formatting & Quality

| Tool | Purpose |
|---|---|
| **treefmt** | Multi-language formatter runner |
| **nixfmt** | Official Nix code formatter |
| **statix** | Nix linter with auto-fix |
| **deadnix** | Dead code removal for Nix |
| **alejandra** | Opinionated Nix formatter (alternative to nixfmt) |
| **nix-diff** | Explain why two derivations differ |

### 19.7 Development

| Tool | Purpose |
|---|---|
| **direnv** + **nix-direnv** | Automatic shell activation |
| **flake-parts** | Modular flake organization |
| **npins** | Non-flake source pinning |
| **nh** | Better CLI for nix/nixos-rebuild |
| **comma** | Run any binary with `nix run` |
| **manix** | Search NixOS option docs |
| **devenv** | Nix-based dev environments |
| **vzvm** | macOS Linux builder with Rosetta |

### 19.8 Image Building

| Tool | Purpose |
|---|---|
| **systemd-repart** | Declarative partition images |
| **systemd-sysupdate** | A/B OTA updates |
| **dockerTools.buildImage** | Build Docker/OCI images with Nix |
| **dockerTools.buildLayeredImage** | Layered Docker images (better caching) |
| **dockerTools.streamLayeredImage** | Stream directly to docker load |
| **nixos-generators** | Build multiple image formats from one config |
| **nixos-appliance-ota-update** | Reference for A/B OTA appliance images |


---

