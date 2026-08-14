# Applicative Systems GitHub Organization — Analysis


The `applicative-systems` organization (16 public repos) is run by the team
behind [Nixcademy](https://nixcademy.com) — the same people who wrote much of
the official nix.dev curriculum. The repos are not toys; they are production
reference implementations and teaching materials for advanced NixOS patterns:

| Category | Repos |
|---|---|
| **Appliance images & OTA** | nixos-appliance-ota-update (92⭐), simple-systemd-repart-nixos-image (16⭐), nixos-image-cross-compilation-example (4⭐) |
| **Declarative service runtime** | declarative-runtime (10⭐) |
| **Integration testing** | nixos-test-driver-nixcon (18⭐), nixos-test-driver-manual (6⭐), nixos-gpu-tests (4⭐), nix-cuda-example (0⭐) |
| **Build infrastructure** | vzvm (22⭐), gcan (27⭐) |
| **Flake scaffolding** | sysmodule-flake (4⭐), mkdocs-flake (11⭐), templates (1⭐) |
| **Other** | declarative-runtime, habrawo.nix.ug (1⭐, user group site), project-templates, nixcon-home-manager |

**Key insight**: This org sits at the intersection of NixOS pedagogy and
production infrastructure. Their patterns are directly applicable to a
cloud-native, GitOps-driven, air-gapped deployment like opendesk-edu.


---

## Part II: Repository Deep Dives

### 1. nixos-appliance-ota-update (92⭐)

**What it is**: A reference implementation for building bootable NixOS appliance
images with **A/B OTA (Over-The-Air) updates** using `systemd-repart` and
`systemd-sysupdate`. This is the most starred repo in the org and the most
relevant pattern for immutable, remotely-updatable infrastructure.

**Core mechanism**:
- `image.repart` defines partition layout: ESP (boot), `nix-store` (squashfs,
  read-only), `root` (ext4, writable), and an `_empty` partition for the next
  update slot
- `systemd-sysupdate` downloads update images from a URL and writes them to the
  inactive partition slot (`InstancesMax = 2`)
- Boot assessment via systemd boot loader automatically reverts to the previous
  slot if the new one fails to boot
- UKI (Unified Kernel Image) boot via systemd-boot, no GRUB
- GPG signature verification (optional)
- TPM-based disk encryption (optional)
- dm-verity for the read-only nix-store partition

**Key code patterns** (from `system-configuration/image.nix`):
```nix
image.repart = {
  name = config.system.image.id;
  split = true;                    # separate nix-store image for updates

  partitions = {
    esp = {
      contents = {
        "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
          "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
        "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
          "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
      };
      repartConfig = {
        Type = "esp"; Format = "vfat"; Label = "boot";
        SizeMinBytes = "200M"; SplitName = "-";
      };
    };
    nix-store = {
      storePaths = [ config.system.build.toplevel ];
      nixStorePrefix = "/";
      repartConfig = {
        Type = "linux-generic";
        Label = "nix-store_${config.system.image.version}";
        Format = "squashfs"; ReadOnly = "yes";
        SizeMinBytes = "2G"; SizeMaxBytes = "2G";
        SplitName = "nix-store";
      };
    };
    root.repartConfig = {
      Type = "root"; Format = "ext4"; Label = "root";
      SizeMinBytes = "5G"; SizeMaxBytes = "5G"; SplitName = "-";
    };
  };
};
```

**Update mechanism** (from `system-configuration/update.nix`):
```nix
systemd.sysupdate = {
  enable = true;
  transfers = {
    "10-nix-store" = {
      Source = { Path = "http://localhost/"; Type = "url-file";
                 MatchPattern = [ "${config.system.image.id}_@v.nix-store.raw" ]; };
      Target = { InstancesMax = 2; Path = "auto"; MatchPattern = "nix-store_@v";
                 Type = "partition"; MatchPartitionType = "linux-generic"; ReadOnly = "yes"; };
    };
    "20-boot-image" = {
      Source = { MatchPattern = [ "${config.boot.uki.name}_@v.efi" ]; };
      Target = { InstancesMax = 2; Path = "/EFI/Linux"; Type = "regular-file"; };
    };
  };
};
```

**Cross-compilation support** (from `flake.nix`):
```nix
# Build from macOS (with linux-builder) targeting x86_64-linux or aarch64-linux
defaultImage = extendConfiguration inputs.self.nixosConfigurations.appliance (
  { lib, ... }: {
    nixpkgs.buildPlatform = lib.mkDefault linuxSystem;
    nixpkgs.hostPlatform = lib.mkDefault linuxSystem;
  });
```

**The `sysupdate-package`** (from `update-package.nix`) bundles the UKI + nix-store
image + SHA256SUMS into a single artifact for distribution:
```nix
config.system.build.sysupdate-package = pkgs.runCommand "sysupdate-package-${version}" {} ''
  mkdir $out
  cp ${build.uki}/${ukiFile} $out/
  cp ${build.image}/${id}_${version}.nix-store.raw $out/
  cd $out; sha256sum * > SHA256SUMS
'';
```

**Relevance to opendesk-edu**:
- **Immutable base OS**: NixOS appliance images could replace the current base
  OS layer on SCS K3s nodes, providing a reproducible, version-controlled OS
  image per cluster node
- **A/B OTA updates**: `systemd-sysupdate` provides safe, atomic OS updates with
  automatic rollback — ideal for air-gapped environments where manual intervention
  is costly
- **Squashfs nix-store**: Read-only, verity-protected store partition means the
  entire system closure is immutable and tamper-evident
- **Cross-compilation**: Images can be built from a macOS development machine or
  a cross-architecture build server, useful for mixed-arch clusters

---

### 2. declarative-runtime (10⭐)

**What it is**: A NixOS module framework that makes service **runtime state**
declarative by pairing each NixOS service with its Terraform/OpenTofu provider.
A systemd oneshot unit applies the declared state after the service starts.

**The gap it closes**: NixOS modules configure static surface (package version,
config file, systemd unit) but NOT runtime state (Grafana dashboards, Forgejo
orgs/repos, Keycloak realms/clients). This repo fills that gap by generating
`.tf.json` from Nix options and applying it via OpenTofu.

**Architecture**:
```
flake.nix
modules/
  default.nix          # aggregates all pairings
  lib/default.nix      # provider-agnostic helpers (mkTfConfig, mkReconcileService)
services/
  forgejo/             # reference pairing (15 resource types)
    module.nix         # NixOS options + systemd wiring
    lib.nix            # provider-specific .tf.json generation
    pkg.nix            # vendored Terraform provider (svalabs/forgejo)
    checks.nix         # NixOS integration tests
  keycloak/            # ~95 resource types
    module.nix, lib.nix, checks.nix
examples/
  keycloak-forgejo/    # runnable QEMU VM example with SSO
```

**Key design decisions** (from CLAUDE.md):
| Decision | Choice |
|---|---|
| Executor | **OpenTofu** (MPL 2.0, free) — NOT Terraform (BSL 1.1, unfree) |
| Config authoring | Generate `.tf.json` directly via `builtins.toJSON` — no HCL, no terranix |
| Secrets | systemd `LoadCredential=` — secrets never enter the Nix store; referenced as `${var.<id>}` in .tf.json |
| Reconciliation | Run-once `Type=oneshot` after primary unit + readiness probe; re-applies on config change via `restartTriggers`; NO drift timer |
| State | Local, per-host only — tfstate lives under the service's state dir (e.g. `/var/lib/forgejo`); no remote backends |
| Module namespace | `services.<svc>.runtime.*` — transparent extension of upstream module |
| Provider wrapping | `pkgs.opentofu.withPlugins (_: [ provider ])` — no registry access at activation time (air-gap friendly!) |
| CI | GitHub Actions with `nix flake check`, Determinate Systems nix-installer |
| Formatter | treefmt + nixfmt (single source of layout truth) |

**The `mkReconcileService` pattern** (from `modules/lib/default.nix`):
```nix
mkReconcileService = { name, tfConfig, afterUnits, healthUrl, tokenFile,
  executor, tokenVar, user, group, stateDir, credentials ? {}, dynamicUser ? false }:
  let
    confFile = tfJsonFile name tfConfig;
    allCredentials = { ${tokenVar} = tokenFile; } // credentials;
    workDir = "${stateDir}/declarative-terraform";
  in {
    description = "Declarative reconciliation for ${name} (OpenTofu)";
    after = afterUnits; requires = afterUnits; wantedBy = [ "multi-user.target" ];
    restartTriggers = [ confFile ];     # re-apply when config changes
    path = [ executor pkgs.curl pkgs.coreutils ];
    environment = { TF_IN_AUTOMATION = "1"; TF_INPUT = "0"; };
    serviceConfig = {
      Type = "oneshot"; RemainAfterExit = true;
      User = user; Group = group;
      LoadCredential = lib.mapAttrsToList (id: path: "${id}:${path}") allCredentials;
    };
    script = ''
      set -euo pipefail; umask 077
      mkdir -p ${workDir}; cd ${workDir}
      install -m 0600 ${confFile} ./main.tf.json
      # readiness probe
      for _ in $(seq 1 60); do
        curl -fsS -o /dev/null "${healthUrl}" && break; sleep 2
      done
      for id in ${lib.escapeShellArgs (lib.attrNames allCredentials)}; do
        export "TF_VAR_$id=$(cat "$CREDENTIALS_DIRECTORY/$id")"
      done
      tofu init -no-color; tofu apply -auto-approve -input=false -no-color
    '';
  };
```

**Secret handling** — the `substituteSecrets` function walks the config tree and
replaces `<attr>File = "/path"` entries with `${var.<id>}` references, collecting
credential mappings for `LoadCredential=`. This works at any nesting depth.

**Usage example**:
```nix
services.forgejo = {
  enable = true;
  runtime = {
    enable = true;
    organizations.acme.description = "ACME Corporation";
    repositories.widgets = { owner = "acme"; description = "Widget factory"; };
  };
};
```

**Relevance to opendesk-edu**:
- **Declarative runtime state for K8s services**: Many opendesk-edu services
  (Keycloak, Grafana, Forgejo/Gitea) have runtime state that ArgoCD/Helmfile
  cannot manage declaratively. This pattern could complement GitOps.
- **Air-gap friendly**: OpenTofu providers are vendored via Nix
  (`opentofu.withPlugins`), so no registry access is needed at runtime — perfect
  for the air-gapped SCS cluster
- **Secret safety**: `LoadCredential=` pattern keeps secrets out of the Nix store
  — directly relevant to opendesk-nix's DevGuard security model
- **Integration test pattern**: Each pairing ships `checks.nix` with NixOS
  integration tests via `testers.runNixOSTest` — a model for testing opendesk-edu
  service modules


---

### 3. nixos-test-driver-nixcon (18⭐)

**What it is**: NixCon 2025 workshop materials on advanced NixOS integration
testing. Three runnable examples: `ping` (basic multi-VM networking), `echo`
(custom service + client), `browser` (X11 + Firefox in a VM).

**Key patterns**:

**Multi-VM test with networking** (`ping/default.nix`):
```nix
{
  name = "ping test";
  nodes = {
    machine1 = {};   # empty config sets defaults
    machine2 = {};
  };
  globalTimeout = 300;
  defaults = {
    networking.dhcpcd.enable = false;  # ongoing discussion re: default
  };
  testScript = ''
    start_all()
    # Must explicitly start network-online.target — it's no longer implicitly
    # required by multi-user.target in recent NixOS
    machine1.systemctl("start network-online.target")
    machine2.systemctl("start network-online.target")
    machine1.wait_for_unit("network-online.target")
    machine2.wait_for_unit("network-online.target")
    machine1.succeed("ping -c 1 machine2")
    machine2.succeed("ping -c 1 machine1")
  '';
}
```

**Custom service + client test** (`echo/default.nix`):
```nix
{
  name = "Echo Service Test";
  nodes = {
    server = { config, ... }: {
      imports = [ ./echo-nixos-module.nix ];
      services.echo.enable = true;
      networking.firewall.allowedTCPPorts = [ config.services.echo.port ];
    };
    client = {};
  };
  testScript = { nodes, ... }: ''
    ECHO_PORT = ${builtins.toString nodes.server.services.echo.port}
    ECHO_TEXT = "Hello, world!"
    start_all()
    server.wait_for_unit("echo.service")
    server.wait_for_open_port(ECHO_PORT)
    client.systemctl("start network-online.target")
    client.wait_for_unit("network-online.target")
    output = client.succeed(f"echo '{ECHO_TEXT}' | nc -N server {ECHO_PORT}")
    assert ECHO_TEXT in output
  '';
}
```

**Interactive debugging** — the `interactive` attribute enables `driverInteractive`:
```nix
interactive.nodes = {
  server = {
    virtualisation.forwardPorts = [{ from = "host"; host.port = 8000; guest.port = 80; }];
  };
  client = import ../debug-host-module.nix;
};
```

**Browser test with OCR and X11** (`browser/default.nix`):
```nix
{
  enableOCR = true;
  defaults = {
    networking.firewall.enable = false;
    virtualisation.resolution = { x = 800; y = 600; };
  };
  nodes = {
    server = { services.httpd.enable = true; ... };
    client = { pkgs, ... }: {
      imports = [ (nixpkgs + "/nixos/tests/common/x11.nix") ];
      programs.firefox.enable = true;
      environment.systemPackages = [ pkgs.xdotool ];
    };
  };
}
```

**Relevance to opendesk-edu**:
- **Multi-VM integration tests** are the gold standard for testing K8s service
  modules before deploying to SCS — you can test that service A can reach
  service B before touching the cluster
- **`interactive` attribute** enables `driverInteractive` for debugging test
  failures interactively — invaluable for complex multi-service setups
- **Port forwarding** in interactive mode mirrors the HAProxy ingress pattern
- **Custom service module testing**: The echo test is a template for testing
  any custom NixOS service module before deploying it

---

### 4. vzvm (22⭐)

**What it is**: A macOS Linux builder using Apple's Virtualization.framework with
Rosetta support. Now in nixpkgs as `pkgs.darwin.linux-builder-vz`. Enables
`x86_64-linux` builds on Apple Silicon at 2.54x the speed of QEMU TCG emulation.

**Key points**:
- Direct kernel boot + erofs store image cached by closure hash → fast,
  predictable boot (12s vs 0.1-31.5s for QEMU)
- Nested virtualization (`virtualisation.vz.nestedVirtualization`) → working
  `/dev/kvm` in the guest → can run `nixosTests` and `testers.runNixOSTest` on macOS
- Under 1000 lines of Swift; host closure ~1.2 GiB (vs ~3.2 GiB for QEMU)
- macOS-native unified logging under `systems.applicative.vzvm`
- In nixos-unstable and NixOS 26.11

**Enablement**:
```nix
nix.linux-builder = {
  enable = true;
  package = pkgs.darwin.linux-builder-vz;
  systems = [ "aarch64-linux" "x86_64-linux" ];  # x86_64 needed for Rosetta
};
```

**Relevance to opendesk-edu**:
- If any developer uses Apple Silicon Macs, vzvm enables local Linux builds and
  NixOS integration tests without QEMU's performance penalty
- Nested virtualization means CI-like VM tests can run on macOS dev machines
- Not directly relevant to the SCS K3s cluster (which is x86_64 Linux), but
  relevant to the developer workflow

---

### 5. gcan (27⭐)

**What it is**: A Rust tool for analyzing, filtering, and pruning Nix GC roots.
Helps answer "what's keeping this path alive?" and safely clean up unused store
paths.

**Key patterns from flake.nix**:
- **naersk** for Rust builds (vendored via flake input with `flake = false`)
- **Comprehensive treefmt config**: nixfmt + statix + deadnix for Nix, rustfmt +
  clippy for Rust, taplo for TOML, prettier for docs, shellcheck + shfmt for shell
- **`inputsFrom`** in devShell to inherit build dependencies from the package
- Overlays pattern: `overlays.default = import ./overlay.nix`

**Relevance to opendesk-edu**:
- **GC root management** is critical in air-gapped environments where store paths
  are precious (binary cache may be limited)
- **treefmt configuration** is a best-practice template for any Nix project —
  the same nixfmt + statix + deadnix combo should be applied to opendesk-nix
- **statix with `["fix"]`** auto-fixes lint issues; **deadnix with `["--edit"]`**
  removes dead code automatically

---

### 6. simple-systemd-repart-nixos-image (16⭐)

**What it is**: A blog-series companion repo showing minimal NixOS appliance
images with `systemd-repart`. Simpler than the OTA repo — no A/B updates, just
the basic image-building pattern.

**Key patterns** (from `config/image.nix`):
```nix
image.repart = {
  name = "image";
  partitions = {
    esp = {
      contents = {
        "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
          "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
        "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
          "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
      };
      repartConfig = { Format = "vfat"; Label = "boot"; SizeMinBytes = "200M"; Type = "esp"; };
    };
    nix-store = {
      storePaths = [ config.system.build.toplevel ];
      nixStorePrefix = "/";
      repartConfig = {
        Format = "squashfs"; Label = "nix-store"; Minimize = "guess";
        ReadOnly = "yes"; Type = "linux-generic";
      };
    };
  };
};

# Runtime partition growth via systemd-repart in initrd
boot.initrd.systemd.repart.enable = true;
boot.initrd.systemd.repart.device = "/dev/sda";
systemd.repart.partitions = {
  home = { Format = "ext4"; Label = "home"; Type = "home"; Weight = 2000; };
  var  = { Format = "ext4"; Label = "var";  Type = "var";  Weight = 1000; };
};
```

**Key difference from OTA repo**: Uses `Minimize = "guess"` (auto-size the
nix-store partition) instead of fixed `SizeMinBytes`/`SizeMaxBytes`. Uses
`boot.initrd.systemd.repart` for runtime partition growth (home, var) rather
than A/B update slots.

**Relevance to opendesk-edu**: This is the minimal starting point for building
NixOS appliance images. If the OTA update mechanism is too complex for the
initial deployment, this repo provides the simplest path to a bootable,
reproducible NixOS image.


---

### 7. nixos-gpu-tests (4⭐)

**What it is**: Running CUDA/GPU workloads inside the NixOS integration test
driver — using the new container-based test runner (not full QEMU VMs).

**Key patterns** (from `flake.nix`):
```nix
pkgs = import inputs.nixpkgs {
  inherit system;
  config = {
    allowUnfree = true;
    cudaSupport = true;
    cudaForwardCompat = false;
    cudaCapabilities = [ "6.1" ];
  };
  overlays = [ (import ./overlay.nix) ];  # patches the test driver
};

# Add required system features to the test derivation
addRequiredFeatures = reqs: drv:
  drv.overrideTestDerivation (old: {
    requiredSystemFeatures = old.requiredSystemFeatures ++ reqs;
  });

cuda-container-test-nvidia = addRequiredFeatures [ "cuda" ] (
  pkgs.testers.runNixOSTest ./cuda-in-container-nvidia.nix
);
```

**Host configuration for GPU passthrough**:
```nix
nix.settings.auto-allocate-uids = true;
nix.settings.experimental-features = [ "auto-allocate-uids" "cgroups" ];
nix.settings.extra-system-features = [ "uid-range" ];
nix.settings.extra-sandbox-paths = [ "/dev/net" ];

# NVIDIA-specific:
hardware.nvidia = {
  modesetting.enable = true;
  package = config.boot.kernelPackages.nvidiaPackages.latest;
};
programs.nix-required-mounts = {
  enable = true;
  presets.nvidia-gpu.enable = true;
};
```

**Relevance to opendesk-edu**: If any services require GPU access (e.g., Ollama
for LLM inference, which is in the opendesk-edu service catalog), this pattern
shows how to test GPU workloads in NixOS integration tests. The
`overrideTestDerivation` + `requiredSystemFeatures` pattern is a general
technique for gating tests on hardware capabilities.

---

### 8. nixos-image-cross-compilation-example (4⭐)

**What it is**: Minimal example of cross-compiling NixOS images — build from
macOS (aarch64-darwin) targeting x86_64-linux or aarch64-linux.

**Key pattern** (from `flake.nix`):
```nix
forEachSystem = lib.genAttrs systems;
packages = forEachSystem (system:
  let linuxSystem = builtins.replaceStrings ["darwin"] ["linux"] system;
  in {
    image-x86_64 = (inputs.self.nixosConfigurations.image.extendModules {
      modules = [{
        nixpkgs.buildPlatform = linuxSystem;
        nixpkgs.hostPlatform = "x86_64-linux";
      }];
    }).config.system.build.image;
    image-aarch64 = (inputs.self.nixosConfigurations.image.extendModules {
      modules = [{
        nixpkgs.buildPlatform = linuxSystem;
        nixpkgs.hostPlatform = "aarch64-linux";
      }];
    }).config.system.build.image;
  });
```

**Key technique**: `extendModules` to override `buildPlatform`/`hostPlatform`
without duplicating the configuration. The same `nixosConfigurations.image` is
used for all target architectures.

**Relevance to opendesk-edu**: Directly applicable if the SCS cluster has
mixed-architecture nodes or if images need to be built on a different
architecture than the target. The `extendModules` pattern is the idiomatic way
to cross-compile NixOS images.

---

### 9. sysmodule-flake (4⭐)

**What it is**: A flake-parts module that auto-discovers NixOS, nix-darwin, and
home-manager configurations from a directory structure, eliminating boilerplate.

**Directory convention**:
```
configs-nixos/         # NixOS configurations (one dir per machine)
configs-darwin/        # nix-darwin configurations
modules-home-manager/  # home-manager modules
modules-nixos/         # NixOS modules
modules-darwin/        # nix-darwin modules
```

**Usage**:
```nix
inputs.sysmodule-flake.url = "github:applicative-systems/sysmodule-flake";
# In outputs:
sysmodules-flake = {
  modulesPath = ./.;
  specialArgs.self = inputs.self;
  inherit (inputs) nix-darwin;
};
```

**Relevance to opendesk-edu**: If opendesk-nix manages multiple NixOS host
configurations (not just K8s manifests), sysmodule-flake could reduce
boilerplate. However, the current opendesk-edu architecture uses Nix primarily
for devShell + K8s manifest generation, so this is lower priority unless NixOS
host management is adopted.

---

### 10. nix-cuda-example (0⭐)

**What it is**: A minimal self-written CUDA app (SAXPY) built with Nix and
exercised in a NixOS integration test. Companion to nixos-gpu-tests but focused
on the packaging side.

**Key pattern**: CUDA-enabled nixpkgs with overlays:
```nix
pkgs = import inputs.nixpkgs {
  inherit system;
  config = { allowUnfree = true; cudaSupport = true; };
  overlays = [ inputs.self.overlays.default ];
};
packages.default = pkgs.cuda-app;
test-cuda-nvidia = pkgs.testers.runNixOSTest ./tests/nvidia.nix;
```

**Relevance to opendesk-edu**: If Ollama or other GPU-dependent services in the
opendesk-edu catalog need CUDA, this shows the packaging pattern: `allowUnfree`
+ `cudaSupport` + overlay + integration test.

---

### 11. mkdocs-flake (11⭐)

**What it is**: MkDocs documentation site with Nix flake for reproducible builds.

**Relevance**: Could be used for opendesk-edu/opendesk-nix documentation. Low
priority but shows the pattern for Nix-managed documentation sites.

---

### 12. templates (1⭐)

**What it is**: Starter Nix flake project templates.

**Relevance**: Reference for project scaffolding patterns.

---

### 13. Other repos

- **nixos-test-driver-manual** (6⭐): Unofficial NixOS Test Driver Manual —
  reference documentation for the test driver API
- **habrawo.nix.ug** (1⭐): Nix user group website (Astro static site)
- **project-templates**, **nixcon-home-manager**: No READMEs (404)


---

