{
  lib,
  stdenv,
  requireFile,
  makeWrapper,
  autoPatchelfHook,
  wrapGAppsHook3,
  alsa-lib,
  atk,
  cacert,
  cairo,
  dconf,
  enchant2,
  file,
  fontconfig,
  freetype,
  fuse3,
  gdk-pixbuf,
  glib,
  glib-networking,
  gnome2,
  gtk2,
  gtk2-x11,
  gtk3,
  gtk_engines,
  harfbuzz,
  heimdal,
  hyphen,
  icu,
  krb5,
  lcms2,
  libGL,
  libappindicator-gtk3,
  libcanberra-gtk3,
  libcap,
  libcxx,
  libfaketime,
  libgbm,
  libinput,
  libjpeg,
  libjson,
  libnotify,
  libpng12,
  libpulseaudio,
  libredirect,
  libseccomp,
  libsecret,
  libsoup_2_4,
  libvorbis,
  libxslt,
  libxml2_13,
  llvmPackages,
  more,
  nspr,
  nss,
  opencv4,
  openssl,
  pango,
  pcsclite,
  sane-backends,
  speex,
  symlinkJoin,
  systemd,
  tzdata,
  which,
  woff2,
  xorg,
  zlib,

  homepage,
  version,
  prefix,
  hash,
  broken ? false,

  extraCerts ? [ ],
}:

