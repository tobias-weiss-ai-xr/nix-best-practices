# Nix-Spirit Integration Status — opendesk-edu / SCS K3s

> Status: **2026-08-15** · Audit of *where the Nix philosophy* (declarative,
> reproducible, immutable, single-source-of-truth, composable) is actually
> embodied in the project code — by stack layer, with evidence and open gaps.
> Companion to `24-opendesk-architecture.md` (what exists) and
> `25-recommendations.md` (what to improve).

## Declared stack

```
Ansible (orchestration)
  + Nix  (pinned tooling + K8s manifest generation)
  + Helmfile (K8s packages)
  + ArgoCD (GitOps)
```

Nix is one of four pillars. The Nix spirit is **fully realized** in the
*build* and *abstraction* layers, **present-but-not-applied** in the *live OS*
layer, and **partial** in *secrets*.

## Integration by layer

| # | Layer | Status | Evidence |
|---|-------|--------|----------|
| 0 | Reproducibility root | ✅ | `opendesk-nix/flake.lock` pins every input (nixpkgs 24.11, flake-utils, treefmt, attic, comin) |
| 1 | Container build | ✅ | Images built with Nix `dockerTools.buildImage`/`buildLayeredImage` via `platform/nix/docks.nix` `mkImage` — **no Dockerfiles**; layered & content-addressed |
| 2 | Supply chain | ✅ | SBOM (`sbom.nix`/`sbomnix`), `cosign-policies.nix`, `integrated-devguard.nix`, `compliance.nix` — attestations & provenance |
| 3 | K8s as Nix values | ✅ | `platform/kubernetes/` is a composable library: `lib.deployment` / `lib.pvc` / `lib.service` / `lib.ingressWithCert` / `lib.secret` (`k8s.nix`). Each service is a pure function returning a resource list |
| 4 | Composable blocks | ✅ | `core/{databases,identity,networking,storage}`, `security/{emergency,policy-backup}`, `nix-builder`, `groupware`, `learning` |
| 5 | Single source of truth | ✅ | `environments/{scs,hrz,demo,local,overrides}` — one config composes all envs; e.g. `overrides/hrz/mariadb.nix` overrides storage class per env |
| 6 | Binary cache | ✅ | `attic` (flake input + `modules/binary-cache-client.nix`, `attic-server.nix`, `post-build-hook.nix`) — shared hermetic builds |
| 7 | Secrets | ⚠️ partial | **sops-nix** used by `platform/docker` services (`secrets.nix` → `config.sops.secrets.*`); **but `platform/kubernetes/services/opencloud.nix` hardcodes plaintext secrets** |
| 8 | Host / OS (NixOS) | ⚠️ partial | `configurations/k3s-node.nix` (full NixOS K3s node), `disko/` (declarative disks), `modules/` (appliance-image, remote-builders) all exist as code |
| 9 | OS GitOps | ⚠️ partial | `comin` declared as flake input ("ArgoCD for the OS") but **not wired** into host configs |
| 10 | App GitOps | ✅ | Nix-generated k8s YAML → GitLab `opendesk-edu` → **ArgoCD** syncs to cluster (Git = source of truth, self-healing) |
| 11 | Code quality / docs | ✅ | `treefmt-nix`; this knowledge base (26+ topic docs) codifies the philosophy |

## Key insight

Nix is **deep in build + abstraction**, **shallow in live OS**.

The **live SCS K3s cluster runs Ubuntu** (`kubectl get nodes` →
`Ubuntu 24.04.4 LTS`), provisioned via **Ansible + Helmfile** — *not* via the
NixOS `configurations/k3s-node.nix`. So the OS-layer Nix (Layers 8–9) is
*designed and coded but not yet applied* to the running cluster. `comin` is
present but dormant.

## Gaps & remediation plan

### Gap A — Live base OS is Ubuntu, not NixOS *(Layers 8–9)*
- `configurations/k3s-node.nix` + `disko/` + `comin` exist as an "appliance image"
  target (`specs/technical/APPLIANCE-IMAGE-SPEC.md`) but are **not the running
  SCS nodes**.
- **Remediation:** wire `comin` into `k3s-node.nix` (`services.comin.enable =
  true`) and promote the SCS nodes to NixOS via `nixos-anywhere`/`disko`.
  ⚠️ **Cluster-affecting / destructive** — requires a separate explicit go-ahead;
  do NOT run against the live cluster without a staged rollout plan.

### Gap B — `comin` not wired *(Layer 9)*
- Declared as flake input, no `services.comin` in any `configurations/` module.
- **Remediation:** add comin module + SSH deploy key; see `11-deployment.md`.

### Gap C — OpenCloud bypasses sops-nix *(Layer 7)*
- `services/opencloud.nix` hardcodes `jwt_secret`, LDAP bind passwords, service
  account secrets as plaintext in the Nix source, while sibling `platform/docker`
  services use encrypted `config.sops.secrets.*`.
- **Remediation:** this is a *design* decision for K8s (sops-nix is NixOS-host
  oriented). Options: (1) sops-encrypt the `opencloud.yaml` blob, decrypt in CI,
  apply as a K8s `Secret`; (2) `sealed-secrets` / `external-secrets` in-cluster.
  Pick one before editing code. (Incident 2026-08-15 config also needs the PVC
  fix below.)

### Gap D — OpenCloud PVC was RWX on ceph-cephfs *(Layers 3–5, config correctness)*
- **Root cause of the 2026-08-15 BoltDB/Bleve corruption:** a single-replica
  workload on a multi-writer filesystem.
- **Fix (applied on disk in `services/opencloud.nix`):** `accessModes` →
  `ReadWriteOnce`, `storageClass` → `env.storage.rwo` (ceph-rbd); image pinned to
  `7.2.2` (`:latest` pulled shifting builds that re-corrupted on restart).
- **Deploy note:** `storageClassName`/`accessModes` are immutable on a bound PVC.
  To apply: `kubectl -n opendesk-edu delete pvc opendesk-opencloud-data` (OpenCloud
  regenerates idm/search/nats/storage on startup); ArgoCD recreates it as RWO.
- ⚠️ This edit currently sits in the **broken `opendesk-nix` working tree** (see
  Gap E) and cannot be committed/deployed until that repo is repaired.

### Gap E — `opendesk-nix` repo in broken git state *(hygiene)*
- `git status` reports ~6464 deleted files, bogus `..sisyphus/` index paths, and
  `flake.nix` untracked. The working tree is massively out of sync with HEAD.
- **Remediation:** do **not** `git add -A` / `git commit` / `git checkout` here
  (would delete ~6464 files or lose changes). Investigate with `git fsck`, recover
  the correct HEAD, and re-sync the working tree before any deploy.

## What is already "Nix-native" and should be preserved
- Herdmetic, pinned, Dockerfile-free image builds (Layer 1).
- K8s-as-Nix-values library + environment composition (Layers 3–5).
- Attic binary cache + SBOM/Cosign/DevGuard supply chain (Layers 2, 6).
- ArgoCD GitOps fed by Nix-generated manifests (Layer 10).
