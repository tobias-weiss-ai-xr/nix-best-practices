# Secrets Management

### 2.1 Three Approaches Compared

| Feature | **agenix** | **sops-nix** | **systemd LoadCredential=** |
|---|---|---|---|
| Encryption | age (SSH keys) | sops (GPG or age) | None (runtime only) |
| Storage | Encrypted `.age` files in Nix store | Encrypted sops files in Nix store | Files on host (e.g., /run/credentials) |
| Key type | SSH Ed25519/RSA | GPG or age (SSH Ed25519 via ssh-to-age) | Any file |
| Decryption | At NixOS activation | At NixOS activation | At systemd unit start |
| Version control | Encrypted files committed to git | Encrypted files committed to git, diffs visible in cleartext | N/A (runtime) |
| CI friendly | Yes (encrypted in store) | Yes (encrypted in store) | N/A |
| Rollback | Yes (in Nix store) | Yes (optional, in Nix store) | N/A |
| Atomic updates | Per-file | Atomic directory swap | Per-unit |
| Home-manager | Yes (age-home module) | Yes | N/A |
| Complexity | Low (very little code) | Medium (sops + keys) | Low (systemd native) |

### 2.2 agenix (Recommended for Simplicity)

```nix
# flake.nix
inputs.agenix.url = "github:ryantm/agenix";

# configuration.nix
imports = [ inputs.agenix.nixosModules.default ];

age.secrets = {
  "database-password" = {
    file = ./secrets/database-password.age;
    owner = "mariadb";
    group = "mariadb";
    mode = "0400";
  };
  "keycloak-admin" = {
    file = ./secrets/keycloak-admin.age;
    path = "/run/agenix/keycloak-admin";
  };
};
```

**CLI usage**:
```bash
# Generate a host key (or use existing SSH host key)
ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key

# Define secrets.nix (maps secrets to public keys)
# Then encrypt:
agenix -e secrets/database-password.age
```

### 2.3 sops-nix (Recommended for Teams)

```nix
# flake.nix
inputs.sops-nix.url = "github:Mic92/sops-nix";
inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs";

# configuration.nix
imports = [ inputs.sops-nix.nixosModules.sops ];

sops = {
  defaultSopsFile = ./secrets/secrets.yaml;
  age.keyFile = "/var/lib/sops-nix/key.txt";
  secrets = {
    "database-password" = {
      owner = "mariadb";
      mode = "0400";
    };
    "keycloak-admin" = {
      path = "/run/secrets/keycloak-admin";
    };
  };
};
```

**Advantages for teams**: sops encrypts once with a master key, multiple developers
can decrypt with their own keys. YAML/JSON/INI/binary formats. Git diffs can be
shown in cleartext. Cloud KMS (AWS, GCP, Azure, Vault) supported.

### 2.4 systemd LoadCredential= (for Runtime Secrets)

Used by the declarative-runtime pattern (applicative-systems). Secrets are
loaded at systemd unit start time, never in the Nix store:

```nix
systemd.services.my-service = {
  serviceConfig = {
    LoadCredential = [
      "db-password:/run/agenix/database-password"
      "api-key:/run/secrets/api-key"
    ];
  };
  script = ''
    export DB_PASSWORD=$(cat "$CREDENTIALS_DIRECTORY/db-password")
    export API_KEY=$(cat "$CREDENTIALS_DIRECTORY/api-key")
    exec my-service
  '';
};
```

### 2.5 Recommendation for opendesk-edu

Use **agenix** for NixOS-level secrets (database passwords, API keys, TLS certs)
combined with **systemd LoadCredential=** for passing secrets to service units.
For K8s secrets, use **Sealed Secrets** or **External Secrets Operator** (which
can read from HashiCorp Vault or any secret backend). The air-gapped SCS cluster
should run its own age key per node, with the private key on the node and public
keys in the flake repository.


---

