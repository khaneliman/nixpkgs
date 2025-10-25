{
  lib,
  rustPlatform,
  fetchFromGitHub,
  versionCheckHook,
  nix-update-script,
  wayland-scanner,
  wayland,
  wayland-protocols,
  dbus,
  pkg-config,
  libinput,
  udev,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "stasis";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "saltnpepper97";
    repo = "stasis";
    tag = "v${finalAttrs.version}";
    hash = "sha256-gJB/y6jSBJZjBTQB9sxbVpllSfF6jwKOEeLqlgIStMA=";
  };

  cargoHash = "sha256-JX0imd+FuuBq8d3FAYEQ+LLZQV39f8Iu9ftLASs00Fc=";

  nativeBuildInputs = [
    pkg-config
    wayland-scanner
  ];

  buildInputs = [
    wayland
    wayland-protocols
    dbus
    libinput
    udev
  ];

  #There are no tests
  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Modern idle manager for Wayland";
    longDescription = ''
      Stasis is a smart idle manager for Wayland that understands context.
      It automatically prevents idle when watching videos, reading documents,
      or playing music, while allowing idle when appropriate. Features include
      media-aware idle handling, application-specific inhibitors, Wayland idle
      inhibitor protocol support, and flexible configuration using the RUNE
      configuration language.
    '';
    homepage = "https://github.com/saltnpepper97/stasis";
    changelog = "https://github.com/saltnpepper97/stasis/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ nartsiss ];
    platforms = lib.platforms.linux;
    mainProgram = "stasis";
  };
})
