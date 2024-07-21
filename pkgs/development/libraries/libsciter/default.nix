{ lib
, glib
, cairo
, libuuid
, pango
, gtk3
, stdenv
, fetchurl
, autoPatchelfHook
}:

stdenv.mkDerivation (finalAttrs:  {
  pname = "libsciter";
  version = "4.4.8.23-bis"; # Version specified in GitHub commit title

  src = finalAttrs.passthru.sources.${stdenv.hostPlatform.system} or (throw "Unsupported platform for libsciter: ${stdenv.hostPlatform.system}");

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [ glib cairo libuuid pango gtk3 ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    ${lib.optionalString stdenv.isLinux "install -m755 -D $src $out/lib/libsciter-gtk.so"}
    ${lib.optionalString stdenv.isDarwin "install -m755 -D $src $out/lib/libsciter.dylib"}

    runHook postInstall
  '';

  passthru = {
    sources = {
      "x86_64-linux" = fetchurl {
        url = "https://github.com/c-smile/sciter-sdk/raw/9f1724a45f5a53c4d513b02ed01cdbdab08fa0e5/bin.lnx/x64/libsciter-gtk.so";
        sha256 = "a1682fbf55e004f1862d6ace31b5220121d20906bdbf308d0a9237b451e4db86";
      };
      "aarch64-linux" = fetchurl {
        url = "https://github.com/c-smile/sciter-sdk/raw/524a90ef7eab16575df9496f7e4c374bbd5fb1fe/bin.lnx/arm64/libsciter-gtk.so";
        sha256 = "09f9apy5xzy1b7djzq9zmb629zhr8r96q0x7x70cycsfzdp8z8bf";
      };
      "aarch64-darwin" = fetchurl {
        url = "https://github.com/c-smile/sciter-sdk/raw/9f1724a45f5a53c4d513b02ed01cdbdab08fa0e5/bin.osx/libsciter.dylib";
        sha256 = "sha256-qNhEQ5tDy3DwKoYQxzX/3nikG6oeVRBYuGkURjAkCg0=";
      };
      "x86_64-darwin" = fetchurl {
        url = "https://github.com/c-smile/sciter-sdk/raw/9f1724a45f5a53c4d513b02ed01cdbdab08fa0e5/bin.osx/libsciter.dylib";
        sha256 = "sha256-qNhEQ5tDy3DwKoYQxzX/3nikG6oeVRBYuGkURjAkCg0=";
      };
    };
  };

  meta = with lib; {
    homepage = "https://sciter.com";
    description = "Embeddable HTML/CSS/JavaScript engine for modern UI development";
    platforms = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    maintainers = with maintainers; [ leixb ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.unfree;
  };
})
