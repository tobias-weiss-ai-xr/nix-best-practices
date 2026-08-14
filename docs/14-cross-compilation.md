# Cross-Compilation & Multi-Architecture

### 10.1 extendModules Pattern (from applicative-systems)

The idiomatic way to cross-compile NixOS images:
```nix
nixosConfigurations.image = nixpkgs.lib.nixosSystem {
  modules = [ ./configuration.nix ];
};

packages.x86_64-linux.image-x86_64 =
  (nixosConfigurations.image.extendModules {
    modules = [{
      nixpkgs.buildPlatform = "x86_64-linux";
      nixpkgs.hostPlatform = "x86_64-linux";
    }];
  }).config.system.build.image;

packages.aarch64-linux.image-aarch64 =
  (nixosConfigurations.image.extendModules {
    modules = [{
      nixpkgs.buildPlatform = "x86_64-linux";  # build on x86
      nixpkgs.hostPlatform = "aarch64-linux";   # run on arm
    }];
  }).config.system.build.image;
```

### 10.2 pkgsCross for Package-Level Cross-Compilation

```nix
pkgsCross.aarch64-multiplatform.hello    # cross-compile for aarch64
pkgsCross.raspberryPi.hello              # for Raspberry Pi
pkgsStatic.hello                          # fully static linking
```

### 10.3 buildPlatform vs hostPlatform vs targetPlatform

- **buildPlatform**: Where the compilation runs
- **hostPlatform**: Where the compiled program runs
- **targetPlatform**: What the compiled program targets (e.g., a cross-compiler)

```nix
nativeBuildInputs = [ pkg-config cmake ];  # run on build machine
buildInputs = [ openssl ];                  # linked into output (host machine)
```

### 10.4 Multi-System Flake Pattern

```nix
systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
forEachSystem = lib.genAttrs systems;
packages = forEachSystem (system:
  let pkgs = nixpkgs.legacyPackages.${system}; in {
    default = pkgs.myapp;
  });
```


---

