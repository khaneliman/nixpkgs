{
  lib,
  stdenv,
  overrideSDK,
  fetchFromGitHub,
  fetchzip,
  installShellFiles,
  testers,
  writeShellScript,
  common-updater-scripts,
  curl,
  darwin,
  jq,
  xcodebuild,
  xxd,
  yabai,
}:
let
  inherit (darwin.apple_sdk.frameworks)
    Carbon
    Cocoa
    ScriptingBridge
    SkyLight
    ;

  stdenv' = overrideSDK stdenv {
    darwinMinVersion = "11.0";
    darwinSdkVersion = "12.3";
  };
in
stdenv'.mkDerivation (finalAttrs: {
  pname = "yabai";
  version = "8.0.0";

  src = fetchFromGitHub {
    owner = "koekeishiya";
    repo = "yabai";
    rev = "cee556de6c98f7647aa866c43e504cdb44be793e";
    hash = "sha256-boxkPbeGO+wgDtmIVcR3sxOcOmickxrn2r7cAqCPepI=";
  };

  env = {
    # silence service.h error
    NIX_CFLAGS_COMPILE = "-Wno-implicit-function-declaration";
  };

  nativeBuildInputs = [
    installShellFiles
    xcodebuild
    xxd
  ];

  buildInputs = [
    Carbon
    Cocoa
    ScriptingBridge
    SkyLight
  ];

  dontConfigure = true;
  enableParallelBuilding = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,share/icons/hicolor/scalable/apps}

    cp ./bin/yabai $out/bin/yabai
    ${lib.optionalString stdenv.isx86_64 "cp ./assets/icon/icon.svg $out/share/icons/hicolor/scalable/apps/yabai.svg"}
    installManPage ./doc/yabai.1

    runHook postInstall
  '';

  postPatch = # bash
    ''
      # aarch64 code is compiled on all targets, which causes our Apple SDK headers to error out.
      # Since multilib doesn't work on darwin i dont know of a better way of handling this.
      substituteInPlace makefile \
      --replace-fail "-arch arm64e" "" \
      --replace-fail '-arch ${if stdenv.isAarch64 then "x86_64" else "arm64"}' ""
      # --replace-fail "clang" "${stdenv.cc.targetPrefix}clang"
    '';

  passthru = {
    tests.version = testers.testVersion {
      package = yabai;
      version = "yabai-v${finalAttrs.version}";
    };

    updateScript = writeShellScript "update-yabai" ''
      set -o errexit
      export PATH="${
        lib.makeBinPath [
          curl
          jq
          common-updater-scripts
        ]
      }"
      NEW_VERSION=$(curl --silent https://api.github.com/repos/koekeishiya/yabai/releases/latest | jq '.tag_name | ltrimstr("v")' --raw-output)
      if [[ "${finalAttrs.version}" = "$NEW_VERSION" ]]; then
          echo "The new version same as the old version."
          exit 0
      fi
      for platform in ${lib.escapeShellArgs finalAttrs.meta.platforms}; do
        update-source-version "yabai" "$NEW_VERSION" --ignore-same-version --source-key="sources.$platform"
      done
    '';
  };

  meta = {
    description = "Tiling window manager for macOS based on binary space partitioning";
    longDescription = ''
      yabai is a window management utility that is designed to work as an extension to the built-in
      window manager of macOS. yabai allows you to control your windows, spaces and displays freely
      using an intuitive command line interface and optionally set user-defined keyboard shortcuts
      using skhd and other third-party software.
    '';
    homepage = "https://github.com/koekeishiya/yabai";
    changelog = "https://github.com/koekeishiya/yabai/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    platforms = lib.platforms.darwin;
    mainProgram = "yabai";
    maintainers = with lib.maintainers; [
      cmacrae
      shardy
      khaneliman
    ];
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
