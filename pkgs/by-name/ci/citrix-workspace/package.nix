{
  lib,
  stdenv,
  requireFile,
  runtimeShell,
  makeWrapper,
  autoPatchelfHook,
  wrapGAppsHook3,
  alsa-lib,
  atk,
  cacert,
  cairo,
  coreutils,
  dconf,
  enchant,
  file,
  fontconfig,
  freetype,
  fuse3,
  gdk-pixbuf,
  glib,
  glib-networking,
  gst_all_1,
  gtk3,
  harfbuzzFull,
  heimdal,
  hyphen,
  krb5,
  lcms2,
  libGL,
  libappindicator,
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
  libpulseaudio,
  libredirect,
  libseccomp,
  libsecret,
  libsoup_3,
  libvorbis,
  libxml2_13,
  libxslt,
  llvmPackages,
  makeBinaryWrapper,
  more,
  nspr,
  nss,
  pango,
  pcsclite,
  sane-backends,
  speex,
  symlinkJoin,
  systemd,
  tzdata,
  which,
  woff2,
  webkitgtk_4_1,
  libxtst,
  libxscrnsaver,
  libxrender,
  libxmu,
  libxinerama,
  libxfixes,
  libxext,
  libxaw,
  libx11,
  xprop,
  xdpyinfo,
  libxcb,
  zlib,
  extraCerts ? [ ],
}:

let
  gstPackages = [
    gst_all_1.gstreamer
    gst_all_1.gst-libav
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
  ];

  gstPluginPath = lib.makeSearchPathOutput "lib" "lib/gstreamer-1.0" gstPackages;

  fuse3' = symlinkJoin {
    name = "fuse3-backwards-compat";
    paths = [ (lib.getLib fuse3) ];
    postBuild = ''
      ln -sf $out/lib/libfuse3.so.3.* $out/lib/libfuse3.so.3
    '';
  };

  # hinst writes the service-continuity manifest only to user profiles; package a system copy.
  nmhManifest = builtins.toJSON {
    name = "com.citrix.workspace.native";
    description = "Launch NMH";
    path = "${placeholder "out"}/opt/citrix-icaclient/NativeMessagingHost";
    type = "stdio";
    allowed_origins = [
      "chrome-extension://dbdlmgpfijccjgnnpacnamgdfmljoeee/"
      "chrome-extension://pmdpflpcmcomdkocbehamllbfkdgnalf/"
    ];
  };

in

