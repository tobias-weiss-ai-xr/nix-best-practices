# Source References


### Applicative Systems Repos (github.com/applicative-systems)

| Repo | Stars | Key Pattern |
|---|---|---|
| nixos-appliance-ota-update | 92 | A/B OTA via systemd-repart/sysupdate, UKI boot, squashfs store, GPG signing, TPM encryption, boot assessment |
| gcan | 27 | Nix GC root analysis (Rust), treefmt config, naersk, inputsFrom |
| vzvm | 22 | macOS Linux builder via Virtualization.framework + Rosetta, nested virtualization, /dev/kvm in guest |
| nixos-test-driver-nixcon | 18 | Advanced multi-VM integration tests: networking, custom services, X11/browser, interactive debugging |
| simple-systemd-repart-nixos-image | 16 | Minimal systemd-repart appliance images, runtime partition growth |
| mkdocs-flake | 11 | MkDocs with Nix flake |
| declarative-runtime | 10 | Declarative runtime state via OpenTofu, LoadCredential secrets, mkReconcileService, vendored providers |
| nixos-test-driver-manual | 6 | Unofficial NixOS test driver manual |
| nixos-gpu-tests | 4 | CUDA in NixOS integration tests, container-based test runner, GPU passthrough |
| nixos-image-cross-compilation-example | 4 | Cross-compiling NixOS images, extendModules for arch variants |
| sysmodule-flake | 4 | flake-parts module for auto-discovering NixOS/darwin/home-manager configs |
| nix-cuda-example | 0 | Minimal CUDA app with Nix, integration test |
| templates | 1 | Starter flake projects |
| habrawo.nix.ug | 1 | Nix user group website (Astro) |

### nix.dev Tutorials (~/git/nix.dev/source/)

| Tutorial | Key Content |
|---|---|
| install-nix.md | Multi-user, single-user, macOS, WSL2, Docker install |
| first-steps/ad-hoc-shell-environments.md | nix-shell -p, --run, --pure, -I |
| first-steps/declarative-shell.md | shell.nix, mkShellNoCC, shellHook, fetchTarball pinning |
| first-steps/reproducible-scripts.md | Shebang nix-shell, -i, -p, --pure |
| first-steps/towards-reproducibility-pinning-nixpkgs.md | fetchTarball with commit hash, channels vs pinned |
| nix-language.md | Derivations, builtins, attrsets, functions, paths, imports |
| callpackage.md | callPackage, override, callPackageWith |
| packaging-existing-software.md | mkDerivation, fetchzip, buildInputs, phases, hooks |
| cross-compilation.md | pkgsCross, buildPlatform vs hostPlatform, pkgsStatic |
| working-with-local-files.md | lib.fileset, builtins.path with name |
| module-system/deep-dive.md | evalModules, mkOption, types, mkIf, mkDefault, mkForce |
| nixos/nixos-configuration-on-vm.md | configuration.nix, boot.loader, nix-build -A vm |
| nixos/integration-testing-using-virtual-machines.md | testers.runNixOSTest, nodes, testScript, driverInteractive |
| nixos/provisioning-remote-machines.md | nixos-anywhere + disko |
| nixos/binary-cache-setup.md | nix-serve + nginx + signing keys |
| nixos/building-and-running-docker-images.md | dockerTools.buildImage, docker load |
| nixos/distributed-builds-setup.md | SSH remote builders, nix.buildMachines |
| nixos/deploying-nixos-using-terraform.md | tweag/terraform-nixos |
| concepts/flakes.md | flake.nix structure, flake.lock, pure mode, follows |
| guides/best-practices.md | Quote URLs, avoid rec/with, set config/overlays, builtins.path |
| guides/recipes/sharing-dependencies.md | inputsFrom |
| guides/recipes/dependency-management.md | npins |
| guides/recipes/continuous-integration-github-actions.md | Cachix |
| guides/recipes/direnv.md | use nix, .envrc |
| guides/recipes/post-build-hook.md | S3 cache auto-upload |
| guides/recipes/add-binary-cache.md | substituters, trusted-public-keys, extra-substituters |

### Other Sources

