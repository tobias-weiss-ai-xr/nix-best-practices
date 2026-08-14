# New Research Findings: NixOS & Nix Ecosystem Deep Dive

> Research round 2 — synthesizing findings from nixos.org manuals, nix.dev
> tutorials, nixos.wiki (via Wayback), Zero to Nix, Awesome Nix, Nixpkgs
> manual, devops-research corpus, and additional community sources.

---

## 1. NixOS Manual Highlights (nixos.org/manual/nixos/stable)

### 1.1 Building Images via systemd-repart

The NixOS manual documents `systemd-repart` as an official image building
method alongside `nixos-rebuild build-image`. Key points:

- `image.repart` configuration allows defining partition layouts declaratively
- Supports `Minimize="guess"` for automatic partition sizing
- Can produce UKI (Unified Kernel Image) bootable images
- Works with `systemd-sysupdate` for A/B OTA updates
- This is the same mechanism used by `applicative-systems/nixos-appliance-ota-update`

### 1.2 Container Management

NixOS has built-in declarative container support:

```nix
containers.webserver = {
  autoStart = true;
  privateNetwork = true;
  hostAddress = "192.168.100.10";
  localAddress = "192.168.100.11";
  config = { config, pkgs, ... }: {
    services.nginx.enable = true;
  };
};
```

- Containers run as systemd-nspawn namespaces
- Can be configured declaratively in `configuration.nix`
- Support for private networking, bind mounts, and forwarded ports
- **Relevance to opendesk-edu**: Could replace some K8s-level abstractions
  for simpler services

### 1.3 NixOS Module System (from manual examples)

The manual provides 34 numbered examples covering:

- `mkEnableOption` / `mkPackageOption` patterns
- Extensible types with `types.anything`
- Submodule patterns (list, attrset, freeform)
- Type checking and overriding
- `extendNixOS` in `passthru.tests` for test coherence

### 1.4 Service Management

NixOS services are systemd units managed declaratively:

- `systemctl status` shows NixOS-managed services
- `systemctl list-units --type=service` for overview
- Services can be stopped/started/restarted via systemctl
- `systemctl reboot` vs `nixos-rebuild boot` for updates

### 1.5 Cleaning the Nix Store

- `nix-collect-garbage -d` removes old generations
- `nix.optimise.automatic = true` for automatic store optimisation
- `boot.loader.systemd-boot.configurationLimit` limits boot entries

---

## 2. nixos.wiki Findings (via Wayback Machine)

### 2.1 Flakes — Detailed Schema

The nixos.wiki Flakes page provides the complete output schema with all
attribute types:

```nix
{
  self, ... }@inputs: {
  checks."<system>"."<name>" = derivation;           # nix flake check
  packages."<system>"."<name>" = derivation;          # nix build .#<name>
  packages."<system>".default = derivation;           # nix build .
  apps."<system>"."<name>" = { type = "app"; program = "..."; };  # nix run
  formatter."<system>" = derivation;                  # nix fmt
  legacyPackages."<system>"."<name>" = derivation;    # nix build .#<name>
  overlays."<name>" = final: prev: { };               # consumed by other flakes
  nixosModules."<name>" = { config, ... }: { };       # NixOS modules
  nixosConfigurations."<hostname>" = { };             # nixos-rebuild switch --flake
  devShells."<system>"."<name>" = derivation;         # nix develop .#<name>
  hydraJobs."<attr>"."<system>" = derivation;         # Hydra CI
  templates."<name>" = { path = "..."; description = "..."; };  # nix flake init
}
```

**Key warnings from the wiki:**
- **Encryption WARNING**: Contents of flake files are copied to the
  world-readable Nix store — never put unencrypted secrets in flake files
- **Git WARNING**: Only files in the git working tree are copied to the store —
  always `git add` new files before building
- `nixConfig` attribute in `flake.nix` can extend `nix.conf` settings
  (e.g., binary cache configuration)

### 2.2 Binary Cache — nix-serve Setup

Detailed nix-serve setup from the wiki:

```nix
# /etc/nixos/configuration.nix (cache server)
services.nix-serve = {
  enable = true;
  secretKeyFile = "/var/cache-priv-key.pem";
};

services.nginx = {
  enable = true;
  recommendedProxySettings = true;
  virtualHosts."binarycache.example.com" = {
    locations."/".proxyPass = "http://${config.services.nix-serve.bindAddress}:${toString config.services.nix-serve.port}";
  };
};
```

