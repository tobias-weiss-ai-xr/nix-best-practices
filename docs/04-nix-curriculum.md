# The 9-Section Nix Curriculum (nix.dev)


All content below is synthesized from the locally cloned nix.dev repository at
`~/git/nix.dev/source/`.

### 01 — Using Nix

**Installation** (`install-nix.md`):
- Multi-user (default, recommended): `sh <(curl -L https://nixos.org/nix/install) --daemon`
- Single-user: `--no-daemon`
- macOS: multi-user installer uses `launchd`
- WSL2: use `--no-daemon` or the NixOS WSL distro
- Docker: `docker run -it nixos/nix` for ephemeral environments
- Determinate Systems installer: `nix-installer` (idempotent, better uninstall)

**Ad-hoc shell environments** (`first-steps/ad-hoc-shell-environments.md`):
```bash
nix-shell -p git jq                      # temporary shell with packages
nix-shell -p git --run "git --version"   # run command and exit
nix-shell -p git --pure                   # isolated shell (no PATH inheritance)
nix-shell -I nixpkgs=channel:nixos-24.11 -p git  # specific channel
```

**Declarative shell** (`first-steps/declarative-shell.md`):
```nix
# shell.nix
{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShellNoCC {
  packages = [ pkgs.git pkgs.jq ];
  GREETING = "Hello";
  shellHook = ''echo "$GREETING"'';
}
```
Pin with `fetchTarball`:
```nix
{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/<hash>.tar.gz") {} }:
```

**Reproducible scripts** (`first-steps/reproducible-scripts.md`):
```bash
#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3Packages.requests
#!nix-shell -I nixpkgs=channel:nixos-24.11
import requests
# ...
```

**Garbage collection**:
```bash
nix-collect-garbage --delete-old           # delete old generations
nix-collect-garbage --delete-older-than 7d # time-based
nix store gc                               # Nix 2.x command
```

### 02 — Nix Language Basics

**Derivations** are the fundamental unit — a function call producing a store path:
```nix
derivation {
  name = "hello";
  builder = "${bash}/bin/bash";
  args = [ "-c" "echo hello > $out" ];
  system = builtins.currentSystem;
}
```

**Key builtins**: `map`, `filter`, `foldl'`, `attrValues`, `attrNames`, `getAttr`,
`hasAttr`, `length`, `head`, `tail`, `genAttrs`, `replaceStrings`, `stringAsChars`,
`toJSON`, `fromJSON`, `path`, `pathExists`, `readFile`, `readDir`, `fetchurl`,
`fetchTarball`, `fetchgit`, `fetchzip`.

**Attribute sets**: `{ a = 1; b = 2; }`, `rec` for recursive refs, `let...in`
for non-recursive scoping, `with` for bringing attrs into scope (avoid at top
level), `inherit` for concise attr copying.

**Functions**: currying (`a: b: a + b`), attribute set args with defaults
(`{ a, b ? 2, ... }@args:`), `@` pattern for capturing the full arg set.

**Paths vs strings**: `./foo` is a path (copied to store), `"${./foo}"` is a
string (store path as string), `<nixpkgs>` is a lookup path (avoid in flakes).

**Imports**: `import ./foo.nix` evaluates a Nix file; `import` can take a
derivation (fetched tarball) too.

### 03 — Input Determinism

**Pinning nixpkgs** (`towards-reproducibility-pinning-nixpkgs.md`):
```nix
{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/<commit>.tar.gz") {} }:
```
Use `status.nixos.org` to find the latest commit for a channel.

**Channels vs pinned**: Channels (`nixos-24.11`, `nixos-unstable`) move;
`fetchTarball` with a specific commit is fully reproducible.

**npins** (`recipes/dependency-management.md`): Non-flake alternative for
pinning sources:
```bash
npins init --bare
npins add github NixOS nixpkgs
# In default.nix:
let sources = import ./npins; in import sources.nixpkgs { ... }
```

**Flakes** (`concepts/flakes.md`): `flake.lock` pins all inputs transitively.
`nix flake update` updates the lock file. `follows` lets an input follow another
input's nixpkgs version.

### 04 — Stdenv Basics

