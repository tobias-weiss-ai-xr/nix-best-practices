# Nix Best Practices — Do and Don't


Synthesized from nix.dev `guides/best-practices.md` and the applicative-systems
repos:

### 6.1 Do

| Practice | Why | Source |
|---|---|---|
| Quote URLs in fetch calls | Unquoted URLs are parsed as paths | nix.dev best-practices |
| Use `let...in` instead of `rec` | `rec` can cause infinite recursion, harder to reason about | nix.dev best-practices |
| Set `config = {}` and `overlays = []` when importing nixpkgs | Makes purity explicit, prevents accidental overrides | nix.dev best-practices |
| Use `builtins.path` with `name` for source paths | Ensures reproducible store paths regardless of directory name | nix.dev best-practices |
| Use `lib.fileset` for precise source filtering | Only needed files enter the store; better caching | nix.dev working-with-local-files |
| Use `lib.recursiveUpdate` for nested attrsets | `//` only does shallow merge | nix.dev best-practices |
| Use treefmt + nixfmt + statix + deadnix | Automated formatting and linting | gcan, declarative-runtime |
| Use `inputsFrom` in mkShell | Share build deps between default.nix and shell.nix | gcan, nix.dev recipes |
| Use `LoadCredential=` for secrets | Keeps secrets out of the world-readable Nix store | declarative-runtime |
| Ship `checks` in flake outputs | CI gates via `nix flake check` | all applicative-systems repos |
| Use `extendModules` for architecture variants | Single config, multiple targets | OTA, cross-compilation repos |
| Vendor Terraform providers via `opentofu.withPlugins` | No registry access at runtime (air-gap friendly) | declarative-runtime |

### 6.2 Don't

| Anti-pattern | Why | Source |
|---|---|---|
| `rec` at top level of file | Hard to read, can cause infinite recursion | nix.dev best-practices |
| `with` at top of file | Ambiguous scoping, conflicts with `let` | nix.dev best-practices |
| `<nixpkgs>` lookup paths in flakes | Impure, not reproducible | nix.dev best-practices |
| `src = ./..` (whole parent dir) | Embeds path name in store path, copies everything | nix.dev working-with-local-files |
| Secrets in the Nix store | Store is world-readable | declarative-runtime |
| Remote Terraform state for per-host config | Unnecessary complexity; local state is simpler | declarative-runtime CLAUDE.md |
| Drift detection timers for reconciliation | Run-once with `restartTriggers` is simpler and sufficient | declarative-runtime CLAUDE.md |
| Terraform (BSL license) | Use OpenTofu (MPL 2.0, free) | declarative-runtime CLAUDE.md |


---

