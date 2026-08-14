# Recommendations and Migration Plan


### Modern

1. **Adopt treefmt** (nixfmt + statix + deadnix) as the `formatter` output in
   opendesk-nix. This ensures consistent formatting and catches anti-patterns
   automatically. Pattern from gcan/declarative-runtime:
   ```nix
   formatter = lib.mapAttrs (_: pkgs:
     pkgs.treefmt.withConfig { settings = { ... }; }) inputs.nixpkgs.legacyPackages;
   ```

2. **Add `checks` to the flake** for CI gates: eval-only checks (manifest YAML
   validity), NixOS integration tests (service-to-service connectivity), and
   `nix flake check` in CI. Pattern from declarative-runtime.

3. **Use `lib.fileset`** for precise source filtering in build.nix instead of
   `src = ./.`. This improves caching and keeps the store clean.

4. **Adopt `extendModules`** for multi-architecture or multi-environment variants
   of any NixOS configurations.

5. **Consider `npins`** as a complement to flakes for pinning external sources
   that are not flake inputs.

### Secure

1. **Self-hosted binary cache with signing**: Set up `nix-serve` + nginx + signing
   keys inside the air-gapped network. All SCS nodes pull from this cache. Use
   `post-build-hook` to auto-upload built paths. (Part V.1)

2. **`LoadCredential=` for all secrets**: Follow the declarative-runtime pattern
   — secrets are never in the Nix store, always loaded via systemd
   `LoadCredential=` or Kubernetes secrets mounted as files.

3. **Container image signing with Cosign**: opendesk-nix already has
   `cosign.nix` — ensure all container images pushed to the local registry are
   signed and verified.

4. **SBOM generation**: opendesk-nix has `sbom.nix` — ensure SBOMs are
   generated for every container image and stored alongside the registry.

5. **Immutable base OS with A/B OTA**: Adopt the nixos-appliance-ota-update
   pattern for SCS nodes. Squashfs nix-store (read-only, verity-protected) +
   A/B slots + automatic rollback on boot failure.

6. **TPM disk encryption**: The OTA repo supports TPM-based encryption for the
   root partition — use this for node-local secrets.

7. **OpenTofu over Terraform**: If any runtime state reconciliation is adopted,
   use OpenTofu (MPL 2.0) not Terraform (BSL 1.1). The declarative-runtime
   pattern shows how.

### Scalable

1. **Distributed builds**: Configure a dedicated build machine (or use vzvm for
   macOS dev machines) as a remote builder. `nix.buildMachines` +
   `nix.distributedBuilds` + `builders-use-substitutes`.

2. **Binary cache as scaling enabler**: With a self-hosted cache, every SCS node
   and every CI runner shares build artifacts — no redundant builds.

3. **`extendModules` for environment variants**: Derive dev/staging/prod
   configurations from a single base without duplication.

4. **NixOS integration tests for multi-service scenarios**: Test that the full
   opendesk-edu service catalog (51+ services) works together before deploying.
   The `nixos-test-driver-nixcon` patterns (multi-VM, networking, port forwarding)
   are directly applicable.

5. **Post-build hook for automatic cache population**: Every build automatically
   uploads to the binary cache, so other nodes can substitute.

### Flexible

1. **Declarative runtime state**: Adopt the declarative-runtime pattern for
   services with runtime state that Helmfile/ArgoCD can't manage (Keycloak
   realms, Grafana dashboards, Forgejo orgs). The `services.<svc>.runtime.*`
   namespace is a clean extension.

2. **Air-gap-friendly provider vendoring**: The
   `pkgs.opentofu.withPlugins (_: [ provider ])` pattern means no registry
   access at runtime — perfect for air-gapped SCS.

3. **Cross-compilation support**: Use the `extendModules` +
   `nixpkgs.buildPlatform`/`hostPlatform` pattern to build images for any
   architecture from any build machine.

4. **Multiple deployment strategies**: The same Nix expressions can produce:
   - K8s manifests (current: via `opendesk-nix.lib.k8s`)
   - Docker images (via `dockerTools.buildImage`)
   - NixOS appliance images (via `image.repart`)
   - NixOS container images (via `nixos/containers.nix`)

5. **Flake or npins**: Support both flake-based and npins-based workflows for
   teams that prefer different tooling.


---

## Part IX: Migration Path for Air-Gapped SCS K3s

### Phase 1: Foundation (Weeks 1-2)

