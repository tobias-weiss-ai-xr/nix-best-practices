# Performance & Image Size Optimization

### 17.1 Closure Analysis

```bash
# List all transitive dependencies of a derivation
nix-store --query --requisites $(nix build --print-out-paths .#default)

# Show closure size
nix path-info -S .#default

# Show why a package is in the closure
nix why-depends .#default nixpkgs#python3

# List the biggest paths in a closure
nix-store --query --requisites $(nix build --print-out-paths .#default) \
  | xargs -I{} du -sh {} | sort -rh | head -20
```

### 17.2 Reducing Image Size

| Technique | Effect |
|---|---|
| Remove unnecessary `environment.systemPackages` | Direct reduction |
| Use `lib.stripDebugInfo` | Strips debug symbols from binaries |
| `fonts.fontconfig.cache = 32` | Pre-generate font cache (smaller image) |
| `boot.initrd.systemd.strip = true` | Smaller initrd |
| `documentation.enable = false` | Remove man pages and docs |
| `documentation.nixos.enable = false` | Remove NixOS documentation |
| Use `dockerTools.buildLayeredImage` | Layered images share layers across images |
| Use `dockerTools.streamLayeredImage` | No intermediate tarball, streams to docker |
| `nixpkgs.config.replaceStdenv` | Smaller stdenv (advanced, may break things) |

### 17.3 Container Image Layering

```nix
# Each package in its own layer → better caching
dockerTools.buildLayeredImage {
  name = "myapp";
  contents = [ pkgs.bash pkgs.coreutils myapp ];
  maxLayers = 100;
}
```

Shared layers (e.g., `bash`, `coreutils`) are pulled once and cached across all
images that use them.

### 17.4 Build Performance

| Technique | Effect |
|---|---|
| Remote builders | Offload builds to powerful machines |
| Binary cache (Attic) | Share built paths across all machines |
| `nix-build --max-jobs` | Parallel local builds |
| `nix build --cores` | Limit cores per build |
| `nix-daemon` priority | `nix.settings.max-jobs` and `nix.settings.cores` |
| Flakes with `--recreate-lock-file` | Update all inputs |
| `nix flake archive` | Upload flake to cache for reproducibility |


---