| Source | Content |
|---|---|
| nixos-and-flakes.thiscute.world/best-practices/intro | Best practices overview, remote deployment (colmena, nixos-rebuild), modularize configuration, binary cache hosting, NixOS flake configuration, simplify commands (Justfile) |
| nixos.org/learn | Manuals, package search, tutorials index |
| StackOverflow (top NixOS) | default.nix/shell.nix usage, upgrading to unstable, NIX_PATH errors, path types in Nix store |
| pi-memory (47 entries) | SCS K3s infrastructure, air-gap architecture, opendesk-edu deployment automation, opendesk-nix DevGuard patterns |

### opendesk Repositories

| Repo | Path | Key Files |
|---|---|---|
| opendesk-edu | ~/git/opendesk_git/opendesk-edu/ | nix/flake.nix (51+ K8s services), ansible/roles/, helmfile/ |
| opendesk-nix | ~/git/opendesk_git/opendesk-nix/ | platform/nix/ (types, security, sbom, registry, compliance, k8s, build, dev, operators, integrated-devguard, tests, nixos/containers, nixos/security, nixos/services) |

---

*Report generated from analysis of all 16 `applicative-systems` GitHub repos,
the complete nix.dev tutorial set, nixos-and-flakes best practices, StackOverflow
insights, and the opendesk-edu/opendesk-nix codebases. All code examples are
verified against the actual repository contents.*

---

## Expanded Guide Sources

## Source References

### Ecosystem Projects

| Project | URL | Key Feature |
|---|---|---|
| Attic | github.com/zhaofengli/attic | S3-compatible binary cache with dedup |
| Harmonia | github.com/nix-community/harmonia | Rust binary cache, zstd compression |
| Colmena | github.com/zhaofengli/colmena | Multi-host NixOS deployment |
| disko | github.com/nix-community/disko | Declarative disk partitioning |
| nixos-anywhere | github.com/numtide/nixos-anywhere | SSH-based NixOS provisioning |
| agenix | github.com/ryantm/agenix | age-encrypted secrets for NixOS |
| sops-nix | github.com/Mic92/sops-nix | sops-based secrets, team-friendly |
| impermanence | github.com/nix-community/impermanence | Ephemeral root storage |
| lanzaboote | github.com/nix-community/lanzaboote | UEFI Secure Boot & Measured Boot |
| flake-parts | github.com/hercules-ci/flake-parts | Modular flake organization |
| vzvm | github.com/applicative-systems/vzvm | macOS Linux builder with Rosetta |
| gcan | github.com/applicative-systems/gcan | Nix GC root analysis |
| nixos-appliance-ota-update | github.com/applicative-systems/nixos-appliance-ota-update | A/B OTA NixOS images |
| declarative-runtime | github.com/applicative-systems/declarative-runtime | Declarative runtime state via OpenTofu |
| nixos-test-driver-nixcon | github.com/applicative-systems/nixos-test-driver-nixcon | Advanced NixOS integration tests |
| Nixery | github.com/tazjin/nixery | Ad-hoc Docker registry from Nix packages |
| deploy-rs | github.com/serokell/deploy-rs | Multi-profile Nix-flake deploy |
| comin | github.com/nlewo/comin | GitOps for NixOS |
| Awesome Nix | github.com/nix-community/awesome-nix | Curated Nix ecosystem list |

### Documentation

| Source | URL | Key Content |
|---|---|---|
| nix.dev | nix.dev | Official tutorials and guides |
| NixOS Manual | nixos.org/manual/nixos/stable | NixOS reference |
| Nixpkgs Manual | nixos.org/manual/nixpkgs/stable | Nixpkgs reference (overlays, dockerTools, testers) |
| Zero to Nix | zero-to-nix.com | Determinate Systems learning resource |
| nixcademy | nixcademy.com | Blog posts on appliance images, OTA, integration tests, macOS |
| nixos.wiki | nixos.wiki | Community wiki (Flakes, Binary Cache, Impermanence) |
| Nix Pills | nixos.org/guides/nix-pills | Foundational Nix tutorial |
| nixos-and-flakes | nixos-and-flakes.thiscute.world/best-practices/intro | Best practices guide |

---

*This guide synthesizes findings from 20+ ecosystem projects, official manuals,
community wikis, blog posts, and the applicative-systems repository analysis.
All code examples are verified against actual source code.*
