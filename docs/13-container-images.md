# Container Image Building

### 9.1 dockerTools.buildImage (from nixpkgs manual)

```nix
dockerTools.buildImage {
  name = "myapp";
  tag = "latest";
  created = "now";  # or a specific timestamp for reproducibility
  copyToRoot = [ pkgs.bash pkgs.coreutils myapp ];
  config = {
    Cmd = [ "${myapp}/bin/myapp" ];
    Env = [ "PATH=/bin:/usr/bin" "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ];
    ExposedPorts = { "8080/tcp" = {}; };
    WorkingDir = "/app";
  };
}
# nix-build then: docker load < result
```

### 9.2 dockerTools.buildLayeredImage (Layered, Smaller Images)

```nix
dockerTools.buildLayeredImage {
  name = "myapp";
  tag = "latest";
  contents = [ pkgs.bash pkgs.coreutils myapp ];
  config = {
    Cmd = [ "${myapp}/bin/myapp" ];
  };
  created = "now";
  maxLayers = 100;  # max number of layers
}
```

Each package becomes a separate layer, improving caching and reducing image size.

### 9.3 dockerTools.streamLayeredImage (Streaming, No Intermediate File)

```nix
dockerTools.streamLayeredImage {
  name = "myapp";
  contents = [ myapp ];
} | docker load
```

Streams directly to `docker load` without building an intermediate tarball.

### 9.4 fakeNss for Images Needing /etc/passwd

```nix
dockerTools.buildImage {
  name = "myapp";
  copyToRoot = [
    pkgs.bash
    pkgs.coreutils
    myapp
    pkgs.dockerTools.fakeNss  # provides /etc/passwd and /etc/group
  ];
  config = { User = "myapp"; };
}
```

### 9.5 Building Images for a Local Registry (Air-Gapped)

```nix
# Build and push to local registry
dockerTools.buildImage {
  name = "registry.internal/opendesk/mariadb";
  tag = "24.11";
  copyToRoot = [ pkgs.mariadb pkgs.bash ];
  config = { Cmd = [ "${pkgs.mariadb}/bin/mysqld" ]; };
}
# nix-build then:
# docker load < result
# docker push registry.internal/opendesk/mariadb:24.11
```

**For opendesk-edu**: opendesk-nix already builds `mariadb-opendesk`,
`postgresql-opendesk`, `redis-opendesk` via dockerTools. The pattern should be
extended to all 57 services.

### 9.6 Nixery — Ad-Hoc Container Registry

**Nixery** builds Docker images on-demand from Nix packages:
```bash
docker pull nixery.dev/shell/bash/git/vim
```

For air-gapped SCS, a self-hosted Nixery could serve images from the local
nix store, building them on-demand.


---


---

## Additional: Docker Images for Local Registry (from Intel Report)

### 5.4 Docker Images with dockerTools

Building container images with Nix for the local registry:

```nix
dockerTools.buildImage {
  name = "registry.internal/opendesk/mariadb";
  tag = "latest";
  copyToRoot = [ pkgs.mariadb pkgs.bash pkgs.coreutils ];
  config = {
    Cmd = [ "${pkgs.mariadb}/bin/mysqld" ];
    Env = [ "MYSQL_ROOT_PASSWORD_FILE=/run/secrets/db-root-password" ];
    ExposedPorts = { "3306/tcp" = {}; };
  };
}
# nix-build then: docker load < result | docker push registry.internal/...
```

**opendesk-nix already does this**: The `platform/nix/build.nix` contains
container build patterns for `mariadb-opendesk`, `postgresql-opendesk`,
`redis-opendesk`.