```nix
# Client configuration
nix = {
  settings = {
    substituters = [
      "http://binarycache.example.com"
      "https://cache.nixos.org/"
    ];
    trusted-public-keys = [
      "binarycache.example.com-1:dsafdafDFW123fdasfa123124FADSAD"
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ];
  };
};
```

**Key details:**
- Key generation: `nix-store --generate-binary-cache-key <hostname> <priv-key> <pub-key>`
- nix-serve defaults to port 5000
- nginx reverse proxy recommended (IPv6 support, HTTPS)
- `nix-cache-info` endpoint returns `StoreDir`, `WantMassQuery`, `Priority`
- `.narinfo` files contain `Sig:` lines for signed packages

### 2.3 Impermanence — Detailed Configuration

The wiki provides a complete impermanence setup with both system-level and
home-manager-level persistence:

```nix
{ config, pkgs, ... }:
let
  impermanence = builtins.fetchTarball
    "https://github.com/nix-community/impermanence/archive/master.tar.gz";
in {
  imports = [ "${impermanence}/nixos.nix" ];

  environment.persistence."/nix/persist/system" = {
    hideMounts = true;
    directories = [
      "/var/log"
      "/var/lib/bluetooth"
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/etc/NetworkManager/system-connections"
      { directory = "/var/lib/colord"; user = "colord"; group = "colord"; mode = "u=rwx,g=rx,o="; }
    ];
    files = [
      "/etc/machine-id"
      { file = "/etc/nix/id_rsa"; parentDirectory = { mode = "u=rwx,g=,o="; }; }
    ];
  };
}
```

**Key warnings:**
- When setting up impermanence, declare a user password — the NixOS installer
  declares passwords imperatively, which won't survive a tmpfs root
- `/home/user` must be on a separate tmpfs for home-manager impermanence
  (otherwise `fuse: mountpoint not empty` error)
- `hideMounts = true` prevents the bind mounts from showing in `mount` output

### 2.4 Disko — Declarative Disk Partitioning

The wiki shows disko with GPT partitioning and bcachefs:

```nix
{ disks ? [ "/dev/vda" ], ... }: {
  disko.devices = {
    disk = {
      vdb = {
        device = builtins.elemAt disks 0;
        type = "disk";
        content = {
          type = "table";
          format = "gpt";
          partitions = [
            {
              name = "ESP";
              start = "1MiB";
              end = "500MiB";
              bootable = true;
              content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
            }
            {
              name = "root";
              start = "500MiB";
              end = "100%";
              part-type = "primary";
              content = { type = "filesystem"; format = "bcachefs"; mountpoint = "/"; };
            }
          ];
        };
      };
    };
  };
}
```

**Usage:**
- `sudo nix run github:nix-community/disko -- --mode zap_create_mount ./disko-config.nix`
- Integrates with NixOS flake: `disko.nixosModules.disko` + `./disko-config.nix`
- Disko auto-generates `fileSystems` entries — remove manually generated ones
  from `hardware-configuration.nix`

### 2.5 Secure Boot — Lanzaboote

From the wiki:
- Lanzaboote has two components: `lzbt` (signs and installs boot files on ESP)
  and `stub` (UEFI application that loads kernel and initrd)
- Requires UEFI mode + systemd-boot enabled
- Check with `bootctl status`
- **Recommendation**: Enable BIOS password and full disk encryption alongside
  Secure Boot to prevent attacks against UEFI

---

## 3. Zero to Nix (Determinate Systems) — Key Concepts

### 3.1 Caching

- Nix uses **binary caches** (remote Nix stores over HTTP) to avoid rebuilding
- Default cache: `cache.nixos.org`
- Check local store first → check binary cache → build from scratch
- **FlakeHub Cache** mentioned as a binary cache service
- Store path format: `/nix/store/<hash>-<name>`
- Without caching, Nix would build everything from scratch every time

### 3.2 NixOS Concepts

