# Declarative runtime state reconciliation via OpenTofu
# See docs/20-runtime-state.md for details.
#
# This pattern uses OpenTofu (MPL 2.0, NOT Terraform BSL) to manage service
# runtime state (Keycloak realms, Grafana dashboards) that NixOS modules cannot.
#
# Key decisions:
#   - OpenTofu (MPL 2.0), not Terraform (BSL 1.1)
#   - .tf.json generated via builtins.toJSON (no HCL, no terranix)
#   - systemd LoadCredential= for secrets (never in Nix store)
#   - Run-once Type=oneshot with restartTriggers (no drift timer)
#   - Local tfstate (no remote backends)
#   - Vendored providers via pkgs.opentofu.withPlugins (air-gap friendly)

{ config, pkgs, lib, ... }:

let
  # Generate .tf.json from Nix options
  tfJsonFile = name: config:
    pkgs.writeText "${name}.tf.json" (builtins.toJSON config);

  # Create a systemd oneshot service that applies OpenTofu config
  mkReconcileService =
    { name
    , tfConfig
    , afterUnits
    , healthUrl
    , tokenFile
    , executor ? pkgs.opentofu
    , tokenVar ? "TF_TOKEN"
    , user ? "root"
    , group ? "root"
    , stateDir ? "/var/lib/${name}"
    , credentials ? { }
    }:
    let
      confFile = tfJsonFile name tfConfig;
      allCredentials = { ${tokenVar} = tokenFile; } // credentials;
      workDir = "${stateDir}/declarative-terraform";
    in
    {
      description = "Declarative reconciliation for ${name} (OpenTofu)";
      after = afterUnits;
      requires = afterUnits;
      wantedBy = [ "multi-user.target" ];

      # Re-apply when config changes
      restartTriggers = [ confFile ];

      path = [ executor pkgs.curl pkgs.coreutils ];

      environment = {
        TF_IN_AUTOMATION = "1";
        TF_INPUT = "0";
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = user;
        Group = group;
        # Secrets loaded via systemd, never in Nix store
        LoadCredential = lib.mapAttrsToList
          (id: path: "${id}:${path}")
          allCredentials;
      };

      script = ''
        set -euo pipefail
        umask 077

        mkdir -p ${workDir}
        cd ${workDir}

        # Install the .tf.json config
        install -m 0600 ${confFile} ./main.tf.json

        # Wait for the service to be healthy
        for _ in $(seq 1 60); do
          curl -fsS -o /dev/null "${healthUrl}" && break
          sleep 2
        done

        # Load secrets from systemd credentials
        for id in ${lib.escapeShellArgs (lib.attrNames allCredentials)}; do
          export "TF_VAR_$id=$(cat "$CREDENTIALS_DIRECTORY/$id")"
        done

        # Apply the configuration
        ${lib.getExe executor} init -no-color
        ${lib.getExe executor} apply -auto-approve -input=false -no-color
      '';
    };
in
{
  # === Keycloak runtime state ===
  services.keycloak = {
    enable = true;
    database = {
      type = "postgresql";
      host = "/run/postgresql";
      username = "keycloak";
      passwordFile = config.age.secrets.keycloak-db-password.path;
    };
    initialAdminPasswordFile = config.age.secrets.keycloak-admin-password.path;

    # Declarative runtime state (realms, clients, scopes)
    runtime = {
      enable = true;

      realms.staff = {
        display_name = "Staff SSO";
        enabled = true;
      };

      openid_clients.app = {
        realm = "staff";
        client_id = "opendesk-app";
        client_secretFile = config.age.secrets.keycloak-client-secret.path;
        valid_redirect_uris = [ "https://app.opendesk.internal/*" ];
        web_origins = [ "https://app.opendesk.internal" ];
      };
    };
  };

  # Wire up the reconciliation service
  systemd.services.keycloak-runtime =
    mkReconcileService {
      name = "keycloak";
      tfConfig = config.services.keycloak.runtime.tfConfig;
      afterUnits = [ "keycloak.service" ];
      healthUrl = "http://localhost:9000/health/ready";
      tokenFile = config.age.secrets.keycloak-admin-token.path;
      user = "keycloak";
      group = "keycloak";
      stateDir = "/var/lib/keycloak";
    };

  # === Grafana runtime state (example) ===
  services.grafana = {
    enable = true;
    settings.server.http_addr = "0.0.0.0";
    settings.server.http_port = 3000;

    runtime = {
      enable = true;
      datasources.prometheus = {
        type = "prometheus";
        url = "http://prometheus.internal:9090";
        isDefault = true;
      };
    };
  };

  systemd.services.grafana-runtime =
    mkReconcileService {
      name = "grafana";
      tfConfig = config.services.grafana.runtime.tfConfig;
      afterUnits = [ "grafana.service" ];
      healthUrl = "http://localhost:3000/api/health";
      tokenFile = config.age.secrets.grafana-api-key.path;
      user = "grafana";
      group = "grafana";
      stateDir = "/var/lib/grafana";
    };
}

# === Vendoring OpenTofu providers (air-gap friendly) ===
#
# providers are vendored via Nix, so no registry access at activation time:
#
# { pkgs, ... }:
# let
#   keycloakProvider = pkgs.terraform-providers.mkProvider {
#     owner = "keycloak";
#     repo = "keycloak";
#     version = "5.1.0";
#     src = pkgs.fetchurl { ... };
#   };
# in {
#   environment.systemPackages = [
#     (pkgs.opentofu.withPlugins (_: [ keycloakProvider ]))
#   ];
# }
