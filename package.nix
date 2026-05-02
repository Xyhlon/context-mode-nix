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
  version = "1.0.103";

  src = fetchFromGitHub {
    owner = "mksglu";
    repo = "context-mode";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Yv0rQITaESPqcxCB73NNynFpQkkFB0qTx4aTvsE9/xE=";
  };

  # The upstream lockfile is `bun.lock`, so we pre-populate `node_modules`
  # with Bun in a fixed-output derivation instead of allowing runtime installs
  # from inside the Nix store.
  node_modules = stdenvNoCC.mkDerivation {
    pname = "${finalAttrs.pname}-node_modules";
    inherit (finalAttrs) version src;

    nativeBuildInputs = [
      bun
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
        --ignore-scripts \
        --no-progress
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -R node_modules $out/
      runHook postInstall
    '';

    dontFixup = true;
    outputHash = "sha256-R0iREbU/o4tf6OojvDzBkEVWQAXb5IwHFYX4g50CZ/8=";
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

