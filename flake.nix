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
