# NixOS Appliance Images & OTA Updates

### 15.1 Minimal Appliance Images with systemd-repart

From applicative-systems/simple-systemd-repart-nixos-image:

```nix
{ modulesPath, pkgs, config, lib, ... }:
{
  imports = [
    (modulesPath + "/image/repart.nix")
    (modulesPath + "/profiles/image-based-appliance.nix")
  ];

  image.repart = {
    name = config.system.image.id;
    split = true;
    partitions = {
      esp = {
        contents = {
          "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
            "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
          "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
            "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
        };
        repartConfig = { Type = "esp"; Format = "vfat"; Label = "boot"; SizeMinBytes = "200M"; };
      };
      nix-store = {
        storePaths = [ config.system.build.toplevel ];
        nixStorePrefix = "/";
        repartConfig = {
          Type = "linux-generic"; Format = "squashfs"; ReadOnly = "yes";
          Label = "nix-store_${config.system.image.version}";
          SizeMinBytes = "2G"; SizeMaxBytes = "2G"; SplitName = "nix-store";
        };
      };
      root.repartConfig = {
        Type = "root"; Format = "ext4"; Label = "root";
        SizeMinBytes = "5G"; SizeMaxBytes = "5G"; SplitName = "-";
      };
    };
  };
}
```

**Key design decisions**:
- **squashfs** for nix-store: read-only, compressed, verity-protectable
- **split = true**: nix-store image is a separate file for A/B updates
- **UKI (Unified Kernel Image)**: kernel + initrd + cmdline in one EFI executable
- **systemd-boot**: No GRUB, simpler boot chain, supports Secure Boot

### 15.2 A/B OTA Updates with systemd-sysupdate

From applicative-systems/nixos-appliance-ota-update:

```nix
systemd.sysupdate = {
  enable = true;
  transfers = {
    "10-nix-store" = {
      Source = {
        Path = "http://cache.internal/";
        Type = "url-file";
        MatchPattern = [ "${config.system.image.id}_@v.nix-store.raw" ];
      };
      Target = {
        InstancesMax = 2;  # A/B slots
        Path = "auto";
        MatchPattern = "nix-store_@v";
        Type = "partition";
        MatchPartitionType = "linux-generic";
        ReadOnly = "yes";
      };
    };
    "20-boot-image" = {
      Source = {
        MatchPattern = [ "${config.boot.uki.name}_@v.efi" ];
      };
      Target = {
        InstancesMax = 2;
        Path = "/EFI/Linux";
        Type = "regular-file";
      };
    };
  };
};
```

**How A/B updates work**:
1. `systemd-sysupdate` downloads the new nix-store image and UKI
2. Writes them to the inactive slot (InstancesMax = 2)
3. On next boot, systemd-boot tries the new slot
4. Boot assessment marks the boot as good or bad
5. If bad, automatically reverts to the previous slot

### 15.3 The sysupdate-package (Distribution Artifact)

```nix
config.system.build.sysupdate-package = pkgs.runCommand "sysupdate-package-${version}" {} ''
  mkdir $out
  cp ${build.uki}/${ukiFile} $out/
  cp ${build.image}/${id}_${version}.nix-store.raw $out/
  cd $out; sha256sum * > SHA256SUMS
'';
```

### 15.4 Image Size Optimization (from nixcademy)

Techniques to minimize NixOS image size (from ~1.5GB to ~350MB):
- Use `nix-store --query --requisites` to analyze closure size
- Remove unnecessary packages from `environment.systemPackages`
- Use `lib.stripDebugInfo` to strip debug symbols
- Use `fonts.fontconfig.cache = 32;` to pre-generate font cache
- Disable unnecessary services (文档, man pages, etc.)
- Use `boot.initrd.systemd.strip = true;` to strip initrd
- Consider `nixpkgs.config.replaceStdenv` for smaller stdenv

### 15.5 Runtime Partition Growth with systemd-repart

```nix
boot.initrd.systemd.repart.enable = true;
boot.initrd.systemd.repart.device = "/dev/sda";
systemd.repart.partitions = {
  home = { Format = "ext4"; Label = "home"; Type = "home"; Weight = 2000; };
  var  = { Format = "ext4"; Label = "var";  Type = "var";  Weight = 1000; };
};
```

On first boot, systemd-repart in the initrd grows these partitions to fill
available disk space.


---

