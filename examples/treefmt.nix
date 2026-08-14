# treefmt configuration
# Run with: nix fmt
# See docs/15-code-quality.md for details.

{ pkgs, ... }:

{
  settings = {
    tree-root-file = "flake.nix";
    on-unmatched = "info";

    formatter = {
      # Nix formatting
      nixfmt = {
        command = pkgs.lib.getExe pkgs.nixfmt;
        includes = [ "*.nix" ];
      };

      # Nix linting with auto-fix
      statix = {
        command = pkgs.lib.getExe pkgs.statix;
        options = [ "fix" ];
        no-positional-arg-support = true;
        includes = [ "*.nix" ];
      };

      # Dead code removal
      deadnix = {
        command = pkgs.lib.getExe pkgs.deadnix;
        options = [ "--edit" ];
        includes = [ "*.nix" ];
      };

      # YAML/JSON formatting
      prettier = {
        command = pkgs.lib.getExe pkgs.prettier;
        options = [ "--write" ];
        includes = [ "*.yaml" "*.yml" "*.json" "*.md" ];
      };

      # Shell formatting
      shfmt = {
        command = pkgs.lib.getExe pkgs.shfmt;
        includes = [ "*.sh" "*.bash" ];
      };

      # Shell linting
      shellcheck = {
        command = pkgs.lib.getExe pkgs.shellcheck;
        includes = [ "*.sh" "*.bash" ];
        excludes = [ ".envrc" ];
      };
    };
  };
}