- **Generations**: Each `nixos-rebuild switch` creates an atomic generation
- **Atomic updates**: Packages installed/upgraded atomically
- **Rollbacks**: `nixos-rebuild switch --rollback` returns to previous generation
- **Multi-user support**: Different users can use different package versions
  (e.g., different git versions) because everything lives in `/nix/store`
- **Module anatomy**: `{ lib, config, pkgs, ... }: { imports = []; config = {}; options = {}; }`
- NixOS stores everything in `/nix/store`, not `/bin` or `/usr/bin`

---

## 4. Nixpkgs Manual — Overlays & dockerTools

### 4.1 Overlays

The Nixpkgs manual documents overlays as the standard way to customize packages:

```nix
# Standard overlay pattern
final: prev: {
  example = prev.example.overrideAttrs (old: {
    ...
  });
}
```

Key examples from the manual (90+ numbered examples):
- `pkgs.zlib.override {}` — override package attributes
- `pkgs.buildEmscriptenPackage {}` — custom build systems
- `dockerTools.buildImage` — Docker image building
- `dockerTools.buildLayeredImage` — layered Docker images
- `dockerTools.streamLayeredImage` — streaming layered images
- `dockerTools.pullImage` — pulling from registries
- `dockerTools.exportImage` — exporting Docker images
- `dockerTools.fakeNss` — fake NSS for container images
- `buildNixShellImage` / `streamNixShellImage` — Nix shell images
- `mkBinaryCache` — copy package closure to another machine
- `testers.runNixOSTest` — NixOS integration tests
- `testers.shellcheck` / `testers.shfmt` — shell script testing

### 4.2 dockerTools Examples

The manual lists 19+ dockerTools examples including:
- Building Docker images with `runAsRoot`, `extraCommands`
- Setting creation date
- Building layered Docker images
- Streaming layered Docker images (memory-efficient)
- Exploring layers in built images
- Pulling from default and specific registries
- Finding digest and hash for `dockerTools.pullImage`
- Exporting and importing Docker images
- Using environment helpers with buildImage/buildLayeredImage
- Using `shadowSetup` for user configuration
- Building `buildNixShellImage` with build environment
- Creating OCI runtime containers
- Building Portable Service images

---

## 5. Awesome Nix — Ecosystem Projects (New Findings)

### 5.1 Deployment Tools (Complete List)

| Tool | Description |
|---|---|
| **bento** | KISS deployment tool for NixOS fleet management |
| **Clan** | Peer-to-peer deployment with built-in secrets and networking |
| **Colmena** | Stateless NixOS deployment (modeled after NixOps/morph) |
| **comin** | Continuous Git pull deployment for NixOS (968★) |
| **deploy-rs** | Multi-profile Nix-flake deploy tool |
| **krops** | Lightweight NixOS deployment toolkit |
| **KubeNix** | Kubernetes resource builder using Nix |
| **KuberNix** | Single-dependency Kubernetes clusters via Nix |
| **morph** | NixOS fleet management |
| **Nixery** | Docker-compatible registry building images ad-hoc via Nix |
| **Nixinate** | Nix flake library for SSH-based NixOS management |
| **Nixlets** | Helm-like tool using only Nix (Kubenix under the hood) |
| **NixOps** | Official Nix deployment tool (AWS, Hetzner, etc.) |
| **pushnix** | Push NixOS config and trigger rebuild via SSH |
| **terraform-nixos** | Terraform modules for NixOS deployment |
| **terranix** | Nix-based Terraform JSON generator (505★) |

### 5.2 Command-Line Tools (Key New Findings)

| Tool | Description |
|---|---|
| **alejandra** | Opinionated Nix formatter optimized for speed |
| **angrr** | Auto Nix GC Roots Retention — delete old GC roots by mtime |
| **comma** | Run any binary (wraps `nix run` + `nix-index`) |
| **deadnix** | Scan Nix files for dead code |
| **devenv** | Nix-based dev shell environments (Cachix) |
| **dix** | Diff Nix — fast diff tool for Nix-related things |
| **manix** | Find config options and function docs for Nixpkgs/NixOS/HM |
| **nh** | Better output for nix/nixos-rebuild/home-manager CLI |
| **nix-alien** | Run unpatched binaries on Nix/NixOS |
| **nix-diff** | Explain why two Nix derivations differ |
| **nix-du** | Visualise which GC roots to delete to free store space |
| **nix-index** | Quickly locate packages with specific files |
| **nix-init** | Generate Nix packages from URLs with hash prefetching |
| **nix-melt** | Ranger-like flake.lock viewer |
| **nix-output-monitor** | Graphs and statistics during builds |
| **nix-tree** | Interactively browse dependency graph |
| **nixfmt** | Official Nix code formatter (used in Nixpkgs) |
| **nixos-cli** | All-in-one CLI for common NixOS tools |
| **nixpkgs-hammering** | Opinionated linter for Nixpkgs expressions |
| **nurl** | Generate Nix fetcher calls from repository URLs |
| **nvd** | Diff package versions between store paths (NixOS generations) |
| **optnix** | Terminal-based options searcher for Nix modules |
| **statix** | Linter/fixer for Nix code antipatterns |

