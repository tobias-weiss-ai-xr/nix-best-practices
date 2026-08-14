# Security Hardening

### 18.1 NixOS Security Defaults

NixOS is already quite secure by default:
- No services enabled unless explicitly configured
- Firewall (`networking.firewall`) is enabled by default
- Root login via SSH is disabled by default
- No setuid binaries unless explicitly configured
- `/nix/store` is read-only

### 18.2 Additional Hardening

```nix
{
  # Kernel hardening
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.tcp_max_syn_backlog" = 2048;
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.perf_event_paranoid" = 2;
    "kernel.unprivileged_bpf_disabled" = 1;
    "dev.tty.ldisc_autoload" = 0;
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
  };

  # AppArmor
  security.apparmor.enable = true;

  # Audit
  security.auditd.enable = true;

  # Fail2ban
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "1h";
  };

  # Only allow SSH key auth
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
      KbdInteractiveAuthentication = false;
    };
  };

  # Automatic security updates
  system.autoUpgrade = {
    enable = true;
    dates = "04:00";
    allowReboot = true;
  };
}
```

### 18.3 Secure Boot + Measured Boot (lanzaboote)

```nix
boot.loader.systemd-boot.enable = true;
boot.lanzaboote = {
  enable = true;
  pkiBundle = "/etc/secureboot";
};
# TPM-bound disk encryption
boot.initrd.luks.devices."crypted" = {
  device = "/dev/disk/by-partlabel/crypted";
  allowDiscards = true;
  crypttabExtraOpts = [ "tpm2-device=auto" ];
};
```

### 18.4 Secrets at Rest

With agenix or sops-nix, secrets are:
- Encrypted at rest in the git repository (age or GPG)
- Decrypted at NixOS activation time
- Stored in `/run/agenix/` or `/run/secrets/` (tmpfs, not persisted)
- Access-controlled by user/group/mode

### 18.5 Container Image Signing (Cosign)

opendesk-nix already has `cosign.nix`. Ensure all container images pushed to the
local registry are signed:
```nix
# After building a container image:
cosign sign --key cosign.key registry.internal/opendesk/mariadb:24.11
# Verify before deployment:
cosign verify --key cosign.pub registry.internal/opendesk/mariadb:24.11
```

### 18.6 SBOM Generation

opendesk-nix has `sbom.nix`. Generate SBOMs (CycloneDX/SPDX) for every
container image:
```nix
syftpackages = pkgs.syft;  # or nixpkgs#syft
# After building an image:
syft packages registry.internal/opendesk/mariadb:24.11 -o cyclonedx-json > mariadb-sbom.json
```


---