**1.1 Set up self-hosted binary cache**
- Deploy `nix-serve` + nginx on a machine inside the air-gapped network
- Generate signing keys: `nix-store --generate-binary-cache-key`
- Configure all build machines and SCS nodes to use the cache as a substituter
- Set up `post-build-hook` for automatic upload
- Configure HTTP proxy (`proxy.internal:3128`) for the initial
  `cache.nixos.org` pull-through

**1.2 Add treefmt to opendesk-nix**
- Add `formatter` output with nixfmt + statix + deadnix
- Run `nix fmt` in CI to enforce formatting
- Fix any existing lint issues with `statix fix` and `deadnix --edit`

**1.3 Add `checks` to the flake**
- Start with eval-only checks (does `nix flake check` pass?)
- Add manifest YAML validity checks (do `opendesk-nix.lib.k8s` outputs parse?)
- Add a simple NixOS integration test for one service (e.g., mariadb)

### Phase 2: Immutable Base OS (Weeks 3-4)

**2.1 Build NixOS appliance images**
- Adopt the `simple-systemd-repart-nixos-image` pattern first (simplest)
- Configure K3s as a NixOS service in the appliance image
- Use squashfs for the nix-store partition (read-only, verity-protected)
- Configure Ceph CSI, HAProxy ingress as NixOS services

**2.2 Provision with nixos-anywhere + disko**
- Declare disk layouts for SCS nodes (clrz14-06, clrz14-07)
- Use `nixos-anywhere` to provision via SSH
- Configure the local registry as a NixOS service

**2.3 Add A/B OTA updates (optional)**
- Adopt the `nixos-appliance-ota-update` pattern
- Set up `systemd-sysupdate` to pull updates from the local registry
- Configure boot assessment for automatic rollback
- Test on a non-production node first

### Phase 3: Testing & CI (Weeks 5-6)

**3.1 Integration tests for all services**
- Add `testers.runNixOSTest` checks for each K8s service module
- Multi-VM tests for service-to-service connectivity (e.g., mariadb + ilias)
- Use the `interactive` attribute for debugging

**3.2 GPU test support (if needed)**
- If Ollama or other GPU services are deployed, adopt the `nixos-gpu-tests`
  pattern for testing CUDA workloads
- Configure `requiredSystemFeatures` to gate GPU tests

**3.3 CI pipeline**
- `nix flake check` on every push
- Binary cache upload via post-build-hook
- Container image builds via `dockerTools.buildImage`, push to local registry
- SBOM generation via `opendesk-nix` sbom.nix
- Cosign signing for all container images

### Phase 4: Runtime State Management (Weeks 7-8)

**4.1 Adopt declarative-runtime pattern for Keycloak**
- Keycloak has ~95 resource types in the declarative-runtime repo
- Generate `.tf.json` from Nix options for realms, clients, scopes, users
- Use `LoadCredential=` for the admin token
- Run as a `Type=oneshot` systemd unit after `keycloak.service`
- Integration test: verify realms/clients are created correctly

**4.2 Extend to other services with runtime state**
- Grafana (dashboards, datasources) — designed but not yet built in declarative-runtime
- Any service with a Terraform/OpenTofu provider

### Phase 5: Advanced (Ongoing)

**5.1 Distributed builds**
- Configure a dedicated build machine for large closures
- Use vzvm for macOS developers needing Linux builds

**5.2 Cross-compilation**
- If mixed-architecture nodes are added, use `extendModules` for aarch64 builds

**5.3 appliance image size optimization**
- Follow the `size-reduction.nix` patterns from the OTA repo
- Target <350MB minimal images

---


---

## Expanded Recommendations (from Best Practices Guide)

## 20. Recommendations for opendesk-edu

