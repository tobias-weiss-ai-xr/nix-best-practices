# Cross-Cutting Patterns from Applicative Systems Repos


Across all repos, several patterns recur that are directly applicable to
opendesk-edu:

### 3.1 treefmt as Single Source of Formatting Truth

Every non-trivial repo uses **treefmt** with **nixfmt** (formatting), **statix**
(linting with auto-fix), and **deadnix** (dead code removal with `--edit`):

```nix
formatter = lib.mapAttrs (_: pkgs:
  pkgs.treefmt.withConfig {
    settings = {
      tree-root-file = "flake.nix";
      on-unmatched = "info";
      formatter = {
        nixfmt = { command = lib.getExe pkgs.nixfmt; includes = [ "*.nix" ]; };
        statix = { command = lib.getExe pkgs.statix; options = [ "fix" ];
                   no-positional-arg-support = true; includes = [ "*.nix" ]; };
        deadnix = { command = lib.getExe pkgs.deadnix; options = [ "--edit" ];
                    includes = [ "*.nix" ]; };
      };
    };
  }) inputs.nixpkgs.legacyPackages;
```

**Recommendation**: Add this to opendesk-nix's flake as `formatter` output.

### 3.2 `extendModules` for Cross-Compilation and Variants

The OTA and cross-compilation repos use `extendModules` to derive architecture
variants from a single base configuration without duplication:

```nix
defaultImage = extendConfiguration inputs.self.nixosConfigurations.appliance (
  { lib, ... }: {
    nixpkgs.buildPlatform = lib.mkDefault linuxSystem;
    nixpkgs.hostPlatform = lib.mkDefault linuxSystem;
  });
```

### 3.3 `forEachSystem` / `eachSystem` Pattern

Two variants appear:
```nix
# OTA repo variant (mapAttrs + genAttrs):
forEachSystem = f:
  builtins.mapAttrs (system: g: g inputs.nixpkgs.legacyPackages.${system})
    (lib.genAttrs systems f);

# gcan variant (foldl'):
eachSystem = systems: f:
  builtins.foldl' (a: s: a // builtins.mapAttrs (k: v: (a.${k} or {}) // { ${s} = v; }) (f s))
    {} systems;
```

### 3.4 NixOS Integration Tests as CI Gates

Every repo with NixOS modules ships `checks` in the flake:
```nix
checks = lib.mapAttrs (system: pkgs:
  # ... testers.runNixOSTest for each module
) inputs.nixpkgs.legacyPackages;
```

The declarative-runtime repo adds eval-only checks (option-name drift detection
without paying for a full VM test):
```nix
checks = ... // (lib.mapAttrs' (name: cfg:
  lib.nameValuePair "example-${name}"
    (exampleSystem system cfg).config.system.build.toplevel
) examples);
```

### 3.5 `inputsFrom` for Shared Dev Shells

```nix
devShells.default = pkgs.mkShell {
  inputsFrom = [ inputs.self.packages.${system}.default ];
  packages = [ pkgs.cargo pkgs.rustc pkgs.clippy ... ];
};
```

### 3.6 Vendor Terraform Providers via Nix (Air-Gap Pattern)

The declarative-runtime repo vendors the Forgejo provider via
`terraform-providers.mkProvider` and wraps it with
`pkgs.opentofu.withPlugins`:
```nix
executor = pkgs.opentofu.withPlugins (_: [ provider ]);
```
This means **no registry access at activation time** — critical for air-gapped
environments.

### 3.7 systemd `LoadCredential=` for Secret Management

The declarative-runtime pattern of loading secrets via systemd
`LoadCredential=` and passing them as `TF_VAR_*` environment variables is a
general best practice for keeping secrets out of the Nix store:
```nix
LoadCredential = lib.mapAttrsToList (id: path: "${id}:${path}") allCredentials;
# In script:
export "TF_VAR_$id=$(cat "$CREDENTIALS_DIRECTORY/$id")"
```

### 3.8 UKI Boot + Squashfs Store = Immutable Appliance

The appliance image pattern across three repos (OTA, simple-repart,
cross-compilation):
1. Build a Unified Kernel Image (UKI) containing kernel + initrd + cmdline
2. Store the nix closure in a read-only squashfs partition
3. Boot via systemd-boot from the ESP partition
4. Optionally use A/B slots with systemd-sysupdate for atomic updates


---

