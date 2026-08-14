# Container image building with dockerTools
# See docs/13-container-images.md for details.
#
# dockerTools.buildLayeredImage creates layered images (each package = separate
# layer) for better caching. Stream directly to docker load without intermediate
# tarball.

{ pkgs, lib, ... }:

let
  # Example: MariaDB container for opendesk-edu
  mariadbImage = pkgs.dockerTools.buildLayeredImage {
    name = "registry.internal/opendesk/mariadb";
    tag = "24.11";

    # Each package becomes a separate layer (better caching)
    contents = [
      pkgs.mariadb
      pkgs.bash
      pkgs.coreutils
      pkgs.dockerTools.fakeNss  # /etc/passwd and /etc/group
    ];

    # Created timestamp for reproducibility
    created = "now";

    # Maximum layers (default 100)
    maxLayers = 100;

    config = {
      Cmd = [ "${pkgs.mariadb}/bin/mysqld" ];
      Env = [
        "MYSQL_ROOT_PASSWORD_FILE=/run/secrets/db-root-password"
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "PATH=/bin:/usr/bin:/sbin:/usr/sbin"
      ];
      ExposedPorts = {
        "3306/tcp" = { };
      };
      WorkingDir = "/var/lib/mysql";
      User = "mysql";
    };
  };

  # Example: PostgreSQL container
  postgresqlImage = pkgs.dockerTools.buildLayeredImage {
    name = "registry.internal/opendesk/postgresql";
    tag = "24.11";
    contents = [ pkgs.postgresql_15 pkgs.bash pkgs.coreutils pkgs.dockerTools.fakeNss ];
    config = {
      Cmd = [ "${pkgs.postgresql_15}/bin/postgres" ];
      Env = [
        "PGDATA=/var/lib/postgresql/data"
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      ];
      ExposedPorts = { "5432/tcp" = { }; };
      User = "postgres";
    };
  };

  # Example: Redis container
  redisImage = pkgs.dockerTools.buildLayeredImage {
    name = "registry.internal/opendesk/redis";
    tag = "24.11";
    contents = [ pkgs.redis pkgs.bash ];
    config = {
      Cmd = [ "${pkgs.redis}/bin/redis-server" ];
      ExposedPorts = { "6379/tcp" = { }; };
    };
  };

  # Example: Streaming image (no intermediate tarball)
  # dockerTools.streamLayeredImage streams directly to docker load
  appImage = pkgs.dockerTools.streamLayeredImage {
    name = "registry.internal/opendesk/app";
    tag = "latest";
    contents = [ pkgs.nodejs_20 pkgs.bash ];
    config = {
      Cmd = [ "node" "server.js" ];
      Env = [ "NODE_ENV=production" ];
      ExposedPorts = { "3000/tcp" = { }; };
    };
  };
in
{
  # Build and push to local registry:
  # nix build .#mariadbImage
  # docker load < result
  # docker push registry.internal/opendesk/mariadb:24.11

  # Sign with Cosign:
  # cosign sign --key cosign.key registry.internal/opendesk/mariadb:24.11

  # Generate SBOM:
  # syft packages registry.internal/opendesk/mariadb:24.11 -o cyclonedx-json > mariadb-sbom.json

  inherit mariadbImage postgresqlImage redisImage appImage;
}

# === buildImage (non-layered, simpler) ===
#
# pkgs.dockerTools.buildImage {
#   name = "myapp";
#   tag = "latest";
#   created = "now";
#   copyToRoot = [ pkgs.bash pkgs.coreutils myapp ];
#   config = {
#     Cmd = [ "${myapp}/bin/myapp" ];
#     Env = [ "PATH=/bin:/usr/bin" ];
#     ExposedPorts = { "8080/tcp" = { }; };
#     WorkingDir = "/app";
#   };
# }
# nix-build then: docker load < result
