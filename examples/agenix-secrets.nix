# agenix secrets management for NixOS
# See docs/06-secrets-management.md for details.
#
# agenix uses age encryption with SSH host keys. Secrets are encrypted in the
# repo and decrypted at activation time to /run/agenix/ (tmpfs).

{ config, pkgs, lib, ... }:

let
  # Define which hosts can decrypt which secrets
  # Public keys are the SSH host keys of each machine
  hostKeys = {
    scs-node-06 = "ssh-ed25519 AAAAC3Nz...";
    scs-node-07 = "ssh-ed25519 AAAAC3Nz...";
  };
in
{
  # Enable agenix
  age = {
    identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
    ];

    # Secrets are defined in secrets.nix (encrypted files in the repo)
    secrets = {
      # Database root password
      db-root-password = {
        file = ../secrets/db-root-password.age;
        owner = "mysql";
        group = "mysql";
        mode = "0400";
      };

      # Keycloak admin password
      keycloak-admin-password = {
        file = ../secrets/keycloak-admin-password.age;
        owner = "keycloak";
        group = "keycloak";
        mode = "0400";
      };

      # Attic cache signing key
      attic-signing-key = {
        file = ../secrets/attic-signing-key.age;
        owner = "atticd";
        group = "atticd";
        mode = "0400";
      };

      # TLS certificate key
      tls-key = {
        file = ../secrets/tls-key.age;
        owner = "nginx";
        group = "nginx";
        mode = "0400";
      };
    };
  };

  # Use secrets in services
  services = {
    mariadb = {
      enable = true;
      # Reference the decrypted secret
      initialRootPasswordFile = config.age.secrets.db-root-password.path;
    };

    keycloak = {
      enable = true;
      # The secret is at /run/agenix/keycloak-admin-password
      initialAdminPasswordFile = config.age.secrets.keycloak-admin-password.path;
    };
  };

  # Example: use a secret in a systemd service via LoadCredential=
  # (complement to agenix for runtime secrets)
  systemd.services.my-app = {
    serviceConfig = {
      LoadCredential = "api-key:${config.age.secrets.api-key.path}";
    };
    script = ''
      export API_KEY=$(cat "$CREDENTIALS_DIRECTORY/api-key")
      exec my-app --api-key "$API_KEY"
    '';
  };
}

# === Setting up agenix ===
#
# 1. Generate SSH host keys on each machine (or use existing):
#    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key
#
# 2. Create secrets.nix:
#    let
#      scs-node-06 = "ssh-ed25519 AAAAC3Nz...";
#      scs-node-07 = "ssh-ed25519 AAAAC3Nz...";
#      all = [ scs-node-06 scs-node-07 ];
#    in
#    {
#      "secrets/db-root-password.age".publicKeys = all;
#      "secrets/keycloak-admin-password.age".publicKeys = all;
#    }
#
# 3. Encrypt a secret:
#    echo "my-secret-password" | agenix -e secrets/db-root-password.age
#
# 4. Re-encrypt after adding a new host:
#    agenix -r