**`mkDerivation`** (`packaging-existing-software.md`):
```nix
stdenv.mkDerivation {
  pname = "example";
  version = "1.0.0";
  src = fetchFromGitHub { owner = "..."; repo = "..."; rev = "..."; hash = "..."; };
  nativeBuildInputs = [ pkg-config cmake ];
  buildInputs = [ openssl ];
  installPhase = ''runHook preInstall; make install; runHook postInstall'';
}
```

**Phases**: `configurePhase`, `buildPhase`, `checkPhase`, `installPhase`,
`fixupPhase`. Each has `pre*`/`post*` hooks via `runHook`.

**`nativeBuildInputs` vs `buildInputs`**: `nativeBuildInputs` run on the build
machine (compilers, pkg-config); `buildInputs` are linked into the output
(libraries).

### 05 — Basic Nix Patterns

**`callPackage`** (`callpackage.md`): Automatic argument filling from the package
set:
```nix
{ stdenv, lib, fetchFromGitHub, openssl }:  # auto-filled by callPackage
stdenv.mkDerivation { ... }
```

**`override`**: Change a single argument without rewriting:
```nix
pkgs.python3.override { enableOptimizations = true; }
```

**`callPackageWith`**: Create a custom package set with overridden arguments:
```nix
let myPkgs = lib.callPackageWith (pkgs // { openssl = pkgs.openssl_3; }) ./foo.nix;
in myPkgs
```

**Anti-patterns to avoid** (from `guides/best-practices.md`):
- Avoid `rec` at top level (use `let...in`)
- Avoid `with` at top of file (ambiguous, conflicts)
- Avoid `<nixpkgs>` lookup paths in flakes
- Quote URLs in fetch calls
- Set `config = {}` and `overlays = []` when importing nixpkgs explicitly
- Use `builtins.path` with `name` for reproducible source paths
- Use `lib.recursiveUpdate` for nested attrsets

### 06 — Advanced Stdenv

**`lib.fileset`** (`working-with-local-files.md`):
```nix
lib.fileset.toSource {
  root = ./.;
  fileset = lib.fileset.intersection
    (lib.fileset.difference ./. ./.git)
    (lib.fileset.gitTracked ./.);
}
```
Functions: `toSource`, `unions`, `difference`, `intersection`, `fileFilter`,
`gitTracked`, `maybeMissing`. More precise than `src = ./.` (which copies
everything) or `src = ./subdir` (which embeds the path name).

**Cross-compilation** (`cross-compilation.md`):
```nix
pkgsCross.aarch64-multiplatform.hello  # cross-compile for aarch64
pkgsStatic.hello                        # fully static linking
# In NixOS:
nixpkgs.buildPlatform = "x86_64-linux";  # where it builds
nixpkgs.hostPlatform = "aarch64-linux";  # where it runs
```
`nativeBuildInputs` = build machine tools; `buildInputs` = host machine libraries.

**`builtins.path`** with `name` for reproducible source paths:
```nix
src = builtins.path { path = ./.; name = "source"; };
```

### 07 — Package Overrides

**Overlays** via `config` and `overlays` when importing nixpkgs:
```nix
pkgs = import nixpkgs {
  config = { allowUnfree = true; };
  overlays = [ (self: super: { mypkg = ...; }) ];
};
```

**`overrideAttrs`**: Modify a derivation's attributes:
```nix
pkgs.hello.overrideAttrs (old: { patches = (old.patches or []) ++ [ ./fix.patch ]; })
```

**`override`** vs **`overrideAttrs`** vs **`overrideDerivation`**:
- `override`: change function arguments (the `callPackage` args)
- `overrideAttrs`: change the derivation attributes (inside mkDerivation)
- `overrideDerivation`: low-level, rarely needed

### 08 — Flakes

**Structure** (`concepts/flakes.md`):
```nix
{
  description = "My project";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in {
        devShells.default = pkgs.mkShell { packages = [ pkgs.git ]; };
        packages.default = ...;
      });
}
```

**Pure mode**: Flakes evaluate in pure mode — no `builtins.getEnv`, no
`builtins.currentTime`, no `<nixpkgs>`. `--impure` flag needed for impure operations.

