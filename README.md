# context-mode-nix

Nix distribution for [`mksglu/context-mode`](https://github.com/mksglu/context-mode).

This repo packages upstream Context Mode `v1.0.103` as a standalone flake and
exports an overlay for downstream users.

## Outputs

- `packages.<system>.default`
- `packages.<system>.context-mode`
- `apps.<system>.default`
- `apps.<system>.context-mode`
- `overlays.default`
- `overlays.context-mode`

## Notes

- This packaging repo is licensed under MIT. See [LICENSE](LICENSE).
- The packaged upstream `context-mode` software remains licensed under ELv2.
  See [UPSTREAM-LICENSE](UPSTREAM-LICENSE).
- Downstream Nix consumers must allow unfree packages because the packaged
  software is ELv2.
- The packaged wrapper keeps its runtime PATH minimal by default:
  `runtimePackages = [ pkgs.python3 ]`.
- Override `runtimePackages` when you want bundled access to optional runtimes
  such as Bun, Go, or Rust.

## Build

```bash
NIXPKGS_ALLOW_UNFREE=1 nix build --impure .#context-mode
```

## Run

```bash
NIXPKGS_ALLOW_UNFREE=1 nix run --impure .#context-mode
```

## Downstream Overlay Example

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    context-mode-nix.url = "github:mksglu/context-mode-nix";
  };

  outputs = { nixpkgs, context-mode-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          context-mode-nix.overlays.default
          (final: prev: {
            context-mode = prev.context-mode.override {
              runtimePackages = [
                final.python3
                final.bun
                final.go
                final.rustc
              ];
            };
          })
        ];
      };
    in
    {
      packages.${system}.default = pkgs.context-mode;
    };
}
```