### 5.3 Development Tools

| Tool | Description |
|---|---|
| **Arion** | Run docker-compose with Nix/NixOS |
| **attic** | Multi-tenant Nix Binary Cache |
| **cached-nix-shell** | Cached nix-shell for faster subsequent shells |
| **Cachix** | Hosted binary cache service (free for OSS) |
| **compose2nix** | Generate NixOS config from Docker Compose |
| **Conflake** | Convention-based flake.nix framework |
| **Devbox** | Instant, portable, predictable dev environments |
| **devshell** | mkShell with extra bits and TOML config |
| **dream2nix** | Auto-convert packages from other build systems to Nix |
| **flake-edit** | Edit flake inputs from CLI |
| **flake-utils-plus** | Lightweight Nix library for NixOS flake config |
| **flake-utils** | Pure Nix flake utility functions |
| **flake.parts** | Minimal Nix modules framework for Flakes |
| **flakelight** | Modular flake framework minimizing boilerplate |
| **flox** | Manage and share dev environments |
| **gitignore.nix** | .gitignore integration for Nix |
| **haumea** | Filesystem-based module system for Nix |
| **lorri** | Better nix-shell for development (augments direnv) |
| **make-shell** | mkShell meets modules — modular drop-in replacement |
| **MCP-NixOS** | MCP server providing AI assistants with NixOS package/option data |
| **namaka** | Snapshot testing for Nix (based on haumea) |
| **nil** | Nix Language Server (incremental analysis) |
| **niv** | Easy dependency management with package pinning |
| **nix2container** | Efficient container building workflow with Nix |
| **nix-direnv** | Fast loader and flake-compliant direnv integration |
| **nix-health** | Check health of Nix install with project-specific checks |
| **nix-oci** | flake-parts module for minimal OCI containers via nix2container |
| **nix-update** | Update versions/source hashes of Nix packages |
| **nixd** | Nix language server (based on Nix libraries) |
| **nixpkgs-review** | Verify Nixpkgs PRs build properly |
| **npins** | Simple dependency management (Niv alternative) |
| **pre-commit-hooks.nix** | Run linters/formatters at commit time and in CI |
| **rnix-lsp** | Syntax-checking language server for Nix |
| **robotnix** | Declarative and reproducible Android (AOSP) build system |
| **services-flake** | NixOS-like service config framework for Nix flakes |
| **Snowfall Lib** | Opinionated flake management library |
| **treefmt-nix** | Format all project files with a single command via .nix |

### 5.4 DevOps Tools

| Tool | Description |
|---|---|
| **Nix GitLab CI** | Define GitLab CI pipelines in pure Nix |
| **nixidy** | Kubernetes GitOps with Nix and Argo CD |
| **Standard** | Opinionated Nix Flakes framework for large projects |

### 5.5 Virtualisation

| Tool | Description |
|---|---|
| **agent-sandbox.nix** | Declarative sandboxing using bubblewrap/sandbox-exec |
| **extra-container** | Run declarative NixOS containers from command line |
| **microvm.nix** | NixOS-based MicroVMs |
| **nixos-shell** | Simple headless VM config using Nix (like Vagrant) |

---

## 6. NixOS Manual — Additional Configuration Topics

From the NixOS manual table of contents, notable service modules relevant to
cloud infrastructure:

