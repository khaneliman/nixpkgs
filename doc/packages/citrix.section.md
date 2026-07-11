# Citrix Workspace {#sec-citrix}

The [Citrix Workspace App](https://www.citrix.com/products/workspace-app/) is a remote desktop viewer which provides access to [XenDesktop](https://www.citrix.com/products/xenapp-xendesktop/) installations.

## Basic usage {#sec-citrix-base}

The tarball archive needs to be downloaded manually, as the license agreements of the vendor for [Citrix Workspace](https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html) needs to be accepted first. Then run `nix-prefetch-url file://$PWD/linuxx64-$version.tar.gz`. With the archive available in the store, the package can be built and installed with Nix.

## Citrix Self-service {#sec-citrix-selfservice}

The [self-service application](https://support.citrix.com/article/CTX200337) manages Citrix desktops and applications.

To set this up, you first have to [download the `.cr` file from the Netscaler Gateway](https://its.uiowa.edu/support/article/102186). After that, you can configure the `selfservice` like this:

```ShellSession
$ storebrowse -C ~/Downloads/receiverconfig.cr
$ selfservice
```

## Custom certificates {#sec-citrix-custom-certs}

The `Citrix Workspace App` in `nixpkgs` trusts several certificates [from the Mozilla database](https://curl.haxx.se/docs/caextract.html) by default.
However, several companies using Citrix might require their own corporate certificate.
On distros with imperative packaging, these certs can be stored easily in [`$ICAROOT`](https://citrix.github.io/receiver-for-linux-command-reference/), however, this directory is a store path in `nixpkgs`.
Override the package to add certificates:

```nix
let
  pkgs = import <nixpkgs> {
    config.allowUnfree = true;
  };
in
pkgs.citrix-workspace.override {
  extraCerts = [
    ./custom-cert-1.pem
    ./custom-cert-2.pem
  ];
}
```

## Optional system integration {#sec-citrix-system-integration}

Some Citrix Workspace features need system services or privileged helpers.
The following NixOS example enables HDX file transfer, Generic USB redirection, and OpenSC smart cards:

```nix
{
  pkgs,
  ...
}:

let
  citrix = pkgs.citrix-workspace.override {
    extraPkcs11Modules = [ "${pkgs.opensc}/lib/opensc-pkcs11.so" ];
  };
in
{
  environment.systemPackages = [ citrix ];

  # Provides /run/wrappers/bin/fusermount3 for HDX file transfer.
  programs.fuse.enable = true;

  # Activates Citrix USB and multitouch rules.
  services.udev.packages = [ citrix ];

  # Required for smart-card support.
  services.pcscd.enable = true;

  security.wrappers.ctxusb = {
    source = "${citrix.icaroot}/ctxusb-wrapper";
    owner = "root";
    group = "root";
    permissions = "a+rx";
    setuid = true;
  };

  systemd.services.ctxusbd = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "forking";
      ExecStart = "${citrix.icaroot}/ctxusbd";
      Restart = "always";
      RuntimeDirectory = "ctxusbd";
      RuntimeDirectoryMode = "0700";
    };
  };
}
```

The package also ships the `ctxcwalogd.service` systemd user unit used by the Citrix logging tools.

## Browser native messaging {#sec-citrix-browser-integration}

Citrix Workspace browser extensions use native-messaging manifests.
Register the two manifests for each installed browser.
For Chromium on NixOS:

```nix
{
  pkgs,
  ...
}:

let
  citrix = pkgs.citrix-workspace;
in
{
  environment.etc = {
    "chromium/native-messaging-hosts/com.citrix.workspace.native.json".source =
      "${citrix}/etc/chromium/native-messaging-hosts/com.citrix.workspace.native.json";
    "chromium/native-messaging-hosts/com.citrix.urlinterceptor.json".source =
      "${citrix}/etc/chromium/native-messaging-hosts/com.citrix.urlinterceptor.json";
  };
}
```

Use the corresponding `opt/chrome` or `opt/edge` path for Google Chrome or Microsoft Edge.

## Unsupported integrations {#sec-citrix-unsupported-integrations}

App Protection, Endpoint Analysis (EPA), and deviceTRUST are not supported because their installers require mutable `/etc` and `/usr/local` paths.
