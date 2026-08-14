# Deployment & Orchestration

### 7.1 Colmena — Multi-Host NixOS Deployment

**Colmena** is a stateless NixOS deployment tool (like NixOps/morph) that
supports parallel deployment, tag-based node selection, and flakes.

```nix
# hive.nix (or flake.nix output)
{
  meta = {
    nixpkgs = import nixpkgs { system = "x86_64-linux"; };
    # Per-node nixpkgs override:
    nodeNixpkgs = { node-b = ./another-nixpkgs-checkout; };
    # Remote builders:
    # machinesFile = ./machines.client-a;
  };

  defaults = { pkgs, ... }: {
    environment.systemPackages = with pkgs; [ vim wget curl ];
    # Don't overwrite unknown remote profiles by default:
    # deployment.replaceUnknownProfiles = true;
  };

  node-a = { name, nodes, ... }: {
    networking.hostName = name;
    time.timeZone = nodes.node-b.config.time.timeZone;
    boot.loader.grub.device = "/dev/sda";
    deployment = {
      targetHost = "node-a.example.com";
      targetPort = 22;
      buildOnTarget = false;  # build locally, copy closure
    };
  };

  node-b = {
    deployment.targetHost = "node-b.example.com";
    # ...
  };
}
```

**Usage**:
```bash
colmena apply                    # deploy to all nodes
colmena apply --on @tag-a        # deploy to tagged nodes
colmena build                    # build without deploying
colmena eval                     # evaluate without building
```

**For SCS K3s**: Colmena can deploy NixOS configurations to all cluster nodes
in parallel, which is more efficient than `nixos-rebuild` per node.

### 7.2 nixos-rebuild (Standard)

```bash
nixos-rebuild switch --flake .#hostname          # local
nixos-rebuild switch --flake .#hostname --target-host root@node  # remote
nixos-rebuild test --flake .#hostname            # test without switching
nixos-rebuild build --flake .#hostname           # build only
```

### 7.3 deploy-rs

Alternative to Colmena with a different API:
```bash
deploy .#hostname --hostname node.example.com
```

### 7.4 comin — GitOps for NixOS

**comin** continuously pulls NixOS configurations from a Git repository and
rebuilds. This is the NixOS equivalent of ArgoCD for Kubernetes:
```nix
services.comin = {
  enable = true;
  settings = {
    endpoint = "https://git.internal/opendesk/nixos-config.git";
    branch = "main";
    polling_interval = 60;
  };
};
```

### 7.5 Nixinate — Flake-Based SSH Deployment

```nix
# In flake.nix outputs:
apps = nixinate.nixinate self {
  hostname = "node.example.com";
  sshUser = "root";
  buildOn = "remote";  # or "local"
};
```

### 7.6 Recommendation for opendesk-edu

For the SCS K3s cluster:
- **Colmena** for NixOS host deployment (if NixOS is adopted as the base OS)
- **ArgoCD** remains for K8s manifest deployment (already in the stack)
- **comin** could complement ArgoCD for NixOS-level GitOps
- **nixos-anywhere** for initial provisioning of new nodes


---

