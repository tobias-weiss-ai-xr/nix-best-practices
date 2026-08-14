# Flake Architecture & Project Structure

### 8.1 flake-parts — Modular Flake Organization

**flake-parts** provides a module system for flakes, letting you split
`flake.nix` into focused files and reuse project logic.

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      flake = {
        nixosConfigurations = { ... };
        nixosModules = { ... };
      };
      systems = [ "x86_64-linux" "aarch64-linux" ];
      perSystem = { pkgs, ... }: {
        devShells.default = pkgs.mkShell { ... };
        packages = { ... };
        checks = { ... };
        formatter = pkgs.treefmt;
      };
    };
}
```

**Benefits**:
- Split flake into multiple files (each in its own module)
- `perSystem` automatically handles `forEachSystem` boilerplate
- Reusable modules shared across projects
- Used by sysmodule-flake (applicative-systems) for auto-discovering configurations

### 8.2 Flake Best Practices (from nixos.wiki, nix.dev, applicative-systems)

| Practice | Rationale |
|---|---|
| Pin nixpkgs with `flake.lock` | Reproducibility |
| Use `follows` for sub-input nixpkgs | Avoid multiple nixpkgs versions |
| Set `config = {}` and `overlays = []` when importing nixpkgs | Purity |
| Use `lib.fileset` for source filtering | Precise store paths, better caching |
| Use `builtins.path` with `name` for reproducible paths | Path name doesn't leak into store path |
| Quote URLs in fetch calls | Unquoted URLs are parsed as paths |
| Use `let...in` instead of `rec` | Avoid infinite recursion, easier to reason |
| Avoid `with` at top of file | Ambiguous scoping |
| Use `lib.recursiveUpdate` for nested attrsets | `//` is shallow only |
| Don't put secrets in flake files | Store is world-readable |
| `git add` new files before `nix build` | Flakes only include git-tracked files |
| Use `nix flake check` in CI | Catch evaluation errors |
| Ship `checks` in flake outputs | CI gates (eval-only + VM tests) |
| Use `treefmt` + `nixfmt` + `statix` + `deadnix` | Automated formatting and linting |

### 8.3 Flake Outputs Reference

| Output | Purpose |
|---|---|
| `packages.${system}.default` | Default package |
| `devShells.${system}.default` | Development shell |
| `nixosConfigurations.${name}` | NixOS system configurations |
| `nixosModules.default` | Reusable NixOS modules |
| `overlays.default` | nixpkgs overlays |
| `apps.${system}.default` | `nix run` apps |
| `checks.${system}` | CI checks |
| `formatter.${system}` | Code formatter (e.g., treefmt) |
| `lib` | Library functions (not system-specific) |
| `legacyPackages.${system}` | Non-flake package set |

### 8.4 npins — Non-Flake Source Pinning

For projects that can't or won't use flakes, npins provides source pinning:
```bash
npins init --bare
npins add github NixOS nixpkgs --branch nixos-24.11
# In default.nix:
let sources = import ./npins; in import sources.nixpkgs { ... }
```


---


---

## Additional: npins for Source Pinning (from Intel Report)

### 5.7 npins for Source Pinning (Non-Flake Alternative)

If flakes are not desired for some components:
```bash
npins init --bare
npins add github NixOS nixpkgs --branch nixos-24.11
# In default.nix:
let sources = import ./npins; in import sources.nixpkgs { ... }
```

**For opendesk-edu**: The current flake.nix already uses flakes with `flake.lock`
for pinning. npins is an alternative if any non-flake components need pinning.

