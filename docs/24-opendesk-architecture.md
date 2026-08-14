# Current opendesk-edu / opendesk-nix Architecture

### 7.1 opendesk-edu/nix/flake.nix

**Inputs**: `nixpkgs` (nixos-24.11), `flake-utils`, `opendesk-nix` (local path
`../../opendesk-nix`).

**Outputs**: `devShell` with pinned tooling (kubectl 1.32.3, helm 3.15.3,
helmfile 0.150.0, ansible 2.16.0, yq-go) and K8s manifest generation via
`opendesk-nix.lib.k8s`.

**Services** (57 files in `nix/k8s/`): argocd, bigbluebutton, bookstack, clamav,
collabora, elasticsearch, etherpad, excalidraw, filebeat, grommunio, ilias,
ilias-full, jitsi, jupyterhub, kasmvnc, kibana, kube-prometheus-stack, limesurvey,
loki, mariadb, memcached, monitoring, moodle, n8n, ollama, opencloud, openproject,
open-webui, overleaf, planka, portal-entries, postgresql, promtail, redis,
rstudio, seaweedfs, self-service-password, semester-provisioning, slidev, snipr,
sogo, stalwart, timescale, ttyd, typo3, xwiki, zammad, dask, intercom, coderd,
code-server, collab-dashboard, drawio, eudi-issuer, f13.

**Stack**: Ansible (orchestration) + Nix (pinned tooling + K8s manifest generation)
+ Helmfile (K8s packages) + ArgoCD (GitOps).

### 7.2 opendesk-nix/platform/nix/

The consolidated Nix library with DevGuard security patterns:

| File | Purpose |
|---|---|
| `types.nix` | Custom Nix types for validation |
| `security.nix` | Security scanning patterns |
| `security-scanning.nix` | Trivy, Grype, Syft integration |
| `sbom.nix` | SBOM generation (CycloneDX/SPDX) |
| `compliance.nix` | Compliance checks (SCS, BSI) |
| `cosign.nix` | Container image signing with Cosign |
| `registry.nix` | Multi-registry support (local registry for air-gap) |
| `k8s.nix` | K8s manifest generation library |
| `build.nix` | Container builds (dockerTools.buildImage) |
| `dev.nix` | DevShell definitions |
| `operators.nix` | K8s operator patterns |
| `cicd.nix` | CI/CD pipeline definitions |
| `integrated-devguard.nix` | Integrated DevGuard (security + compliance + SBOM) |
| `tests.nix` | Test utilities |
| `nixos/containers.nix` | NixOS container patterns |
| `nixos/security.nix` | NixOS security hardening |
| `nixos/services.nix` | NixOS service definitions |

**Container builds**: `mariadb-opendesk`, `postgresql-opendesk`, `redis-opendesk`
via `dockerTools.buildImage`.

### 7.3 Gaps Identified

1. **No NixOS base OS**: SCS K3s nodes run a traditional Linux, not NixOS. The
   appliance image pattern (Part II.1) could provide an immutable, reproducible
   base OS.
2. **No binary cache**: No self-hosted `nix-serve` for the air-gapped
   environment. Builds depend on `cache.nixos.org` (via proxy) or local builds.
3. **No integration tests**: No `testers.runNixOSTest` checks in the flake. The
   applicative-systems pattern of shipping `checks` for every module is missing.
4. **No treefmt formatter**: No `formatter` output in the flake for automated
   Nix formatting/linting.
5. **No distributed builds**: No remote builder configuration for offloading
   large builds.
6. **No OTA updates**: No `systemd-sysupdate` / A/B partition scheme for node OS
   updates.
7. **Runtime state management**: K8s services (Keycloak, Grafana) have runtime
   state not managed by Helmfile/ArgoCD. The declarative-runtime pattern could
   fill this gap.
8. **No `checks` output**: The flake has no `checks` for CI validation.

---

