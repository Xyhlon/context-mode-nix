{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bun,
  nodejs,
  makeBinaryWrapper,
  python3,
  cacert,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  runtimePackages ? [ python3 ],
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "context-mode";
  version = "1.0.111";

  src = fetchFromGitHub {
    owner = "mksglu";
    repo = "context-mode";
    tag = "v${finalAttrs.version}";
    hash = "sha256-mj6SY5o1Kcie2NRullBAxKKWU10b0TVZ/Y19DfOrUrs=";
  };

  # The upstream lockfile is `bun.lock`, so we pre-populate `node_modules`
  # with Bun in a fixed-output derivation instead of allowing runtime installs
  # from inside the Nix store.
  node_modules = stdenvNoCC.mkDerivation {
    pname = "${finalAttrs.pname}-node_modules";
    inherit (finalAttrs) version src;

    nativeBuildInputs = [
      bun
      nodejs
      cacert
      writableTmpDirAsHomeHook
    ];

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild
      export BUN_INSTALL_CACHE_DIR=$(mktemp -d)
      bun install \
        --frozen-lockfile \
        --omit dev \
        --ignore-scripts \
        --no-progress

      # Bun still materializes dev-only packages for this lockfile, so trim
      # the installed tree down to packages reachable from runtime deps only.
      node <<'EOF'
      const fs = require("node:fs");
      const path = require("node:path");

      const rootDir = process.cwd();
      const nodeModulesDir = path.join(rootDir, "node_modules");
      const rootPkg = JSON.parse(fs.readFileSync(path.join(rootDir, "package.json"), "utf8"));
      const keep = new Set();
      const queue = [];

      function resolvePackage(name, fromDir) {
        let currentDir = fromDir;
        const parts = name.split("/");

        while (true) {
          const candidate = path.join(currentDir, "node_modules", ...parts);
          if (fs.existsSync(candidate)) {
            return fs.realpathSync(candidate);
          }

          const parentDir = path.dirname(currentDir);
          if (parentDir === currentDir) {
            return null;
          }
          currentDir = parentDir;
        }
      }

      function enqueueRuntimeDeps(pkg, fromDir) {
        const deps = {
          ...(pkg.dependencies ?? {}),
          ...(pkg.optionalDependencies ?? {}),
          ...(pkg.peerDependencies ?? {}),
        };

        for (const depName of Object.keys(deps)) {
          const resolved = resolvePackage(depName, fromDir);
          if (resolved !== null) {
            queue.push(resolved);
          }
        }
      }

      enqueueRuntimeDeps(rootPkg, rootDir);

      while (queue.length > 0) {
        const pkgDir = queue.pop();
        if (keep.has(pkgDir)) {
          continue;
        }

        keep.add(pkgDir);

        const pkgJsonPath = path.join(pkgDir, "package.json");
        if (!fs.existsSync(pkgJsonPath)) {
          continue;
        }

        const pkg = JSON.parse(fs.readFileSync(pkgJsonPath, "utf8"));
        enqueueRuntimeDeps(pkg, pkgDir);
      }

      fs.rmSync(path.join(nodeModulesDir, ".bin"), { force: true, recursive: true });

      for (const entry of fs.readdirSync(nodeModulesDir, { withFileTypes: true })) {
        if (entry.name.startsWith("@")) {
          const scopeDir = path.join(nodeModulesDir, entry.name);
          for (const scopedEntry of fs.readdirSync(scopeDir, { withFileTypes: true })) {
            const scopedPath = path.join(scopeDir, scopedEntry.name);
            const resolved = fs.realpathSync(scopedPath);
            if (!keep.has(resolved)) {
              fs.rmSync(scopedPath, { force: true, recursive: true });
            }
          }

          if (fs.readdirSync(scopeDir).length == 0) {
            fs.rmdirSync(scopeDir);
          }
          continue;
        }

        const entryPath = path.join(nodeModulesDir, entry.name);
        const resolved = fs.realpathSync(entryPath);
        if (!keep.has(resolved)) {
          fs.rmSync(entryPath, { force: true, recursive: true });
        }
      }
      EOF
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -R node_modules $out/
      runHook postInstall
    '';

    dontFixup = true;
    outputHash = "sha256-cA757aKHj2LLdyd4c/kEA1ts5SpBUv+1aeZ6lW6x7+A=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [
    makeBinaryWrapper
    nodejs
  ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    libDir="$out/lib/${finalAttrs.pname}"
    install -d "$libDir" "$out/bin"

    cp package.json README.md LICENSE                "$libDir/"
    cp start.mjs cli.bundle.mjs server.bundle.mjs    "$libDir/"
    cp .mcp.json openclaw.plugin.json                "$libDir/" 2>/dev/null || true

    cp -r hooks configs                              "$libDir/"
    [ -d skills ]              && cp -r skills            "$libDir/"
    [ -d .claude-plugin ]      && cp -r .claude-plugin    "$libDir/"
    [ -d .openclaw-plugin ]    && cp -r .openclaw-plugin  "$libDir/"
    [ -d scripts ]             && cp -r scripts           "$libDir/"

    if [ -d insight ]; then
      install -d "$libDir/insight"
      for f in server.mjs package.json tsconfig.json vite.config.ts \
               tailwind.config.ts postcss.config.js index.html; do
        [ -f "insight/$f" ] && cp "insight/$f" "$libDir/insight/"
      done
      [ -d insight/src ] && cp -r insight/src "$libDir/insight/"
    fi

    cp -R ${finalAttrs.node_modules}/node_modules "$libDir/"

    chmod +x "$libDir/cli.bundle.mjs" "$libDir/server.bundle.mjs" "$libDir/start.mjs"

    makeBinaryWrapper ${lib.getExe nodejs} "$out/bin/context-mode" \
      --add-flags "$libDir/cli.bundle.mjs" \
      --prefix PATH : ${lib.makeBinPath ([ nodejs ] ++ runtimePackages)}

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckProgramArg = "--version";

  passthru = {
    inherit runtimePackages;
  };

  meta = {
    description = "MCP server that virtualises the agent's context window via sandboxed tool execution and a session-scoped FTS5 knowledge base";
    homepage = "https://github.com/mksglu/context-mode";
    license = lib.licenses.elastic20;
    mainProgram = "context-mode";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.unix;
  };
})
