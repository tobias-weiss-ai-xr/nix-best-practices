# Code Quality & Formatting

### 11.1 treefmt — The Single Source of Formatting Truth

Every serious Nix project should use treefmt with multiple formatters:

```nix
formatter = lib.mapAttrs (_: pkgs:
  pkgs.treefmt.withConfig {
    settings = {
      tree-root-file = "flake.nix";
      on-unmatched = "info";
      formatter = {
        nixfmt = {
          command = lib.getExe pkgs.nixfmt;
          includes = [ "*.nix" ];
        };
        statix = {
          command = lib.getExe pkgs.statix;
          options = [ "fix" ];
          no-positional-arg-support = true;
          includes = [ "*.nix" ];
        };
        deadnix = {
          command = lib.getExe pkgs.deadnix;
          options = [ "--edit" ];
          includes = [ "*.nix" ];
        };
        prettier = {
          command = lib.getExe pkgs.prettier;
          options = [ "--write" ];
          includes = [ "*.md" "*.yaml" "*.yml" "*.json" ];
        };
        shfmt = {
          command = lib.getExe pkgs.shfmt;
          includes = [ "*.sh" "*.bash" ];
        };
        shellcheck = {
          command = lib.getExe pkgs.shellcheck;
          includes = [ "*.sh" "*.bash" ];
          excludes = [ ".envrc" ];
        };
        rustfmt = {  # if Rust code present
          command = lib.getExe pkgs.rustfmt;
          options = [ "--config" "skip_children=true" "--edition" "2024" ];
          includes = [ "*.rs" ];
        };
        taplo = {  # if TOML present
          command = lib.getExe pkgs.taplo;
          options = [ "format" ];
          includes = [ "*.toml" ];
        };
      };
    };
  }) inputs.nixpkgs.legacyPackages;
```

**Run**: `nix fmt` (or `nix build .#formatter` then run the result)

### 11.2 statix — Nix Linter

statix detects anti-patterns:
- `rec` usage where `let...in` would be better
- `with` at top level
- `<nixpkgs>` lookup paths in flakes
- Unquoted URLs

```bash
statix check .       # check
statix fix .         # auto-fix (also via treefmt)
```

### 11.3 deadnix — Dead Code Removal

```bash
deadnix --edit .     # remove unused bindings (also via treefmt)
```

### 11.4 nixfmt — The Official Nix Formatter

```bash
nixfmt .             # format all .nix files
```

### 11.5 Other Quality Tools

| Tool | Purpose |
|---|---|
| `alejandra` | Alternative opinionated Nix formatter (faster, different style) |
| `nix-diff` | Explain why two Nix derivations differ |
| `nix-index` | Index the nix store for fast file lookups |
| `manix` | Search NixOS option and function documentation |
| `nh` | Better CLI for nix, nixos-rebuild, home-manager |
| `comma` | Run any binary with nix run (wraps nix-index) |
| `nix-alien` | Run unpatched binaries on NixOS |
| `dix` | Diff Nix-related things |

### 11.6 CI Quality Gates

```nix
checks = lib.mapAttrs (system: pkgs:
  # Eval-only checks (fast, catches option-name drift)
  lib.mapAttrs' (name: cfg:
    lib.nameValuePair "eval-${name}"
      (evalSystem system cfg).config.system.build.toplevel
  ) configurations
  # VM integration tests (slower, catches runtime issues)
  // {
    integration-test = pkgs.testers.runNixOSTest ./tests/integration.nix;
  }
  # Formatting check
  // {
    formatting = inputs.self.formatter.${system}.check inputs.self;
  }
) inputs.nixpkgs.legacyPackages;
```


---

