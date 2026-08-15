# NixOS & Nix Best Practices for opendesk-edu on SCS K3s

A comprehensive knowledge base of NixOS/Nix best practices, patterns, and
reference implementations for building a modern, secure, scalable, and flexible
cloud stack on an air-gapped SCS K3s cluster.

## Context

- **Target platform**: SCS K3s cluster (air-gapped, HTTP proxy at
  `proxy.internal:3128`, HAProxy ingress, Ceph CSI RBD+CephFS)
- **Existing stack**: Ansible (orchestration) + Nix (pinned tooling) +
  Helmfile (K8s packages) + ArgoCD (GitOps)
- **NixOS version**: 24.11 (nixpkgs pin)
- **Consolidation**: opendesk-nix is being consolidated as the single Nix
  library (opendesk-edu/nix is deprecated)

## Repository Structure

```
nix-best-practices/
├── README.md                          # This file (master index)
├── docs/                              # Topic-focused documentation
│   ├── 01-ecosystem-overview.md       # Ecosystem tooling reference
│   ├── 02-applicative-systems.md      # Applicative Systems org analysis (16 repos)
│   ├── 03-cross-cutting-patterns.md   # 8 recurring patterns from applicative-systems
│   ├── 04-nix-curriculum.md           # 9-section nix.dev curriculum
│   ├── 05-binary-cache.md             # Attic, nix-serve, harmonia, post-build-hook
│   ├── 06-secrets-management.md       # agenix, sops-nix, systemd LoadCredential=
│   ├── 07-disk-provisioning.md        # disko, nixos-anywhere, LUKS+TPM
│   ├── 08-immutable-systems.md        # impermanence, BTRFS rollback, A/B OTA
│   ├── 09-secure-boot.md              # lanzaboote, UEFI Secure Boot, TPM
│   ├── 10-integration-testing.md      # testers.runNixOSTest, QEMU vs containers
│   ├── 11-deployment.md               # Colmena, nixos-rebuild, comin, nixinate
│   ├── 12-flake-architecture.md       # flake-parts, best practices, npins
│   ├── 13-container-images.md         # dockerTools.buildImage/buildLayeredImage
│   ├── 14-cross-compilation.md        # extendModules, pkgsCross
│   ├── 15-code-quality.md             # treefmt, nixfmt, statix, deadnix
│   ├── 16-overlays.md                 # overlays, override, overrideAttrs
│   ├── 17-remote-builds.md            # SSH builders, vzvm, distributed builds
│   ├── 18-dev-workflow.md             # direnv, reproducible scripts, CI, npins
│   ├── 19-appliance-images.md         # systemd-repart, UKI boot, A/B OTA
│   ├── 20-runtime-state.md            # declarative-runtime, OpenTofu, LoadCredential=
│   ├── 21-performance.md              # closure analysis, image size, layering
│   ├── 22-security-hardening.md       # kernel sysctl, AppArmor, auditd, Cosign, SBOM
│   ├── 23-best-practices.md           # Do/Don't tables
│   ├── 24-opendesk-architecture.md    # Current opendesk-edu/opendesk-nix state + gaps
│   ├── 25-recommendations.md          # 4 goals, migration path, priority actions
│   ├── 26-sources.md                  # All source references
│   ├── 27-new-research-findings.md    # Round 2 research (manuals, wiki, Awesome Nix)
│   └── 28-nix-integration-status.md   # Nix-spirit integration map + open gaps
└── examples/                          # Standalone Nix configuration examples
    ├── flake.nix                      # Reference flake (treefmt, checks, devShell)
    ├── treefmt.nix                    # treefmt config (nixfmt + statix + deadnix)
    ├── attic-cache.nix                # Attic binary cache (S3, post-build-hook)
    ├── agenix-secrets.nix             # agenix secrets management
    ├── disko-partition.nix            # Declarative disk partitioning (LUKS+TPM, btrfs)
    ├── integration-test.nix           # NixOS integration test (MariaDB)
    ├── appliance-image.nix            # systemd-repart image with A/B OTA
    ├── ota-update.nix                 # systemd-sysupdate A/B update config
    ├── declarative-runtime.nix        # OpenTofu reconciliation (Keycloak, Grafana)
    ├── colmena-deployment.nix         # Multi-host NixOS deployment
    ├── docker-image.nix               # dockerTools.buildLayeredImage
    ├── cross-compile.nix              # extendModules for multi-arch
    ├── remote-builder.nix             # SSH remote builder + vzvm
    └── devshell.nix                   # Dev shell with direnv
```

## Quick Start

### Find a topic

