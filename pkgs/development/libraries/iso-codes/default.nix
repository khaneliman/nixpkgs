{ lib, stdenv, fetchurl, gettext, python3 }:

stdenv.mkDerivation rec {
  pname = "iso-codes";
  version = "4.16.0";

  src = fetchurl {
    url = "https://salsa.debian.org/iso-codes-team/iso-codes/-/archive/v${version}/${pname}-v${version}.tar.gz";
    sha256 = "sha256-fJkPw5oFl1vtsBdeP/Cfw4MEiBX2i0Yqu/BVqAMuZsw=";
  };

  nativeBuildInputs = [ gettext python3 ];

  enableParallelBuilding = true;

  meta = with lib; {
    homepage = "https://salsa.debian.org/iso-codes-team/iso-codes";
    description = "Various ISO codes packaged as XML files";
    license = licenses.lgpl21;
    platforms = platforms.all;
  };
}
