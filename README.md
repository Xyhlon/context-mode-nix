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

## Install as an MCP Server

If you agree to the ELv2 license for the packaged upstream `context-mode`
subproject, you can use a location-independent launcher in MCP clients
instead of relying on a locally installed `context-mode` binary:

```bash
env NIXPKGS_ALLOW_UNFREE=1 nix run --impure github:Xyhlon/context-mode-nix --
```

Security note: `github:Xyhlon/context-mode-nix` is an unpinned flake reference.
It tracks this repository's moving default branch, so future `nix run` invocations
can pick up newer commits automatically. Only use this if you trust the
maintainer, or audit the repo yourself and pin it to a specific revision or
lock it through your own flake configuration.

### Codex

```bash
codex mcp add context-mode -- env NIXPKGS_ALLOW_UNFREE=1 nix run --impure github:Xyhlon/context-mode-nix --
```

Or add the server directly to `~/.codex/config.toml`:

```toml
[mcp_servers.context_mode]
command = "env"
args = [
  "NIXPKGS_ALLOW_UNFREE=1",
  "nix",
  "run",
  "--impure",
  "github:Xyhlon/context-mode-nix",
  "--",
]
```

### OpenCode

Add the server to `opencode.json` or `opencode.jsonc`:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "context-mode": {
      "type": "local",
      "command": [
        "env",
        "NIXPKGS_ALLOW_UNFREE=1",
        "nix",
        "run",
        "--impure",
        "github:Xyhlon/context-mode-nix",
        "--"
      ]
    }
  }
}
```

## Downstream Overlay Example

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    context-mode-nix.url = "github:Xyhlon/context-mode-nix";
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