| Service | Relevance |
|---|---|
| **Kubernetes Administration** | NixOS has built-in K8s module support |
| **Keycloak** | Native NixOS module for Keycloak (relevant to opendesk-edu) |
| **Forgejo** | Native NixOS module for Forgejo (Git server) |
| **PostgreSQL** | Native NixOS module with TLS and replication |
| **Redis** | Native NixOS module |
| **Nextcloud** | Native NixOS module |
| **Prometheus exporters** | Native NixOS monitoring support |
| **Goss** | Native NixOS service health checking |
| **Cert Spotter** | Certificate transparency monitoring |
| **Flatpak** | Containerized application support |
| **TigerBeetle** | Financial accounting database |
| **FoundationDB** | Distributed database |
| **BorgBackup** | Deduplicating backup |
| **TPM2** | Trusted Platform Module support |
| **SSL/TLS Certificates with ACME** | Let's Encrypt integration |
| **NixOS Facter** | Hardware detection (replacing `nixos-generate-config`) |
| **Container Management** | systemd-nspawn declarative containers |
| **NixOS Tests** | Built-in integration testing framework |
| **Modular Services** | Service module composition patterns |

---

## 7. nix.dev Troubleshooting & FAQ (New Findings)

### 7.1 Troubleshooting Tips

| Problem | Solution |
|---|---|
| Binary cache down/unreachable | `--option substitute false` |
| Force re-check of binary cache | `--narinfo-cache-negative-ttl` (seconds) |
| Database disk image malformed | `sqlite3 /nix/var/nix/db/db.sqlite "pragma integrity_check"` then dump/reload |
| Store schema version mismatch | Dump with new Nix, reload with old Nix: `nix-store --dump-db` / `nix-store --load-db` |
| Connection reset by peer | File/dir too large for store import, or low disk/memory — reduce size or GC |
| macOS update breaks Nix | Re-add Nix daemon source to `/etc/zshrc` after macOS overwrites it |

### 7.2 FAQ Highlights

- **nixfmt** is the official formatter for Nix code, used in Nixpkgs
- **nixpkgs-review** for building reverse dependencies: `nixpkgs-review wip`
- **Home Manager** for managing dotfiles in `$HOME`
- **nixos-generators** for building custom ISO images
- NixOS test machines can be connected to interactively
- NixOS can be bootstrapped inside an existing Linux installation

---

## 8. devops-research Corpus — Nix-Related Findings

### 8.1 Nix-Related Repositories

From the devops-research `repos.yaml` (1,850+ repos):

| Repo | Stars | Category | Description |
|---|---|---|---|
| **xonsh/xonsh** | 9,600 | security/systems | Python-powered shell with Nix/NixOS support |
| **firezone/firezone** | 9,013 | security/systems | Zero-trust access platform (WireGuard) |
| **tiiuae/sbomnix** | 307 | security/security | SBOM, provenance, dependency graph, and vulnerability tools for Nix |
| **buildsafedev/bsf** | 289 | security/application | Developer-centric supply chain security tool (Nix + SLSA) |
| **nlewo/comin** | 968 | cicd/application | GitOps for NixOS servers and laptops |
| **terranix/terranix** | 505 | iac/application | Nix-based Terraform JSON generator |

### 8.2 NixOS Research Paper

From the devops-research `papers.yaml`:

> **"Deklarativna, ponovljiva, neobstojna in varna postavitev ter upravljanje
> infrastrukture z Nix/NixOS"** (2026-07)
> Author: Miha Krumpestar
> URL: https://repozitorij.uni-lj.si/IzpisGradiva.php?id=185108
> Category: security
>
> Abstract: "Every mainstream operating system and configuration manager
> treats the filesystem as a mutable global namespace and deployment as a
> sequence of stateful transformations upon it. The resulting failure..."

This paper examines NixOS's declarative, reproducible, ephemeral, and secure
infrastructure management approach — directly relevant to the opendesk-edu
use case of building a secure, reproducible cloud stack.

### 8.3 Key DevOps Intelligence from Digest

From the devops-research `data/latest.md` digest (2026-08-09):

