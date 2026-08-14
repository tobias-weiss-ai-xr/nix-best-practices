# NixOS Integration Testing (VMs & Containers)

### 6.1 Two Backends: QEMU VMs vs systemd-nspawn Containers

The NixOS integration test driver now supports two backends:

| Feature | QEMU VMs (classic) | systemd-nspawn containers (new) |
|---|---|---|
| Isolation | Full hardware virtualization | Container isolation (shared kernel) |
| Speed | Slower (full VM boot) | ~25% faster |
| Memory | Higher (full guest) | Lower |
| KVM required | Yes (or emulation) | No |
| GPU passthrough | Via PCI (exclusive) | Via bind-mount (shared) |
| Nested virt | Required for macOS | Not needed |
| Best for | Security isolation, cross-arch | CI, GPU tests, fast iteration |

**Enable container tests** (from nixcademy + nixos-gpu-tests):
```nix
nix.settings.auto-allocate-uids = true;
nix.settings.experimental-features = [ "auto-allocate-uids" "cgroups" ];
nix.settings.extra-system-features = [ "uid-range" ];
# For container <-> VM networking:
nix.settings.extra-sandbox-paths = [ "/dev/net" ];
```

### 6.2 testers.runNixOSTest (from nixpkgs manual)

```nix
testers.runNixOSTest {
  name = "my-test";
  nodes = {
    server = { pkgs, ... }: {
      environment.systemPackages = [ pkgs.hello ];
      services.foo.enable = true;
    };
    client = { ... }: { ... };
  };
  testScript = ''
    start_all()
    server.wait_for_unit("foo.service")
    client.succeed("hello")
  '';
}
```

**Key attributes**:
- `nodes`: The evaluated NixOS configurations (useful for debugging)
- `driverInteractive`: A script that launches an interactive Python session
  for debugging the testScript

### 6.3 Multi-VM Test Patterns (from nixos-test-driver-nixcon)

**Networking**: Must explicitly start `network-online.target`:
```python
machine1.systemctl("start network-online.target")
machine1.wait_for_unit("network-online.target")
```

**Interactive debugging with port forwarding**:
```nix
interactive.nodes.server = {
  virtualisation.forwardPorts = [{
    from = "host";
    host.port = 8000;
    guest.port = 80;
  }];
};
```

**Custom service testing** (echo server example):
```nix
{
  name = "Echo Service Test";
  nodes.server = { config, ... }: {
    imports = [ ./echo-nixos-module.nix ];
    services.echo.enable = true;
    networking.firewall.allowedTCPPorts = [ config.services.echo.port ];
  };
  nodes.client = {};
  testScript = { nodes, ... }: ''
    ECHO_PORT = ${builtins.toString nodes.server.services.echo.port}
    start_all()
    server.wait_for_unit("echo.service")
    server.wait_for_open_port(ECHO_PORT)
    client.succeed("echo 'Hello' | nc -N server ${toString nodes.server.services.echo.port}")
  '';
}
```

### 6.4 GPU/CUDA in Integration Tests (from nixos-gpu-tests)

```nix
pkgs = import inputs.nixpkgs {
  inherit system;
  config = { allowUnfree = true; cudaSupport = true; cudaForwardCompat = false; cudaCapabilities = [ "6.1" ]; };
  overlays = [ (import ./overlay.nix) ];  # patches test driver
};

addRequiredFeatures = reqs: drv:
  drv.overrideTestDerivation (old: { requiredSystemFeatures = old.requiredSystemFeatures ++ reqs; });

cuda-container-test-nvidia = addRequiredFeatures [ "cuda" ] (
  pkgs.testers.runNixOSTest ./cuda-in-container-nvidia.nix
);
```

**Host requirements**: `programs.nix-required-mounts.presets.nvidia-gpu.enable = true;`

### 6.5 Running NixOS Tests on macOS (from nixcademy)

With vzvm or the standard linux-builder:
```nix
nix.linux-builder = {
  enable = true;
  systems = [ "aarch64-linux" "x86_64-linux" ];
};
nix.settings.system-features = [ "nixos-test" "apple-virt" ];
```

### 6.6 Eval-Only Checks (Fast CI Gates)

From declarative-runtime — evaluate the configuration without building a VM:
```nix
checks = lib.mapAttrs' (name: cfg:
  lib.nameValuePair "example-${name}"
    (exampleSystem system cfg).config.system.build.toplevel
) examples;
```

This catches option-name drift and evaluation errors in CI without paying for a
full VM build.


---


---

## Additional: Integration Tests as CI Gates (from Intel Report)

### 5.5 Integration Tests as CI Gates

The applicative-systems pattern for testing NixOS modules:

```nix
checks = lib.mapAttrs (system: pkgs:
  import ./tests/checks.nix { inherit pkgs self; }
) inputs.nixpkgs.legacyPackages;
```

For opendesk-edu, integration tests could verify that K8s manifest generation
produces valid YAML, that services can communicate, and that secrets are
handled correctly — all before deploying to SCS.