### 20.1 Architecture Vision

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    opendesk-edu on SCS K3s                              │
│                                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │  NixOS Base  │  │  NixOS Base  │  │  NixOS Base  │  │  Build Machine│ │
│  │  (A/B OTA)   │  │  (A/B OTA)   │  │  (A/B OTA)   │  │  + Attic Cache│ │
│  │  clrz14-06   │  │  clrz14-07   │  │  ...         │  │  + Remote Build│ │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│         │                  │                  │                  │        │
│         └──────────────────┴──────────────────┘                  │        │
│                            │                                       │        │
│                     ┌──────▼──────┐                                │        │
│                     │  K3s Cluster │  ←── Container images from    │        │
│                     │  (HAProxy    │      dockerTools.buildImage   │        │
│                     │   ingress)   │      signed with Cosign       │        │
│                     │  (Ceph CSI)  │      SBOM via syft            │        │
│                     └─────────────┘                                │        │
│                                                                    │        │
│  ┌─────────────────────────────────────────────────────────────────┘     │
│  │  GitOps: ArgoCD (K8s) + comin (NixOS)                                   │
│  │  Secrets: agenix (NixOS) + External Secrets Operator (K8s)             │
│  │  Tests: testers.runNixOSTest (CI gates)                                │
│  │  Formatting: treefmt + nixfmt + statix + deadnix                       │
│  │  Cache: Attic (S3-backed via Ceph RGW)                                 │
│  └────────────────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────────────┘
```

### 20.2 Priority Actions

**P0 — Immediate (Weeks 1-2)**:
1. Set up **Attic binary cache** on Ceph RGW inside the air-gapped network
2. Add **treefmt** (nixfmt + statix + deadnix) to opendesk-nix flake
3. Add **`checks`** output to flake (eval-only + one integration test)
4. Add **agenix** for NixOS-level secrets (if NixOS is adopted as base OS)
5. Configure **post-build-hook** to auto-upload to Attic

**P1 — Foundation (Weeks 3-4)**:
6. Build **NixOS appliance images** with systemd-repart (simple-systemd-repart pattern)
7. Provision SCS nodes with **nixos-anywhere + disko**
8. Configure **distributed builds** (dedicated build machine as remote builder)
9. Add **integration tests** for key services (mariadb, postgresql, keycloak)
10. Configure **container image builds** with `dockerTools.buildLayeredImage` for all 57 services

**P2 — Advanced (Weeks 5-8)**:
11. Add **A/B OTA updates** with systemd-sysupdate (nixos-appliance-ota-update pattern)
12. Set up **lanzaboote** for Secure Boot + Measured Boot on SCS nodes
13. Implement **impermanence** for ephemeral root (forces explicit state declaration)
14. Adopt **declarative-runtime** pattern for Keycloak runtime state management
15. Add **GPU integration tests** if Ollama or other GPU services are deployed

**P3 — Ongoing**:
16. Monitor nixpkgs for security updates (`system.autoUpgrade` or comin)
17. Expand integration test coverage to all 57 services
18. Optimize image sizes (closure analysis, stripping, layering)
19. Consider **Colmena** for multi-node NixOS deployment
20. Consider **flake-parts** for modular flake organization in opendesk-nix

### 20.3 Migration from Current Architecture

**Current**: Ansible (orchestration) + Nix (devShell + K8s manifests) + Helmfile + ArgoCD

**Target**: NixOS (base OS) + Nix (everything) + ArgoCD (K8s GitOps) + Attic (cache) + agenix (secrets) + Colmena (NixOS deployment) + testers.runNixOSTest (CI)

**Migration steps**:
1. Keep existing Helmfile + ArgoCD for K8s (no change)
2. Add Nix-built container images (`dockerTools.buildLayeredImage`) alongside Helmfile
3. Add Attic cache and remote builder
4. Provision one SCS node with NixOS via nixos-anywhere as a pilot
5. Gradually migrate all nodes to NixOS appliance images
6. Add A/B OTA for safe node updates
7. Add integration tests as CI gates
8. Add declarative-runtime for Keycloak/Grafana runtime state

### 20.4 Key Decisions

| Decision | Recommendation | Rationale |
|---|---|---|
| Binary cache | **Attic** | S3-compatible (Ceph), dedup, multi-tenancy, server-side signing |
| Secrets | **agenix** + **LoadCredential=** | Simple, SSH-key-based, store-safe |
| Deployment | **Colmena** + **nixos-anywhere** | Parallel, stateless, SSH-based |
| Base OS | **NixOS appliance** (systemd-repart) | Immutable, reproducible, A/B OTA |
| OTA | **systemd-sysupdate** | Atomic, auto-revert, battle-tested |
| Secure Boot | **lanzaboote** | UEFI Secure Boot + TPM Measured Boot |
| Ephemeral root | **impermanence** | Forces explicit state declaration |
| Tests | **testers.runNixOSTest** (containers) | 25% faster, no KVM, GPU passthrough |
| Formatting | **treefmt** + nixfmt + statix + deadnix | Automated, consistent |
| Runtime state | **declarative-runtime** (OpenTofu) | Air-gap friendly, LoadCredential secrets |
| Flake structure | **flake-parts** | Modular, reusable, perSystem |
| Image building | **dockerTools.buildLayeredImage** | Layered, cacheable, reproducible |

---