let
  openssl' = symlinkJoin {
    name = "openssl-backwards-compat";
    nativeBuildInputs = [ makeWrapper ];
    paths = [ (lib.getLib openssl) ];
    postBuild = ''
      ln -sf $out/lib/libcrypto.so $out/lib/libcrypto.so.1.0.0
      ln -sf $out/lib/libssl.so $out/lib/libssl.so.1.0.0
    '';
  };

  opencv4' = symlinkJoin {
    name = "opencv4-compat";
    nativeBuildInputs = [ makeWrapper ];
    paths = [ opencv4 ];
    postBuild = ''
      for so in ${opencv4}/lib/*.so; do
        ln -s "$so" $out/lib/$(basename "$so").407 || true
        ln -s "$so" $out/lib/$(basename "$so").410 || true
      done
    '';
  };

in

stdenv.mkDerivation rec {
  pname = "citrix-workspace";
  inherit version;

  src = requireFile rec {
    name = "${prefix}-${version}.tar.gz";
    sha256 = hash;

    message = ''
      In order to use Citrix Workspace, you need to comply with the Citrix EULA and download
      the ${if stdenv.hostPlatform.is64bit then "64-bit" else "32-bit"} binaries, .tar.gz from:

      ${homepage}

      (if you do not find version ${version} there, try at
      https://www.citrix.com/downloads/workspace-app/)

      Once you have downloaded the file, please use the following command and re-run the
      installation:

      nix-prefetch-url file://\$PWD/${name}
    '';
  };

  dontBuild = true;
  dontConfigure = true;
  sourceRoot = ".";
  preferLocalBuild = true;
  passthru.icaroot = "${placeholder "out"}/opt/citrix-icaclient";

  nativeBuildInputs = [
    autoPatchelfHook
    file
    libfaketime
    makeWrapper
    more
    which
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    atk
    cairo
    dconf
    enchant2
    fontconfig
    freetype
    (lib.getLib fuse3)
    gdk-pixbuf
    glib-networking
    gnome2.gtkglext
    gtk2
    gtk2-x11
    gtk3
    gtk_engines
    harfbuzz
    heimdal
    hyphen
    icu
    krb5
    lcms2
    libGL
    libcanberra-gtk3
    libcap
    libcxx
    libgbm
    libinput
    libjpeg
    libjson
    libnotify
    libpng12
    libpulseaudio
    libseccomp
    libsecret
    libsoup_2_4
    libvorbis
    libxslt
    libxml2_13
    llvmPackages.libunwind
    nspr
    nss
    opencv4'
    openssl'
    pango
    pcsclite
    sane-backends
    speex
    stdenv.cc.cc
    (lib.getLib systemd)
    woff2
    xorg.libXScrnSaver
    xorg.libXaw
    xorg.libXmu
    xorg.libXtst
    zlib
  ];

  runtimeDependencies = [
    glib
    glib-networking
    libappindicator-gtk3
    libGL
    pcsclite

    xorg.libX11
    xorg.libXScrnSaver
    xorg.libXext
    xorg.libXfixes
    xorg.libXinerama
    xorg.libXmu
    xorg.libXrender
    xorg.libXtst
    xorg.libxcb
    xorg.xdpyinfo
    xorg.xprop
  ];

  installPhase =
    let
      icaFlag =
        program:
        if (builtins.match "selfservice(.*)" program) != null then
          "--icaroot"
        else if (builtins.match "wfica(.*)" program != null) then
          null
        else
          "-icaroot";
      wrap = program: ''
        wrapProgram $out/opt/citrix-icaclient/${program} \
          ${lib.optionalString (icaFlag program != null) ''--add-flags "${icaFlag program} $ICAInstDir"''} \
          --set ICAROOT "$ICAInstDir" \
          --prefix GIO_EXTRA_MODULES : "${glib-networking}/lib/gio/modules" \
          --prefix LD_LIBRARY_PATH : "$ICAInstDir:$ICAInstDir/lib:$ICAInstDir/lib/webkit2gtk-4.0" \
          --set LD_PRELOAD "${libredirect}/lib/libredirect.so ${lib.getLib pcsclite}/lib/libpcsclite.so" \
          --set NIX_REDIRECTS "/usr/share/zoneinfo=${tzdata}/share/zoneinfo:/etc/zoneinfo=${tzdata}/share/zoneinfo:/etc/timezone=$ICAInstDir/timezone"
      '';
      wrapLink = program: ''
        ${wrap program}
        ln -sf $out/opt/citrix-icaclient/${program} $out/bin/${baseNameOf program}
      '';

      copyCert = path: ''
        cp -v ${path} $out/opt/citrix-icaclient/keystore/cacerts/${baseNameOf path}
      '';

      mkWrappers = lib.concatMapStringsSep "\n";

      toWrap = [
        "wfica"
        "selfservice"
        "util/configmgr"
        "util/conncenter"
        "util/ctx_rehash"
      ];
    in
    ''
      runHook preInstall

      mkdir -p $out/{bin,share/applications}
      export ICAInstDir="$out/opt/citrix-icaclient"
      export HOME=$(mktemp -d)

      # Run upstream installer in the store-path.
      sed -i -e 's,^ANSWER="",ANSWER="$INSTALLER_YES",g' -e 's,/bin/true,true,g' ./${prefix}/hinst
      source_date=$(date --utc --date=@$SOURCE_DATE_EPOCH "+%F %T")
      faketime -f "$source_date" ${stdenv.shell} ${prefix}/hinst CDROM "$(pwd)"

      if [ -f "$ICAInstDir/util/setlog" ]; then
        chmod +x "$ICAInstDir/util/setlog"
        ln -sf "$ICAInstDir/util/setlog" "$out/bin/citrix-setlog"
      fi
      ${mkWrappers wrapLink toWrap}
      ${mkWrappers wrap [
        "PrimaryAuthManager"
        "ServiceRecord"
        "AuthManagerDaemon"
        "util/ctxwebhelper"
      ]}

      ln -sf $ICAInstDir/util/storebrowse $out/bin/storebrowse

      # As explained in https://wiki.archlinux.org/index.php/Citrix#Security_Certificates
      echo "Expanding certificates..."
      pushd "$ICAInstDir/keystore/cacerts"
      awk 'BEGIN {c=0;} /BEGIN CERT/{c++} { print > "cert." c ".pem"}' \
        < ${cacert}/etc/ssl/certs/ca-bundle.crt
      popd

      ${mkWrappers copyCert extraCerts}

      # Extract bundled webkit2gtk-4.0 libraries
      # Citrix bundles webkit libraries to support Ubuntu 24.04+ which removed webkit2gtk-4.0 from repos
      echo "Extracting bundled webkit2gtk-4.0 libraries..."
      if [ -f "$ICAInstDir/Webkit2gtk4.0/webkit2gtk-4.0.tar.gz" ]; then
        pushd "$ICAInstDir"
        tar -xzf Webkit2gtk4.0/webkit2gtk-4.0.tar.gz
        # Move webkit libraries to lib directory for easier discovery
        mkdir -p lib/webkit2gtk-4.0
        cp -r webkit2gtk-4.0-package/usr/lib/x86_64-linux-gnu/* lib/webkit2gtk-4.0/
        # Clean up
        rm -rf webkit2gtk-4.0-package Webkit2gtk4.0
        popd
      else
        echo "Warning: Bundled webkit2gtk-4.0 tarball not found"
      fi

      # See https://developer-docs.citrix.com/en-us/citrix-workspace-app-for-linux/citrix-workspace-app-for-linux-oem-reference-guide/reference-information/#library-files
      # Those files are fallbacks to support older libwekit.so and libjpeg.so
      rm $out/opt/citrix-icaclient/lib/ctxjpeg_fb_8.so || true
      rm $out/opt/citrix-icaclient/lib/UIDialogLibWebKit.so || true

      # We support only Gstreamer 1.0
      rm $ICAInstDir/util/{gst_aud_{play,read},gst_*0.10,libgstflatstm0.10.so} || true
      ln -sf $ICAInstDir/util/gst_play1.0 $ICAInstDir/util/gst_play
      ln -sf $ICAInstDir/util/gst_read1.0 $ICAInstDir/util/gst_read

      echo "We arbitrarily set the timezone to UTC. No known consequences at this point."
      echo UTC > "$ICAInstDir/timezone"

      echo "Copy .desktop files."
      cp $out/opt/citrix-icaclient/desktop/* $out/share/applications/

      # We introduce a dependency on the source file so that it need not be redownloaded everytime
      echo $src >> "$out/share/workspace_dependencies.pin"

      runHook postInstall
    '';

  # Make sure that `autoPatchelfHook` is executed before
  # running `ctx_rehash`.
  dontAutoPatchelf = true;

  # Ignore missing optional dependencies from bundled webkit and optional Citrix features
  autoPatchelfIgnoreMissingDeps = [
    "libfuse3.so.3"        # Optional FUSE filesystem support (ctxfuse)
    "libharfbuzz-icu.so.0" # Optional harfbuzz ICU support (advanced text shaping)
    "libmanette-0.2.so.0"  # Optional gamepad support in webkit
  ];
  preFixup = ''
    find $out/opt/citrix-icaclient/lib -name "libopencv_imgcodecs.so.*" | while read -r fname; do
      # lib needs libtiff.so.5, but nixpkgs provides libtiff.so.6
      patchelf --replace-needed libtiff.so.5 libtiff.so $fname
      # lib needs libjpeg.so.8, but nixpkgs provides libjpeg.so.9
      patchelf --replace-needed libjpeg.so.8 libjpeg.so $fname
    done

    # Bundled webkit needs libjpeg.so.8, but nixpkgs provides libjpeg.so.9
    if [ -f "$out/opt/citrix-icaclient/lib/webkit2gtk-4.0/libwebkit2gtk-4.0.so.37.56.4" ]; then
      patchelf --replace-needed libjpeg.so.8 libjpeg.so "$out/opt/citrix-icaclient/lib/webkit2gtk-4.0/libwebkit2gtk-4.0.so.37.56.4"
    fi
  '';
  postFixup = ''
    autoPatchelf -- "$out"
    $out/opt/citrix-icaclient/util/ctx_rehash
  '';

  meta = with lib; {
    inherit broken;
    license = licenses.unfree;
    description = "Citrix Workspace";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ] ++ optional (versionOlder version "24") "i686-linux";
    maintainers = with maintainers; [ flacks ];
    inherit homepage;
  };
}