- **fluxcd/flux2 v2.9.4**: Flux patch release with Kustomization fixes
- **checkov 3.3.1**: IaC security scanning (serverless vars opt-out)
- **syft v1.50.0**: SBOM generation (bun classifier, OCI layout support)
- **gitleaks v8.30.1**: Secret scanning (recursive decoding, composite rules)
- **trivy v0.73.0**: Container vulnerability scanning
- **Kubernetes DRA vs HAMi**: GPU sharing on K8s (CNCF blog)
- **Shadow AI in CI/CD**: Threat modeling from developer laptop to K8s
- **NPM supply chain attacks**: Shai-Hulud worm (6th round, keyv/cacheable)
- **Platform Engineering ROI**: Cost of building internal developer platforms

**Relevance to opendesk-edu**: The security tooling (checkov, syft, gitleaks,
trivy) are relevant for the DevGuard security patterns in opendesk-nix.

---

## 9. NixOS Virtual Machines (nix.dev Tutorial Deep Dive)

### 9.1 Creating VMs from NixOS Config

```shell-session
$ nix-build '<nixpkgs/nixos>' -A vm \
  -I nixpkgs=channel:nixos-24.05 \
  -I nixos-config=./configuration.nix
$ ./result/bin/run-nixos-vm
```

### 9.2 QEMU Configuration Options

```nix
{ config, pkgs, ... }: {
  imports = [ <nixpkgs/nixos/modules/virtualisation/qemu-vm.nix> ];
  virtualisation.qemu.options = [ "-device virtio-vga" ];
}
```

### 9.3 Key VM Tutorial Points

- `nixos.qcow2` file persists VM state — delete between config changes
- `QEMU_KERNEL_PARAMS=console=ttyS0` for serial console
- `-nographic` flag for headless operation
- GNOME/Sway desktop environments can be enabled in the VM config
- `nixos-generate-config --dir ./` generates initial config from ISO

---

## 10. Bootable ISO Image Building (nix.dev)

```nix
{ pkgs, modulesPath, lib, ... }: {
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.supportedFilesystems = lib.mkForce [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs" ];
}
```

```shell-session
$ NIX_PATH=nixpkgs=https://github.com/NixOS/nixpkgs/archive/<commit>.tar.gz \
  nix-shell -p nixos-generators --run \
  "nixos-generate --format iso --configuration ./myimage.nix -o result"
$ dd if=result/iso/*.iso of=/dev/sdX status=progress
$ sync
```

**Relevance**: Custom ISO images for air-gapped SCS provisioning — can
pre-bake the NixOS installer with custom kernel, filesystem support, and
proxy configuration.

---

## 11. Raspberry Pi / ARM Deployment (nix.dev)

Key findings from the RPi tutorial:

- AArch64 SD images from Hydra: `nixos-sd-image-*.img.zst`
- Cross-build images on x86 for aarch64
- `nixos-hardware` module for hardware-specific config:
  ```nix
  imports = [ "${fetchTarball "https://github.com/NixOS/nixos-hardware/tarball/master"}/raspberry-pi/4" ];
  ```
- `boot.loader.generic-extlinux-compatible.enable = true` for ARM boot
- `hardware.enableRedistributableFirmware = true` for Wi-Fi/BT firmware
- `users.mutableUsers = false` for declarative user management

**Relevance**: ARM edge deployment patterns for SCS cluster edge nodes.

---

## 12. Python Development Environment (nix.dev)

```nix
{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-23.11") {} }:

pkgs.mkShellNoCC {
  packages = with pkgs; [
    (python3.withPackages (ps: [ ps.flask ]))
    curl
    jq
  ];
}
```

**Key pattern**: `python3.withPackages` allows composing Python environments
with non-Python tools (curl, jq) in the same shell — impossible with
virtualenv alone.

---

## 13. nix.dev Further Reading — Community Resources

### 13.1 Learning Resources

| Resource | Type | Description |
|---|---|---|
| Nix Pills | Tutorial | Low-level package building with Nix |
| Nix from First Principles | Blog | Modern crash-course (Flake edition) |
| How to Learn Nix | Blog | "Let's Play" style for obscure docs |
| Nix - A One Pager | Reference | One-page Nix language intro |
| nix-book | Book | NixOS hardening and configuration |
| NixOS in Production | Book | Free (pay-what-you-want) PDF |
| NixOS & Flakes Book | Book | Beginner's NixOS & Flakes guide |
| NixOS Asia Tutorial | Tutorial | High-level Flakes/NixOS/home-manager |
| Zero to Nix | Guide | Determinate Systems learning resource |
| Explainix | Tool | Visual Nix syntax explainer |

