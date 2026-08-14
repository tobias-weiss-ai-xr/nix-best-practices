# Development Workflow & Developer Experience

### 14.1 direnv — Automatic Shell Activation

```bash
# .envrc
use flake
# or for non-flake:
use nix
```

With `nix-direnv` (recommended for performance):
```bash
# .envrc
use flake .#devShell
```

`nix-direnv` caches the nix shell evaluation, so entering a directory is instant
after the first time. Combined with `shellHook`, this provides automatic
environment setup:

```nix
devShells.default = pkgs.mkShell {
  packages = [ pkgs.kubectl pkgs.helm pkgs.helmfile pkgs.ansible ];
  shellHook = ''
    export KUBECONFIG=$PWD/.kube/config
    export ANSIBLE_CONFIG=$PWD/ansible/ansible.cfg
    echo "Welcome to opendesk-edu dev shell"
  '';
};
```

### 14.2 Sharing Dependencies Between default.nix and shell.nix

From nix.dev `recipes/sharing-dependencies`:
```nix
# default.nix
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShellNoCC {
  inputsFrom = [ (pkgs.callPackage ./package.nix { }) ];
  packages = [ pkgs.git ];
}
```

`inputsFrom` inherits build dependencies from the package, so `default.nix` and
`shell.nix` share the same environment.

### 14.3 Reproducible Scripts

```bash
#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3Packages.requests python3Packages.pyyaml
#!nix-shell -I nixpkgs=channel:nixos-24.11
import requests
import yaml
# ...
```

Or with flakes:
```bash
#!/usr/bin/env nix
#!nix shell nixpkgs#python3Packages.requests nixpkgs#python3Packages.pyyaml -c python3
import requests
import yaml
# ...
```

### 14.4 nix flake check in CI

```yaml
# .github/workflows/ci.yml
- uses: cachix/install-nix-action@v27
- uses: cachix/cachix-action@v15
  with:
    name: opendesk
    signingKey: '${{ secrets.CACHIX_SIGNING_KEY }}'
- run: nix flake check
- run: nix build .#default
```

For air-gapped CI (no Cachix):
```yaml
- uses: cachix/install-nix-action@v27
  with:
    extra_nix_config: |
      substituters = http://attic.internal:8080
      trusted-public-keys = attic.internal:...
- run: nix flake check
- run: nix build .#default
```

### 14.5 Justfile for Simplifying Commands (from nixos-and-flakes)

```makefile
# Justfile
build:
    nix build .#default

switch:
    sudo nixos-rebuild switch --flake .#myhost

test:
    nix flake check

fmt:
    nix fmt

update:
    nix flake update

shell:
    nix develop
```


---


---

## Additional: CI with Cachix (from Intel Report)

### 5.6 CI with Cachix (Adapted for Air-Gap)

Standard Cachix flow (requires internet):
```yaml
- uses: cachix/install-nix-action@v27
- uses: cachix/cachix-action@v15
  with: { name: opendesk, signingKey: '${{ secrets.CACHIX_SIGNING_KEY }}' }
```

**Air-gapped adaptation**: Replace Cachix with the self-hosted `nix-serve`
cache. CI builds push to the internal cache via post-build-hook. The CI runner
itself must be inside the air-gapped network or have proxy access.


## Additional: direnv (from Intel Report)

### 5.8 direnv for Developer Experience

```bash
# .envrc
use flake
# or for non-flake:
use nix
```

Automatic shell activation when entering the project directory. Combined with
`shellHook` for environment setup (KUBECONFIG, etc.).

---