| If you want to... | Read |
|---|---|
| Set up a binary cache for air-gapped SCS | [docs/05-binary-cache.md](docs/05-binary-cache.md) |
| Manage secrets on NixOS | [docs/06-secrets-management.md](docs/06-secrets-management.md) |
| Partition disks declaratively | [docs/07-disk-provisioning.md](docs/07-disk-provisioning.md) |
| Build immutable NixOS images | [docs/19-appliance-images.md](docs/19-appliance-images.md) |
| Set up Secure Boot | [docs/09-secure-boot.md](docs/09-secure-boot.md) |
| Write integration tests | [docs/10-integration-testing.md](docs/10-integration-testing.md) |
| Deploy NixOS to multiple hosts | [docs/11-deployment.md](docs/11-deployment.md) |
| Structure a flake | [docs/12-flake-architecture.md](docs/12-flake-architecture.md) |
| Build container images with Nix | [docs/13-container-images.md](docs/13-container-images.md) |
| Cross-compile for multiple architectures | [docs/14-cross-compilation.md](docs/14-cross-compilation.md) |
| Format and lint Nix code | [docs/15-code-quality.md](docs/15-code-quality.md) |
| Set up remote builders | [docs/17-remote-builds.md](docs/17-remote-builds.md) |
| Manage runtime state (Keycloak, Grafana) | [docs/20-runtime-state.md](docs/20-runtime-state.md) |
| Harden NixOS security | [docs/22-security-hardening.md](docs/22-security-hardening.md) |
| Understand the applicative-systems patterns | [docs/02-applicative-systems.md](docs/02-applicative-systems.md) |
| Learn the nix.dev curriculum | [docs/04-nix-curriculum.md](docs/04-nix-curriculum.md) |
| See recommendations for opendesk-edu | [docs/25-recommendations.md](docs/25-recommendations.md) |

### Use an example

```bash
# Copy a flake template
cp examples/flake.nix ./flake.nix

# Copy a treefmt config
cp examples/treefmt.nix ./treefmt.nix

# Copy an integration test
cp examples/integration-test.nix ./tests/integration.nix

# Format your code
nix fmt

# Run checks
nix flake check
```

## Key Recommendations for opendesk-edu

### P0 — Immediate (Weeks 1-2)
1. Set up **Attic binary cache** on Ceph RGW ([docs/05-binary-cache.md](docs/05-binary-cache.md))
2. Add **treefmt** (nixfmt + statix + deadnix) ([docs/15-code-quality.md](docs/15-code-quality.md))
3. Add **`checks`** to the flake ([docs/10-integration-testing.md](docs/10-integration-testing.md))
4. Add **agenix** for secrets ([docs/06-secrets-management.md](docs/06-secrets-management.md))

### P1 — Foundation (Weeks 3-4)
5. Build **NixOS appliance images** with systemd-repart ([docs/19-appliance-images.md](docs/19-appliance-images.md))
6. Provision SCS nodes with **nixos-anywhere + disko** ([docs/07-disk-provisioning.md](docs/07-disk-provisioning.md))
7. Configure **distributed builds** ([docs/17-remote-builds.md](docs/17-remote-builds.md))
8. Build **container images** with dockerTools ([docs/13-container-images.md](docs/13-container-images.md))

### P2 — Advanced (Weeks 5-8)
9. Add **A/B OTA updates** with systemd-sysupdate ([docs/19-appliance-images.md](docs/19-appliance-images.md))
10. Set up **lanzaboote** Secure Boot ([docs/09-secure-boot.md](docs/09-secure-boot.md))
11. Implement **impermanence** ([docs/08-immutable-systems.md](docs/08-immutable-systems.md))
12. Adopt **declarative-runtime** for Keycloak ([docs/20-runtime-state.md](docs/20-runtime-state.md))

### P3 — Ongoing
13. Monitor nixpkgs for security updates
14. Expand integration test coverage
15. Optimize image sizes ([docs/21-performance.md](docs/21-performance.md))
16. Consider **Colmena** for multi-node deployment ([docs/11-deployment.md](docs/11-deployment.md))

## Sources

This knowledge base synthesizes findings from:

- **applicative-systems** GitHub organization (16 repos, analyzed in [docs/02-applicative-systems.md](docs/02-applicative-systems.md))
- **nix.dev** tutorials (all 9 curriculum sections, in [docs/04-nix-curriculum.md](docs/04-nix-curriculum.md))
- **nixos-and-flakes.thiscute.world** best practices
- **nixos.org** manuals (NixOS, Nixpkgs) — systemd-repart, containers, module system
- **nixos.wiki** (via Wayback) — Flakes schema, Binary Cache, Impermanence, Disko, Secure Boot
- **Zero to Nix** (Determinate Systems) — Caching, NixOS concepts
- **Awesome Nix** — 150+ ecosystem tools (deployment, CLI, dev, DevOps)
- **devops-research** corpus — sbomnix, comin, terranix, NixOS security paper
- **nixcademy** blog posts (minimizing images, container tests, macOS testing)
- **Ecosystem projects**: Attic, Harmonia, Colmena, disko, nixos-anywhere, agenix, sops-nix, impermanence, lanzaboote, flake-parts, vzvm, gcan
- **opendesk-edu** and **opendesk-nix** repositories

Full source references: [docs/26-sources.md](docs/26-sources.md)

Round 2 research findings: [docs/27-new-research-findings.md](docs/27-new-research-findings.md)

## License

Internal documentation for the opendesk-edu project.
