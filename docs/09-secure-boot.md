# Secure Boot & Measured Boot

### 5.1 lanzaboote — UEFI Secure Boot for NixOS

**lanzaboote** signs bootloaders, kernels, and initrds for UEFI Secure Boot,
creating a chain of trust from firmware to OS. It also supports Measured Boot
with TPM to bind disk encryption to boot state.

**Setup**:
```nix
inputs.lanzaboote.url = "github:nix-community/lanzaboote";

# configuration.nix
boot.loader.systemd-boot.enable = true;
boot.lanzaboote = {
  enable = true;
  pkiBundle = "/etc/secureboot";
};
```

**Key generation**:
```bash
# Generate Secure Boot keys
sbctl create-keys
# Enroll keys in firmware
sbctl enroll-keys -m
```

**How it works**:
1. `lzbt` (Lanzaboote tool) takes a NixOS bootspec, signs the kernel + initrd
2. Creates a Unified Kernel Image (UKI) with the stub
3. Installs the UKI to the EFI System Partition (ESP)
4. Multiple NixOS generations are all signed and bootable
5. The Lanzaboote stub stores kernel/initrd separately on the ESP (saves space
   vs systemd-stub which embeds them in the UKI)

**Measured Boot** (TPM-bound encryption):
- TPM records measurements of all boot components
- LUKS volume key is sealed to expected TPM measurements
- If boot chain is tampered with, the key cannot be unsealed
- Combine with a PIN for attended systems, or a recovery key for unattended

### 5.2 Full Trusted Boot Chain for SCS Nodes

```
Firmware (Secure Boot) → systemd-boot (signed) → UKI (signed) → Linux kernel (signed) → initrd (hash embedded in UKI) → LUKS (TPM-bound) → root filesystem
```

For air-gapped SCS nodes, this provides:
- **Tamper detection**: Any modification to the boot chain is detected
- **Remote attestation**: TPM measurements can be verified remotely
- **Auto-revert**: Combined with A/B OTA, a failed boot reverts to the previous slot


---

