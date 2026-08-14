# Cross-compilation with extendModules
# See docs/14-cross-compilation.md for details.
#
# extendModules derives architecture variants from a single base configuration
# without duplication. The same nixosConfigurations.image is used for all targets.

{ inputs, lib, ... }:

let
  systems = [ "x86_64-linux" "aarch64-linux" ];
  forEachSystem = lib.genAttrs systems;
in
{
  # Base NixOS configuration (shared across all architectures)
  nixosConfigurations.image = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      ./configuration.nix
      ./modules/appliance-image.nix
    ];
  };

  # Cross-compiled images for each architecture
  packages = forEachSystem (system:
    let
      linuxSystem = system;
    in
    {
      # x86_64 (native build on x86_64)
      image-x86_64 =
        (inputs.self.nixosConfigurations.image.extendModules {
          modules = [{
            nixpkgs.buildPlatform = lib.mkDefault linuxSystem;
            nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
          }];
        }).config.system.build.image;

      # aarch64 (cross-compiled from x86_64)
      image-aarch64 =
        (inputs.self.nixosConfigurations.image.extendModules {
          modules = [{
            nixpkgs.buildPlatform = lib.mkDefault "x86_64-linux";
            nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
          }];
        }).config.system.build.image;
    });

  # Package-level cross-compilation (for individual packages, not full images)
  legacyPackages = forEachSystem (system:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    {
      # Cross-compile a package for aarch64
      aarch64-hello = pkgs.pkgsCross.aarch64-multiplatform.hello;

      # Fully static linking
      static-hello = pkgs.pkgsStatic.hello;
    });
}

# === buildPlatform vs hostPlatform vs targetPlatform ===
#
# buildPlatform:  Where the compilation runs
# hostPlatform:   Where the compiled program runs
# targetPlatform: What the compiled program targets (e.g., a cross-compiler)
#
# nativeBuildInputs = [ pkg-config cmake ];  # run on build machine
# buildInputs = [ openssl ];                  # linked into output (host machine)