**`follows`**: Make one input's sub-input follow another:
```nix
inputs.flake-utils.inputs.nixpkgs.follows = "nixpkgs";
```

**Flake outputs**: `packages`, `devShells`, `nixosConfigurations`,
`nixosModules`, `overlays`, `apps`, `checks`, `formatter`, `lib`.

**npins as non-flake alternative**: For projects that can't or won't use flakes,
npins provides source pinning without the flake machinery.

### 09 — NixOS

**Module system** (`module-system/deep-dive.md`):
```nix
{ config, lib, pkgs, ... }:
{
  options.services.foo.enable = lib.mkEnableOption "foo";
  config = lib.mkIf config.services.foo.enable {
    systemd.services.foo = { ... };
  };
}
```
Types: `str`, `int`, `bool`, `attrsOf`, `listOf`, `submodule`, `either`, `enum`.
Priority: `mkDefault` < default < `mkForce` < `mkOverride 10`.

**`configuration.nix`** (`nixos-configuration-on-vm.md`):
```nix
{ config, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  users.users.alice = { isNormalUser = true; extraGroups = [ "wheel" ]; };
  services.openssh.enable = true;
  system.stateVersion = "24.11";
}
# Build a VM: nix-build -A vm <nixpkgs/nixos> -A config.system.build.vm
```

**Integration tests** (`integration-testing-using-virtual-machines.md`):
```nix
testers.runNixOSTest {
  name = "my-test";
  nodes = {
    server = { ... };
    client = { ... };
  };
  testScript = ''
    start_all()
    server.wait_for_unit("my-service.service")
    client.succeed("curl http://server")
  '';
}
```

**Provisioning** (`provisioning-remote-machines.md`):
- `nixos-anywhere` for SSH-based provisioning of bare metal
- `disko` for declarative disk partitioning
- `nixos-rebuild switch` for applying config changes

**Binary cache** (`binary-cache-setup.md`):
```nix
services.nix-serve = {
  enable = true;
  listenAddress = "0.0.0.0";
  port = 5000;
  secretKeyFile = "/var/cache-priv-key.pem";
};
# Sign paths: nix-store --generate-binary-cache-key <name> pub priv
# Client config:
nix.settings.substituters = [ "https://cache.example.com" ];
nix.settings.trusted-public-keys = [ "cache.example.com:..." ];
```

**Distributed builds** (`distributed-builds-setup.md`):
```nix
nix.buildMachines = [{
  hostName = "builder";
  systems = [ "x86_64-linux" "aarch64-linux" ];
  maxJobs = 4;
  speedFactor = 2;
  supportedFeatures = [ "kvm" "nixos-test" "big-parallel" ];
}];
nix.distributedBuilds = true;
nix.settings.builders-use-substitutes = true;
```

**Docker images** (`building-and-running-docker-images.md`):
```nix
dockerTools.buildImage {
  name = "myapp";
  tag = "latest";
  config.Cmd = [ "${myapp}/bin/myapp" ];
  copyToRoot = [ pkgs.bash pkgs.coreutils ];
}
# nix-build then: docker load < result
```

**CI with Cachix** (`continuous-integration-github-actions.md`):
```yaml
- uses: cachix/install-nix-action@vXX
- uses: cachix/cachix-action@vXX
  with:
    name: mycache
    signingKey: '${{ secrets.CACHIX_SIGNING_KEY }}'
    authToken: '${{ secrets.CACHIX_AUTH_TOKEN }}'
```

**Post-build hook** (`post-build-hook.md`): Auto-upload built paths to a
binary cache (S3-compatible):
```nix
nix.settings.post-build-hook = "/run/current-system/bin/upload-to-cache";
# Script reads $OUT_PATHS and uploads to S3
```

**direnv** (`direnv.md`): `.envrc` with `use nix` for automatic shell activation.

**Binary cache client** (`add-binary-cache.md`):
```nix
nix.settings.substituters = [ "https://cache.example.com" ];
nix.settings.trusted-public-keys = [ "cache.example.com:..." ];
# With priority (lower = higher priority):
nix.settings.extra-substituters = [ "https://my-cache.example.com" ];
```


---

