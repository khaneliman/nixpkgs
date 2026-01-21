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
  enchant,
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
  harfbuzzFull,
  heimdal,
  hyphen,
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
  libjpeg8,
  libjson,
  libmanette,
  libnotify,
  libpng12,
  libpulseaudio,
  libredirect,
  libseccomp,
  libsecret,
  libsoup_2_4,
  libvorbis,
  libxml2_13,
  libxslt,
  llvmPackages,
  more,
  nspr,
  nss,
  opencv4,
  openssl,
  pango,
  pcsclite,
  perl,
  sane-backends,
  speex,
  symlinkJoin,
  systemd,
  tzdata,
  util-linux,
  which,
  woff2,
  xorg,
  zlib,
  gst_all_1,
  libva,
  x264,

  homepage,
  version,
  hash,

  extraCerts ? [ ],
}:

let
  fuse3' = symlinkJoin {
    name = "fuse3-backwards-compat";
    paths = [ (lib.getLib fuse3) ];
    postBuild = ''
      ln -sf $out/lib/libfuse3.so.3.17.4 $out/lib/libfuse3.so.3
    '';
  };

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
    name = "linuxx64-${version}.tar.gz";
    sha256 = hash;

    message = ''
      In order to use Citrix Workspace, you need to comply with the Citrix EULA and download
      the 64-bit binaries, .tar.gz from:

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
    enchant
    fontconfig
    freetype
    fuse3'
    gdk-pixbuf
    glib-networking
    gnome2.gtkglext
    gtk2
    gtk2-x11
    gtk3
    gtk_engines
    harfbuzzFull
    heimdal
    hyphen
    krb5
    lcms2
    libGL
    libcanberra-gtk3
    libcap
    libcxx
    libgbm
    libinput
    libjpeg8
    libjson
    libmanette
    libnotify
    libpng12
    libpulseaudio
    libseccomp
    libsecret
    libsoup_2_4
    libvorbis
    libxml2_13
    libxslt
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

    # GStreamer dependencies for webcam/mic redirection (HDX RealTime)
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-vaapi
    (lib.getOutput "out" libva)
    (lib.getOutput "lib" x264)
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

    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-vaapi
    (lib.getOutput "out" libva)
    (lib.getOutput "lib" x264)
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
      gstPluginPath = lib.makeSearchPath "lib/gstreamer-1.0" [
        (lib.getLib gst_all_1.gstreamer)
        (lib.getLib gst_all_1.gst-plugins-base)
        (lib.getLib gst_all_1.gst-plugins-good)
        (lib.getLib gst_all_1.gst-plugins-bad)
        (lib.getLib gst_all_1.gst-plugins-ugly)
        (lib.getLib gst_all_1.gst-vaapi)
      ];
      wrapArgs =
        program:
        lib.concatStringsSep " " [
          (lib.optionalString (icaFlag program != null) ''--add-flags "${icaFlag program} $ICAInstDir"'')
          "--set ICAROOT \"$ICAInstDir\""
          "--prefix GIO_EXTRA_MODULES : \"${glib-networking}/lib/gio/modules\""
          "--prefix LD_LIBRARY_PATH : \"$ICAInstDir:$ICAInstDir/lib:$ICAInstDir/usr/lib/x86_64-linux-gnu:$ICAInstDir/usr/lib/x86_64-linux-gnu/webkit2gtk-4.0/injected-bundle\""
          "--prefix LD_LIBRARY_PATH : \"${
            lib.makeLibraryPath [
              (lib.getOutput "out" libva)
              (lib.getOutput "lib" x264)
            ]
          }\""
          "--set LD_PRELOAD \"${libredirect}/lib/libredirect.so ${lib.getLib pcsclite}/lib/libpcsclite.so\""
          "--set NIX_REDIRECTS \"/usr/share/zoneinfo=${tzdata}/share/zoneinfo:/etc/zoneinfo=${tzdata}/share/zoneinfo:/etc/timezone=$ICAInstDir/timezone:/usr/lib/x86_64-linux-gnu=$ICAInstDir/usr/lib/x86_64-linux-gnu\""
          "--set GST_PLUGIN_SYSTEM_PATH_1_0 \"${gstPluginPath}\""
          "--set GST_PLUGIN_PATH_1_0 \"${gstPluginPath}\""
          "--set GST_PLUGIN_PATH \"${gstPluginPath}\""
        ];
      wrap = program: ''
        wrapProgram $out/opt/citrix-icaclient/${program} ${wrapArgs program}
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
      sed -i -e 's,^ANSWER="",ANSWER="$INSTALLER_YES",g' -e 's,/bin/true,true,g' -e 's, -C / , -C . ,g' ./linuxx64/hinst
      source_date=$(date --utc --date=@$SOURCE_DATE_EPOCH "+%F %T")
      faketime -f "$source_date" ${stdenv.shell} linuxx64/hinst CDROM "$(pwd)"

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

      # We support only Gstreamer 1.0
      rm $ICAInstDir/util/{gst_aud_{play,read},gst_*0.10,libgstflatstm0.10.so} || true
      ln -sf $ICAInstDir/util/gst_play1.0 $ICAInstDir/util/gst_play
      ln -sf $ICAInstDir/util/gst_read1.0 $ICAInstDir/util/gst_read

      echo "We arbitrarily set the timezone to UTC. No known consequences at this point."
      echo UTC > "$ICAInstDir/timezone"

      echo "Copy .desktop files."
      cp $out/opt/citrix-icaclient/desktop/* $out/share/applications/

      # Install USB redirection support
      # The hinst installer skips USB files when it can't write to /etc, so we install them manually
      echo "Installing USB redirection support..."
      if [ -d "./linuxx64/linuxx64.cor/usb" ]; then
        # Install USB daemon and tools
        install -m 755 ./linuxx64/linuxx64.cor/usb/ctxusbd "$ICAInstDir/"
        install -m 755 ./linuxx64/linuxx64.cor/usb/ctxusb "$ICAInstDir/"
        install -m 755 ./linuxx64/linuxx64.cor/usb/ctx_usb_isactive "$ICAInstDir/"
        install -m 644 ./linuxx64/linuxx64.cor/usb/usb.conf "$ICAInstDir/"
        install -m 644 ./linuxx64/linuxx64.cor/usb/VDGUSB.DLL "$ICAInstDir/"

        # Install udev rules (using our own file since upstream has deprecated OPTIONS and hardcoded paths)
        mkdir -p $out/lib/udev/rules.d
        substitute ${./85-ica-usb.rules} $out/lib/udev/rules.d/85-ica-usb.rules \
          --replace-fail "@icaroot@" "$ICAInstDir" \
          --replace-fail "@logger@" "${util-linux}"
      else
        echo "Warning: USB directory not found in tarball, USB redirection will not be available"
      fi

      # Also install the HID and multitouch udev rules from config/
      if [ -d "$ICAInstDir/config" ]; then
        cp "$ICAInstDir/config/"*.rules $out/lib/udev/rules.d/ 2>/dev/null || true
      fi

      # We introduce a dependency on the source file so that it need not be redownloaded everytime
      echo $src >> "$out/share/workspace_dependencies.pin"

      runHook postInstall
    '';

  # Make sure that `autoPatchelfHook` is executed before
  # running `ctx_rehash`.
  dontAutoPatchelf = true;
  # Null out hardcoded webkit bundle path so it falls back to LD_LIBRARY_PATH
  postFixup = ''
    ${lib.getExe perl} -0777 -pi -e 's{/usr/lib/x86_64-linux-gnu/webkit2gtk-4.0/injected-bundle/}{"\0" x length($&)}e' \
      $out/opt/citrix-icaclient/usr/lib/x86_64-linux-gnu/libwebkit2gtk-4.0.so.37.56.4

    autoPatchelf -- "$out"

    $out/opt/citrix-icaclient/util/ctx_rehash
  '';

  meta = {
    # Older versions need webkitgtk_4_0 which was removed.
    # 25.08 bundles the same.
    broken = lib.versionOlder version "25.08";
    license = lib.licenses.unfree;
    description = "Citrix Workspace";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ flacks ];
    inherit homepage;
  };
}
