# Immutable & Ephemeral Systems

### 4.1 Impermanence — Ephemeral Root Storage

**impermanence** (nix-community) wipes the root filesystem on every reboot,
forcing all persistent state to be explicitly declared. This is the NixOS
equivalent of a "stateless" system.

**Setup with tmpfs root**:
```nix
fileSystems."/" = {
  device = "none";
  fsType = "tmpfs";
  options = [ "defaults" "size=25%" "mode=755" ];
};
fileSystems."/persistent" = {
  device = "/dev/root_vg/root";
  neededForBoot = true;
  fsType = "btrfs";
  options = [ "subvol=persistent" ];
};
```

**Declare persistent paths**:
```nix
imports = [ "${impermanence}/nixos.nix" ];

environment.persistence."/persistent" = {
  hideMounts = true;
  directories = [
    "/var/log"
    "/var/lib/nixos"
    "/var/lib/systemd/coredump"
    "/etc/NetworkManager/system-connections"
    { directory = "/var/lib/mariadb"; user = "mariadb"; group = "mariadb"; mode = "u=rwx,g=rx,o="; }
  ];
  files = [
    "/etc/machine-id"
  ];
};
```

**Benefits for SCS K3s**:
- Forces explicit declaration of all state (no hidden state)
- Clean slate on every reboot (testing-friendly)
- Combined with A/B OTA updates: if the new system fails, revert to the old one
- `/nix` and `/boot` are on persistent storage; everything else is ephemeral

### 4.2 BTRFS Rollback (Alternative to tmpfs)

Instead of tmpfs (which uses RAM), use BTRFS subvolumes and create a fresh root
on each boot:
```nix
boot.initrd.postDeviceCommands = ''
  mkdir -p /mnt
  mount -t btrfs /dev/disk/by-label/root /mnt
  btrfs subvolume delete /mnt/root
  btrfs subvolume snapshot /mnt/root-blank /mnt/root
  umount /mnt
'';
```

### 4.3 A/B OTA Updates with systemd-sysupdate

From the applicative-systems nixos-appliance-ota-update pattern:

```nix
systemd.sysupdate = {
  enable = true;
  transfers = {
    "10-nix-store" = {
      Source = { Path = "http://cache.internal/"; Type = "url-file";
                 MatchPattern = [ "${config.system.image.id}_@v.nix-store.raw" ]; };
      Target = { InstancesMax = 2; Path = "auto"; MatchPattern = "nix-store_@v";
                 Type = "partition"; MatchPartitionType = "linux-generic"; ReadOnly = "yes"; };
    };
  };
};
```

**Boot assessment** (auto-revert on failure):
```nix
boot.loader.systemd-boot.configurationLimit = 10;
# systemd-boot's boot assessment marks failed boots and reverts automatically
```


---

