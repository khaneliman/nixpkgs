{ lib, stdenvNoCC, fetchurl, nix-update-script }:

stdenvNoCC.mkDerivation rec {
  pname = "clash-geoip";
  version = "20240212";

  src = fetchurl {
    url = "https://github.com/Dreamacro/maxmind-geoip/releases/download/${version}/Country.mmdb";
    sha256 = "sha256-cNVEWdIRo2Z2FluZIR0O5o3Aso4tDcVyHAG3DkNmpSQ=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/etc/clash
    install -Dm 0644 $src -D $out/etc/clash/Country.mmdb
    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = with lib; {
    description = "A GeoLite2 data created by MaxMind";
    homepage = "https://github.com/Dreamacro/maxmind-geoip";
    license = licenses.unfree;
    maintainers = [];
    platforms = platforms.all;
  };
}