### 13.2 Video Resources

| Resource | Description |
|---|---|
| Nixology (Burke Libbey) | Fundamental Nix concepts video series |
| The Nix Hour (Silvan Mosberger) | Weekly Nix ecosystem exploration |
| Nixpkgs (Jon Ringer) | Nixpkgs tutorial videos |
| NixOS (Wil Taylor) | Getting started with NixOS |
| NixCon YouTube | NixCon talk recordings |
| NixOS Foundation YouTube | Official NixOS Foundation channel |

### 13.3 Notable Community Tools (from Further Reading)

- **Nix Starter Configs** (Misterio77): Simple Flake templates for
  NixOS + home-manager
- **compose2nix**: Generate NixOS config from Docker Compose (relevant
  for migrating Docker services to NixOS)
- **nixidy**: Kubernetes GitOps with Nix and Argo CD (directly relevant
  to opendesk-edu's ArgoCD stack)
- **MCP-NixOS**: MCP server for AI assistants to query NixOS packages/options

---

## 14. Cross-Source Synthesis — New Insights for opendesk-edu

### 14.1 Binary Cache Priority — Priority Field

From the nixos.wiki and nix.dev research:

The `Priority` field in `nix-cache-info` controls which cache wins when
multiple caches have the same store path:

- Lower priority number = higher precedence
- `cache.nixos.org` uses priority 30
- Self-hosted caches can use lower numbers to override

**For SCS air-gapped**: Set the local Attic/nix-serve cache to priority 10
to ensure it takes precedence over cache.nixos.org (which is unreachable
in air-gapped environments anyway, but the priority matters if a cache
proxy is set up).

### 14.2 NixOS Container Management vs K8s

NixOS's built-in `containers.<name>` (systemd-nspawn) provides a lighter
alternative to K8s for simple services:

- **Advantage**: Declarative, integrated with NixOS config, no K8s overhead
- **Disadvantage**: No rolling updates, no service mesh, no horizontal scaling
- **Use case**: Sidecar services on K8s nodes (e.g., local registry proxy,
  monitoring agents, binary cache)

### 14.3 comin — GitOps for NixOS

`comin` (968★) is a GitOps tool that continuously pulls NixOS configurations
from Git repositories — essentially ArgoCD for NixOS:

- Watches Git repositories for config changes
- Automatically runs `nixos-rebuild switch` on changes
- Supports multiple remotes with priority
- **Relevance**: Could complement opendesk-edu's ArgoCD by managing the
  NixOS base OS layer while ArgoCD manages K8s workloads

### 14.4 terranix — Nix for Terraform/OpenTofu

`terranix` (505★) generates Terraform JSON from Nix expressions:

- Alternative to `declarative-runtime`'s `builtins.toJSON` approach
- Uses NixOS module system for type checking
- Supports both Terraform and OpenTofu
- **Relevance**: Could be an alternative to the `builtins.toJSON` approach
  used in `applicative-systems/declarative-runtime`

### 14.5 sbomnix — Nix SBOM Generation

`tiiuae/sbomnix` (307★) generates SBOMs from Nix derivations:

- CycloneDX and SPDX output formats
- Dependency graph generation
- Vulnerability scanning integration
- PURL (Package URL) support
- **Relevance**: Directly relevant to opendesk-nix's `sbom.nix` module —
  sbomnix could be integrated as a CI step for SBOM generation

### 14.6 buildsafedev/bsf — Supply Chain Security

`buildsafedev/bsf` (289★) is a developer-centric supply chain security tool:

- Nix-based reproducible builds
- SLSA (Supply-chain Levels for Software Artifacts) provenance
- **Relevance**: Relevant to opendesk-nix's security and compliance patterns

### 14.7 NixOS Module System — Extensible Types

From the NixOS manual examples (34 examples), key patterns:

```nix
# Extensible type placeholder
options.settings = mkOption {
  type = types.submoduleWith {
    modules = [ ];
    shorthandOnlyDefinesConfig = true;
  };
  default = {};
};

# Extending services in other modules
config.services.xserver.displayManager.enable = mkDefault true;

# Using extendNixOS in passthru.tests
passthru.tests = (nixos {}).extendNixOS { modules = [ testModule ]; };
```

### 14.8 nixfmt — Official Formatter

nixfmt is the **official** Nix code formatter, used to format all code in
Nixpkgs itself. This is distinct from:
- **alejandra** — opinionated alternative formatter
- **nixpkgs-fmt** — another popular formatter

**Recommendation for opendesk-edu**: Use `nixfmt` (official) or `alejandra`
(opinionated) with `treefmt` for consistent formatting across the project.

### 14.9 MCP-NixOS — AI Integration

`MCP-NixOS` provides an MCP (Model Context Protocol) server that gives AI
assistants access to NixOS package and option data:

- Search NixOS packages
- Search NixOS options
- Search Home Manager options
- Search nix-darwin configurations
- **Relevance**: Could be used to enhance AI-assisted NixOS configuration
  authoring in the opendesk-edu workflow

---

## 15. Summary of New Findings vs Previous Research

### New Sources Consulted

| Source | URL | Key New Findings |
|---|---|---|
| NixOS Manual | nixos.org/manual/nixos/stable | systemd-repart image building, container management, 34 module examples, service management |
| nixos.wiki (Wayback) | web.archive.org/nixos.wiki | Flakes schema, binary cache setup, impermanence config, disko config, Secure Boot/Lanzaboote |
| Zero to Nix | zero-to-nix.com | Caching concepts, NixOS generations, module anatomy, binary cache mechanics |
| Awesome Nix | github.com/nix-community/awesome-nix | 150+ ecosystem tools (deployment, CLI, dev, DevOps, virtualisation) |
| Nixpkgs Manual | nixos.org/manual/nixpkgs/stable | 90+ examples (overlays, dockerTools, testers, build helpers) |
| nix.dev Troubleshooting | nix.dev/guides/troubleshooting | Cache troubleshooting, DB repair, schema migration, macOS issues |
| nix.dev FAQ | nix.dev/guides/faq | nixfmt, nixpkgs-review, Home Manager, nixos-generators |
| nix.dev VM Tutorial | nix.dev/tutorials/nixos/nixos-configuration-on-vm | QEMU VM config, nix-build -A vm, graphical VMs, Sway |
| nix.dev ISO Tutorial | nix.dev/tutorials/nixos/building-bootable-iso-image | Custom ISO with nixos-generators, kernel customization |
| nix.dev RPi Tutorial | nix.dev/tutorials/nixos/installing-nixos-on-a-raspberry-pi | ARM deployment, nixos-hardware, extlinux boot, mutableUsers |
| nix.dev Python Tutorial | nix.dev/guides/recipes/python-environment | python3.withPackages, mkShellNoCC |
| nix.dev Further Reading | nix.dev/recommended-reading | Community resources, videos, blogs |
| devops-research corpus | ~/git/devops-research | sbomnix, bsf, comin, terranix, NixOS paper on declarative infrastructure |

### Key New Patterns Not in Previous Research

1. **NixOS declarative containers** (systemd-nspawn) — lighter alternative
   to K8s for sidecar services
2. **comin** — GitOps for NixOS base OS (complements ArgoCD for K8s)
3. **terranix** — Nix-to-Terraform JSON (alternative to builtins.toJSON)
4. **sbomnix** — Nix-native SBOM generation with CycloneDX/SPDX
5. **MCP-NixOS** — AI assistant integration for NixOS package/option search
6. **nixos-generators** — Multi-format image building (ISO, VM, cloud)
7. **Priority field** in binary cache — controls cache precedence
8. **nix-health** — Project-specific Nix health checks in flake.nix
9. **compose2nix** — Docker Compose to NixOS config migration tool
10. **nixidy** — Kubernetes GitOps with Nix and Argo CD (directly relevant)
11. **NixOS manual module examples** — 34 patterns for extensible modules
12. **Nixpkgs manual dockerTools examples** — 19+ container image patterns
13. **nix-cache-info protocol** — StoreDir, WantMassQuery, Priority fields
14. **FlakeHub Cache** — Determinate Systems hosted binary cache
15. **NixOS Facter** — Hardware detection replacing nixos-generate-config

---

*This document supplements the existing 26-topic best practices guide with
findings from the second research round. All findings are cross-referenced
with their source URLs for verification.*
