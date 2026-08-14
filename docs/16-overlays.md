# Overlays & Package Override Patterns

### 12.1 Overlays (from nixpkgs manual)

Overlays allow modifying the nixpkgs package set without forking it:

```nix
# flake.nix
overlays.default = final: prev: {
  mypackage = final.callPackage ./mypackage.nix { };
  # Override an existing package
  hello = prev.hello.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./fix.patch ];
  });
  # Python package override
  python3 = prev.python3.override {
    packageOverrides = pyfinal: pyprev: {
      requests = pyprev.requests.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./requests-fix.patch ];
      });
    };
  };
};
```

### 12.2 Override Patterns

| Pattern | Use Case |
|---|---|
| `override` | Change function arguments (callPackage args) |
| `overrideAttrs` | Change derivation attributes (inside mkDerivation) |
| `overrideDerivation` | Low-level, rarely needed |
| `extendPackages` | Create a custom package set with overrides |
| `callPackageWith` | Create a scoped package set with custom arguments |

### 12.3 Composing Overlays

```nix
pkgs = import nixpkgs {
  inherit system;
  overlays = [
    (import ./overlay.nix)           # local overlay
    inputs.some-flake.overlays.default  # flake overlay
    (final: prev: { custom = final.callPackage ./custom.nix { }; })
  ];
  config = { allowUnfree = true; };
};
```

### 12.4 Interdependent Package Sets (from nixpkgs manual)

```nix
# Create a scope with interdependent packages
myScope = pkgs.lib.makeScope pkgs.newScope (self: {
  library1 = self.callPackage ./library1.nix { };
  library2 = self.callPackage ./library2.nix { inherit (self) library1; };
  app = self.callPackage ./app.nix { inherit (self) library1 library2; };
});
```


---

