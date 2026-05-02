{
  description = "Nix distribution for Context Mode";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    let
      mkContextMode = pkgs: pkgs.callPackage ./package.nix { };
      overlay = final: prev: {
        context-mode = mkContextMode final;
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      flake = {
        overlays.default = overlay;
        overlays.context-mode = overlay;
      };

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      perSystem =
        { pkgs, system, ... }:
        let
          context-mode = mkContextMode pkgs;
        in
        {
          packages.default = context-mode;
          packages.context-mode = context-mode;

          checks.runtime-node-modules = pkgs.runCommand "context-mode-runtime-node-modules" { } ''
            root="${context-mode}/lib/context-mode/node_modules"

            for path in \
              "$root/@modelcontextprotocol/sdk" \
              "$root/better-sqlite3" \
              "$root/turndown" \
              "$root/turndown-plugin-gfm" \
              "$root/@mixmark-io/domino"
            do
              if [ ! -e "$path" ]; then
                echo "missing runtime dependency: $path" >&2
                exit 1
              fi
            done

            for path in \
              "$root/esbuild" \
              "$root/lightningcss" \
              "$root/@esbuild" \
              "$root/@rolldown"
            do
              if [ -e "$path" ]; then
                echo "unexpected dev dependency: $path" >&2
                exit 1
              fi
            done

            mkdir -p "$out"
          '';

          apps = {
            default = {
              type = "app";
              program = "${self.packages.${system}.default}/bin/context-mode";
              meta.description = "Context Mode MCP server";
            };
            context-mode = {
              type = "app";
              program = "${self.packages.${system}.default}/bin/context-mode";
              meta.description = "Context Mode MCP server";
            };
          };

          formatter = pkgs.nixfmt-tree;

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              nil
              nixfmt-tree
              statix
            ];
          };
        };
    };
}
