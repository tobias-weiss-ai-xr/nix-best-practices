# NixOS integration test example
# See docs/10-integration-testing.md for details.
#
# This tests that a MariaDB service starts and accepts connections.
# Run with: nix flake check .#integration
# Or interactively: nix build .#checks.x86_64-linux.integration.driverInteractive

{ pkgs, ... }:

{
  name = "mariadb-integration";

  nodes = {
    server = { config, ... }: {
      services.mysql = {
        enable = true;
        package = pkgs.mariadb;
        initialDatabases = [
          { name = "opendesk"; }
        ];
      };
      networking.firewall.allowedTCPPorts = [ 3306 ];
    };

    client = { ... }: {
      environment.systemPackages = [ pkgs.mariadb ];
    };
  };

  testScript = ''
    start_all()

    # Wait for MariaDB to be ready
    server.wait_for_unit("mysql.service")
    server.wait_for_open_port(3306)

    # Client must be able to connect
    client.systemctl("start network-online.target")
    client.wait_for_unit("network-online.target")

    # Test database connectivity
    client.succeed(
      "mysql -h server -P 3306 -u root -e 'SHOW DATABASES;' | grep opendesk"
    )

    # Test creating a table
    client.succeed(
      "mysql -h server -P 3306 -u root opendesk -e 'CREATE TABLE test (id INT);'"
    )
    client.succeed(
      "mysql -h server -P 3306 -u root opendesk -e 'INSERT INTO test VALUES (1);'"
    )
    result = client.succeed(
      "mysql -h server -P 3306 -u root opendesk -e 'SELECT * FROM test;'"
    )
    assert "1" in result, "Database write/read failed"
  '';

  # Interactive debugging (uncomment to use)
  # interactive.nodes.server = {
  #   virtualisation.forwardPorts = [{ from = "host"; host.port = 3306; guest.port = 3306; }];
  # };
}

# === Multi-VM networking test (from nixos-test-driver-nixcon) ===
#
# {
#   name = "multi-vm-ping";
#   nodes = {
#     machine1 = {};
#     machine2 = {};
#   };
#   globalTimeout = 300;
#   defaults = {
#     networking.dhcpcd.enable = false;
#   };
#   testScript = ''
#     start_all()
#     machine1.systemctl("start network-online.target")
#     machine2.systemctl("start network-online.target")
#     machine1.wait_for_unit("network-online.target")
#     machine2.wait_for_unit("network-online.target")
#     machine1.succeed("ping -c 1 machine2")
#     machine2.succeed("ping -c 1 machine1")
#   '';
# }
#
# === GPU/CUDA test (from nixos-gpu-tests) ===
#
# pkgs = import inputs.nixpkgs {
#   config = { allowUnfree = true; cudaSupport = true; };
# };
# cuda-test = pkgs.testers.runNixOSTest {
#   nodes.server = { ... };
#   # Add required system features
#   requiredSystemFeatures = [ "cuda" ];
# };