stdenv.mkDerivation (finalAttrs: {
  pname = "citrix-workspace";
  version = "26.04.0.105";

  src = requireFile rec {
    name = "linuxx64-${finalAttrs.version}.tar.gz";
    sha256 = "1kl6b1ldjd9gb6cmvhxf6ggvc3amq1kz0qwjlb1fp6dxx0pivwm8";

    message = ''
      In order to use Citrix Workspace, you need to comply with the Citrix EULA and download
      the 64-bit binaries, .tar.gz from:

      https://www.citrix.com/downloads/workspace-app/betas-and-tech-previews/workspace-app-tp-gcc11-for-linux.html

      (if you do not find version ${finalAttrs.version} there, try at
      https://www.citrix.com/downloads/workspace-app/)

      Once you have downloaded the file, please use the following command and re-run the
      installation:

      nix-prefetch-url file://$PWD/${name}
    '';
  };

  dontBuild = true;
  dontConfigure = true;
  strictDeps = true;
  __structuredAttrs = true;
  sourceRoot = ".";
  preferLocalBuild = true;
  passthru.icaroot = "${finalAttrs.finalPackage}/opt/citrix-icaclient";

  nativeBuildInputs = [
    autoPatchelfHook
    file
    libfaketime
    makeBinaryWrapper
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
    gtk3
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
    libpulseaudio
    libseccomp
    libsecret
    libsoup_3
    libvorbis
    libxml2_13
    libxslt
    llvmPackages.libunwind
    nspr
    nss
    pango
    pcsclite
    sane-backends
    speex
    stdenv.cc.cc
    (lib.getLib systemd)
    woff2
    webkitgtk_4_1
    libxscrnsaver
    libxaw
    libxmu
    libxtst
    zlib
  ]
  ++ gstPackages;

  runtimeDependencies = [
    glib
    glib-networking
    libappindicator
    (lib.getLib libcap)
    libGL
    pcsclite

    libx11
    libxscrnsaver
    libxext
    libxfixes
    libxinerama
    libxmu
    libxrender
    libxtst
    libxcb
    xdpyinfo
    xprop
  ];

  installPhase =
    let
      isSelfservice = program: (builtins.match "selfservice(.*)" program) != null;
      isWfica = program: (builtins.match "wfica(.*)" program) != null;

      # These helpers read ICAROOT from the environment; injected -icaroot flags
      # conflict with their argument parsing.
      isEnvOnly =
        program:
        builtins.elem program [
          "NativeMessagingHost"
          "UrlRedirector"
          "util/logmgr"
          "util/nfcui"
          "util/sendfeedback"
          "util/setlog"
          "util/storebrowse"
        ];

      icaFlag =
        program:
        if isSelfservice program then
          "--icaroot"
        else if isWfica program || isEnvOnly program then
          null
        else
          "-icaroot";

      ldLibraryPath =
        program:
        lib.concatStringsSep ":" (
          lib.optional (isWfica program) "$ICAInstDir"
          ++ [
            "$ICAInstDir/lib"
            "${lib.getLib webkitgtk_4_1}/lib/webkit2gtk-4.1/injected-bundle"
            # HdxRtcEngine loads libpulse.so.0 with dlopen, so autoPatchelf
            # cannot discover it from ELF dependencies.
            "${lib.getLib libpulseaudio}/lib"
          ]
        );

      runtimeSetup = ''
        timezoneFile="$ICAROOT/timezone"
        localtime=$(${lib.getExe' coreutils "readlink"} /etc/localtime 2>/dev/null || true)

        case "$localtime" in
          */zoneinfo/*)
            if [ -n "''${XDG_RUNTIME_DIR:-}" ] \
              && [ -d "$XDG_RUNTIME_DIR" ] \
              && [ -O "$XDG_RUNTIME_DIR" ]; then
              timezone="''${localtime##*/zoneinfo/}"
              candidate="$XDG_RUNTIME_DIR/citrix-timezone"

              if printf '%s\n' "$timezone" > "$candidate" 2>/dev/null; then
                timezoneFile="$candidate"
              fi
            fi
            ;;
        esac

        redirects="/usr/share/zoneinfo=${tzdata}/share/zoneinfo"
        redirects="$redirects:/etc/zoneinfo=${tzdata}/share/zoneinfo"
        redirects="$redirects:/etc/timezone=$timezoneFile"

        if [ -x /run/wrappers/bin/fusermount3 ]; then
          redirects="$redirects:/usr/bin/fusermount3=/run/wrappers/bin/fusermount3"
        fi

        export NIX_REDIRECTS="$redirects"
      '';

      # Only the ICA engine needs the top-level client directory on the library
      # path. Leaving it enabled for UI helpers exposes Citrix's session-only
      # libproxy.so to the embedded web stack, which then fails to resolve CGP
      # symbols.
      wrapperArgs =
        program:
        lib.concatStringsSep " \\\n          " (
          lib.optional (icaFlag program != null) ''--add-flags "${icaFlag program} $ICAInstDir"''
          ++ [
            ''--set ICAROOT "$ICAInstDir"''
            ''--prefix GIO_EXTRA_MODULES : "${glib-networking}/lib/gio/modules"''
            ''--prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "$ICAInstDir/gst-plugins:${gstPluginPath}"''
            ''--prefix LD_LIBRARY_PATH : "${ldLibraryPath program}"''
            ''--set LD_PRELOAD "${libredirect}/lib/libredirect.so ${lib.getLib pcsclite}/lib/libpcsclite.so"''
            # Citrix hardcodes /etc/timezone and /usr/bin/fusermount3; redirect both at launch.
            "--run ${lib.escapeShellArg runtimeSetup}"
          ]
          ++ lib.optionals (isWfica program) [
            # wfica is an X11 client (it runs under XWayland). On a Wayland
            # session Mesa's EGL loader otherwise auto-selects the Wayland
            # platform for wfica's startup OpenGL probe and segfaults in
            # wl_proxy_create_wrapper; pin the client to X11 (user-overridable).
            # See https://github.com/NixOS/nixpkgs/issues/540102
            "--set-default GDK_BACKEND x11"
            "--set-default EGL_PLATFORM x11"
          ]
        );

      # Runtime timezone detection requires shell wrappers rather than makeBinaryWrapper.
      wrap = program: ''
        wrapProgramShell $out/opt/citrix-icaclient/${program} \
          ${wrapperArgs program}
      '';

      wrapLink = program: ''
        ${wrap program}
        ln -sf $out/opt/citrix-icaclient/${program} $out/bin/${baseNameOf program}
      '';

      makeBinWrapper = program: wrapperName: ''
        makeShellWrapper $out/opt/citrix-icaclient/${program} $out/bin/${wrapperName} \
          ${wrapperArgs program}
      '';

      copyCert = path: ''
        cp -v ${path} $out/opt/citrix-icaclient/keystore/cacerts/${baseNameOf path}
      '';

      mkWrappers = lib.concatMapStringsSep "\n";

      toWrap = [
        "NativeMessagingHost"
        "UrlRedirector"
        "adapter"
        "selfservice"
        "util/configmgr"
        "util/conncenter"
        "util/ctx_rehash"
        "util/ctxwebhelper"
        "util/storebrowse"
      ];
    in
    ''
      runHook preInstall

      mkdir -p $out/{bin,share/applications}
      export ICAInstDir="$out/opt/citrix-icaclient"
      export HOME=$(mktemp -d)

      # Run upstream installer in the store-path.
      sed -i \
        -e 's,^ANSWER="",ANSWER="$INSTALLER_YES",g' \
        -e 's,/bin/true,true,g' \
        -e 's, -C / , -C . ,g' \
        -e 's,^[[:space:]]*install_deviceTrust "\$ICAInstDir",      :,' \
        -e 's,^[[:space:]]*install_EPA_with_prompt "\$ICAInstDir",      :,' \
        -e 's,^[[:space:]]*install_fido2Service "\$CDSourceDir" "\$ICAInstDir",  :,' \
        ./linuxx64/hinst
      source_date=$(date --utc --date=@$SOURCE_DATE_EPOCH "+%F %T")
      faketime -f "$source_date" ${stdenv.shell} linuxx64/hinst CDROM "$(pwd)"

      # The GCC 11 package line links against libsoup 3 and WebKitGTK 4.1, but
      # the tarball still contains the legacy WebKitGTK 4.0 bundle.
      rm -rf "$ICAInstDir/Webkit2gtk4.0"

      # Non-root hinst omits USB; redirection requires a system daemon and setuid wrapper.
      install -m555 -t "$ICAInstDir" \
        linuxx64/linuxx64.cor/usb/{VDGUSB.DLL,ctxusbd,ctx_usb_isactive}
      install -m555 linuxx64/linuxx64.cor/usb/ctxusb "$ICAInstDir/ctxusb.real"
      # security.wrappers preserves ICAROOT, so force the store root before
      # the privileged binary reads its USB policy.
      makeBinaryWrapper "$ICAInstDir/ctxusb.real" "$ICAInstDir/ctxusb-wrapper" \
        --set ICAROOT "$ICAInstDir"
      # VDGUSB.DLL execs sibling ctxusb directly. Preserve the raw binary for the
      # setuid wrapper and bridge the sibling path to /run/wrappers.
      printf '%s\n' \
        '#!${runtimeShell}' \
        'exec /run/wrappers/bin/ctxusb "$@"' \
        > "$ICAInstDir/ctxusb"
      chmod 555 "$ICAInstDir/ctxusb"
      install -m644 -t "$ICAInstDir" linuxx64/linuxx64.cor/usb/usb.conf
      sed -i \
        -e 's/^[ \t]*VirtualDriver[ \t]*=.*$/&, GenericUSB/' \
        -e '/\[ICA 3.0\]/a GenericUSB=on' \
        "$ICAInstDir/config/module.ini"
      chmod u+w "$ICAInstDir/config/module.ini"
      printf '[GenericUSB]\nDriverName = VDGUSB.DLL\n' >> "$ICAInstDir/config/module.ini"
      grep -Fq 'GenericUSB=on' "$ICAInstDir/config/module.ini"
      grep -Eq '^VirtualDriver[[:space:]]*=.*GenericUSB' "$ICAInstDir/config/module.ini"
      grep -Fq 'DriverName = VDGUSB.DLL' "$ICAInstDir/config/module.ini"

      # Scope input access to touchscreens classified by 60-input-id. Replace HAL
      # suppression with udisks/ModemManager ignores; FIDO uses 70-uaccess.
      mkdir -p $out/lib/udev/rules.d
      printf '%s\n' \
        'KERNEL=="event[0-9]*", SUBSYSTEM=="input", ENV{ID_INPUT_TOUCHSCREEN}=="1", TAG+="uaccess"' \
        > $out/lib/udev/rules.d/61-ica-mtch.rules
      printf '%s\n' \
        "SUBSYSTEM==\"usb\", ACTION==\"add\", PROGRAM==\"$ICAInstDir/ctx_usb_isactive\", ENV{UDISKS_IGNORE}=\"1\", ENV{ID_MM_DEVICE_IGNORE}=\"1\"" \
        > $out/lib/udev/rules.d/85-ica-usb.rules

      # Package hinst's user unit; setlog/logmgr require its daemon.
      mkdir -p $out/lib/systemd/user
      sed \
        -e '/^#/d' \
        -e "s,###ICAROOT###,$ICAInstDir,g" \
        -e '/###CitrixUser###/d' \
        -e 's,###USER###,default,' \
        linuxx64/linuxx64.cor/ctxcwalogd.service > $out/lib/systemd/user/ctxcwalogd.service

      # hinst writes browser manifests only to user homes; package system copies.
      for browser in opt/chrome chromium opt/edge; do
        mkdir -p "$out/etc/$browser/native-messaging-hosts"
        printf '%s' ${lib.escapeShellArg nmhManifest} \
          > "$out/etc/$browser/native-messaging-hosts/com.citrix.workspace.native.json"
        sed "s,/opt/Citrix/ICAClient,$ICAInstDir,g" \
          "$ICAInstDir/config/com.citrix.urlinterceptor.json" \
          > "$out/etc/$browser/native-messaging-hosts/com.citrix.urlinterceptor.json"
      done

      # Recreate bundled OpenCV SONAME links required by libbgblur.
      for so in "$ICAInstDir"/lib/third_party/*.so.*; do
        soname=$(objdump -p "$so" | awk '$1 == "SONAME" { print $2 }')
        filename=$(basename "$so")
        if [ -n "$soname" ] && [ "$soname" != "$filename" ]; then
          ln -sf "$filename" "$ICAInstDir/lib/third_party/$soname"
        fi
      done

      # FHS launcher hinst generates even for non-root installs; it hardcodes
      # store paths without any of the wrapper environment.
      rm -f "$ICAInstDir/wfica.sh"
      chmod +x "$ICAInstDir/util/setlog"
      ${mkWrappers wrapLink toWrap}
      ${makeBinWrapper "wfica" "wfica"}
      ${makeBinWrapper "util/setlog" "citrix-setlog"}
      ${mkWrappers wrap [
        "PrimaryAuthManager"
        "ServiceRecord"
        "AuthManagerDaemon"
        "util/logmgr"
        "util/new_store"
        "util/nfcui"
        "util/sendfeedback"
      ]}

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

      # hinst links these GStreamer elements system-wide; expose them through
      # the wrapper plugin path instead.
      mkdir -p "$ICAInstDir/gst-plugins"
      ln -s "$ICAInstDir/util/libgstflatstm1.0.so" \
        "$ICAInstDir/gst-plugins/libgstflatstm.so"
      ln -s "$ICAInstDir/lib/libctxbeffect.so" "$ICAInstDir/gst-plugins/"

      # `hinst` disables multimedia when it cannot link into FHS plugin
      # directories. In Nix we provide the plugin path via wrappers instead.
      sed -i 's/^MultiMedia=Off$/MultiMedia=On/' "$ICAInstDir/config/module.ini"
      grep -Fxq 'MultiMedia=On' "$ICAInstDir/config/module.ini"

      echo "We arbitrarily set the timezone to UTC. No known consequences at this point."
      echo UTC > "$ICAInstDir/timezone"

      echo "Patch .desktop files."
      for desktop in "$ICAInstDir"/desktop/*.desktop; do
        sed -i \
          -e "s#/opt/Citrix/ICAClient#$ICAInstDir#g" \
          "$desktop"

        case "$(basename "$desktop")" in
          citrixapp.desktop)
            sed -i \
              -e "s#^TryExec=.*#TryExec=$out/bin/selfservice#" \
              -e "s#^Exec=.*#Exec=$out/bin/selfservice %u#" \
              "$desktop"
            ;;
          citrixweb.desktop | ctxaadsso.desktop | fido2_llt.desktop | receiver.desktop | receiver_fido2.desktop)
            sed -i \
              -e "s#^TryExec=.*#TryExec=$out/bin/ctxwebhelper#" \
              -e "s#^Exec=.*#Exec=$out/bin/ctxwebhelper %u#" \
              "$desktop"
            ;;
          selfservice.desktop)
            sed -i \
              -e "s#^TryExec=.*#TryExec=$out/bin/selfservice#" \
              -e "s#^Exec=.*#Exec=$out/bin/selfservice#" \
              "$desktop"
            ;;
          wfica.desktop)
            sed -i \
              -e "s#^TryExec=.*#TryExec=$out/bin/adapter#" \
              -e "s#^Exec=.*#Exec=$out/bin/adapter %f#" \
              "$desktop"
            ;;
        esac
      done

      echo "Copy .desktop files."
      cp $out/opt/citrix-icaclient/desktop/*.desktop $out/share/applications/

      install -Dm444 "$ICAInstDir/desktop/Citrix-mime_types.xml" \
        $out/share/mime/packages/Citrix-mime_types.xml
      install -Dm444 "$ICAInstDir/icons/000_Receiver_64.png" \
        $out/share/icons/hicolor/64x64/apps/Citrix-Receiver.png

      runHook postInstall
    '';

  # Make sure that `autoPatchelfHook` is executed before
  # running `ctx_rehash`.
  dontAutoPatchelf = true;
  postFixup = ''
    addAutoPatchelfSearchPath "$out/opt/citrix-icaclient/lib"
    addAutoPatchelfSearchPath "$out/opt/citrix-icaclient/lib/third_party"
    autoPatchelf -- "$out"

    $out/opt/citrix-icaclient/util/ctx_rehash
  '';

  meta = {
    license = lib.licenses.unfree;
    description = "Citrix Workspace";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [
      khaneliman
      flacks
    ];
    homepage = "https://www.citrix.com/downloads/workspace-app/betas-and-tech-previews/workspace-app-tp-gcc11-for-linux.html";
  };
})
