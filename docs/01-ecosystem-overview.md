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
| **nix2container** | Efficient container building (alternative to dockerTools) |
| **compose2nix** | Generate NixOS config from Docker Compose |

### 19.9 Additional Ecosystem Tools (Round 2 Research)

| Tool | Category | Purpose |
|---|---|---|
| **bento** | Deployment | KISS NixOS fleet management |
| **Clan** | Deployment | P2P deployment with built-in secrets and networking |
| **morph** | Deployment | NixOS fleet management (legacy) |
| **Nixlets** | Kubernetes | Helm-like tool using only Nix (Kubenix under the hood) |
| **KuberNix** | Kubernetes | Single-dependency K8s clusters via Nix |
| **nixidy** | GitOps | Kubernetes GitOps with Nix and Argo CD |
| **terranix** | IaC | Nix-based Terraform/OpenTofu JSON generator |
| **sbomnix** | Security | SBOM, provenance, dependency graph, vulnerability tools for Nix |
| **bsf** | Security | Developer-centric supply chain security (SLSA) |
| **MCP-NixOS** | AI | MCP server for NixOS package/option search |
| **nix-health** | CI | Project-specific Nix health checks in flake.nix |
| **nix-output-monitor** | Dev | Build graphs and statistics during derivations |
| **nix-tree** | Dev | Interactive dependency graph browser |
| **nvd** | Dev | Diff package versions between NixOS generations |
| **nix-init** | Dev | Generate Nix packages from URLs with hash prefetching |
| **nurl** | Dev | Generate Nix fetcher calls from repository URLs |
| **nix-diff** | Dev | Explain why two Nix derivations differ |
| **nix-du** | Dev | Visualise GC roots to free store space |
| **angrr** | Dev | Auto Nix GC Roots Retention (delete old roots by mtime) |
| **optnix** | Dev | Terminal-based options searcher for Nix modules |
| **nixos-cli** | Dev | All-in-one CLI for common NixOS tools |
| **nixpkgs-hammering** | Quality | Opinionated linter for Nixpkgs expressions |
| **pre-commit-hooks.nix** | Quality | Run linters/formatters at commit time and in CI |
| **nil** | Editor | Nix Language Server (incremental analysis) |
| **nixd** | Editor | Nix language server (based on Nix libraries) |
| **rnix-lsp** | Editor | Syntax-checking language server for Nix |
| **Arion** | Containers | Run docker-compose with Nix/NixOS |
| **extra-container** | Containers | Run declarative NixOS containers from CLI |
| **microvm.nix** | VMs | NixOS-based MicroVMs |
| **nixos-shell** | VMs | Simple headless VM config (like Vagrant) |
| **agent-sandbox.nix** | Security | Declarative sandboxing with bubblewrap/sandbox-exec |
| **robotnix** | Mobile | Declarative Android (AOSP) build system |
| **Devbox** | Dev | Instant, portable, predictable dev environments |
| **flox** | Dev | Manage and share dev environments |
| **Snowfall Lib** | Flake | Opinionated flake management library |
| **flakelight** | Flake | Modular flake framework minimizing boilerplate |
| **Conflake** | Flake | Convention-based flake.nix framework |
| **dream2nix** | Packaging | Auto-convert packages from other build systems |
| **Nix GitLab CI** | CI | Define GitLab CI pipelines in pure Nix |
| **Standard** | Framework | Opinionated Nix Flakes framework for large projects |

---

