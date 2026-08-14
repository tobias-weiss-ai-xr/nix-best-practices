# Runtime State Reconciliation

### 16.1 The Problem

NixOS modules configure a service's **static** surface (package version, config
file, systemd unit). They do NOT manage **runtime** state: Grafana
dashboards/datasources, Keycloak realms/clients, Forgejo orgs/repos. The
declarative-runtime pattern (applicative-systems) solves this.

### 16.2 The declarative-runtime Pattern

**Architecture**: Generate `.tf.json` from Nix options → apply via OpenTofu →
run-once systemd oneshot after the primary service starts.

```nix
services.keycloak = {
  enable = true;
  runtime = {
    enable = true;
    realms.staff.display_name = "Staff SSO";
    openid_clients.app = {
      realm = "staff";
      client_id = "app";
      client_secretFile = "/run/agenix/keycloak-client-secret";
      valid_redirect_uris = [ "https://app.example.com/*" ];
    };
  };
};
```

**Key design decisions** (from CLAUDE.md):
- **OpenTofu** (MPL 2.0) not Terraform (BSL 1.1)
- **`.tf.json`** generated directly via `builtins.toJSON` (no HCL, no terranix)
- **systemd `LoadCredential=`** for secrets (never in Nix store)
- **Run-once** reconciliation (not drift timer) with `restartTriggers`
- **Local state** (tfstate under service's state dir, no remote backends)
- **Vendored providers** via `pkgs.opentofu.withPlugins` (air-gap friendly)

### 16.3 The mkReconcileService Function

```nix
mkReconcileService = { name, tfConfig, afterUnits, healthUrl, tokenFile,
  executor, tokenVar, user, group, stateDir, credentials ? {} }:
  let
    confFile = tfJsonFile name tfConfig;
    allCredentials = { ${tokenVar} = tokenFile; } // credentials;
    workDir = "${stateDir}/declarative-terraform";
  in {
    description = "Declarative reconciliation for ${name} (OpenTofu)";
    after = afterUnits;
    requires = afterUnits;
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ confFile ];  # re-apply on config change
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = user;
      Group = group;
      LoadCredential = lib.mapAttrsToList (id: path: "${id}:${path}") allCredentials;
    };
    script = ''
      set -euo pipefail; umask 077
      mkdir -p ${workDir}; cd ${workDir}
      install -m 0600 ${confFile} ./main.tf.json
      for _ in $(seq 1 60); do
        curl -fsS -o /dev/null "${healthUrl}" && break; sleep 2
      done
      for id in ${lib.escapeShellArgs (lib.attrNames allCredentials)}; do
        export "TF_VAR_$id=$(cat "$CREDENTIALS_DIRECTORY/$id")"
      done
      tofu init -no-color; tofu apply -auto-approve -input=false -no-color
    '';
  };
```

### 16.4 When to Use This Pattern

Use declarative-runtime when:
- The service has admin-declarative runtime state (dashboards, realms, orgs)
- A Terraform/OpenTofu provider exists for the service
- The NixOS module cannot already express the runtime state

Do NOT use when:
- The service is entirely config-file-driven (already declarative via NixOS options)
- No Terraform/OpenTofu provider exists
- The runtime state is ephemeral (recreated on each restart anyway)

### 16.5 Applicable Services for opendesk-edu

| Service | Provider | Resource Types | Priority |
|---|---|---|---|
| Keycloak | keycloak/keycloak | ~95 (realms, clients, scopes, users, roles, groups) | High |
| Grafana | grafana/grafana | Dashboards, datasources, users, orgs | Medium |
| Forgejo/Gitea | svalabs/forgejo | Orgs, repos, teams, webhooks, branch protection | Low (if adopted) |


---

