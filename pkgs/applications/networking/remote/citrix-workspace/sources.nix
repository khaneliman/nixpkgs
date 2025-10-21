{ stdenv, lib }:

let
  mkVersionInfo =
    _:
    {
      major,
      minor,
      patch,
      x64hash,
      x86hash,
      x64suffix,
      x86suffix,
      homepage,
      broken ? false,
    }:
    {
      inherit homepage broken;
      version = "${major}.${minor}.${patch}.${
        if stdenv.hostPlatform.is64bit then x64suffix else x86suffix
      }";
      prefix = "linuxx${if stdenv.hostPlatform.is64bit then "64" else "86"}";
      hash = if stdenv.hostPlatform.is64bit then x64hash else x86hash;
    };

  # Attribute-set with all actively supported versions of the Citrix workspace app
  # for Linux.
  #
  # The latest versions can be found at https://www.citrix.com/downloads/workspace-app/linux/
  # x86 is unsupported past 23.11, see https://docs.citrix.com/en-us/citrix-workspace-app-for-linux/deprecation
  # Only versions 25.08+ support webkitgtk_4_1 (webkitgtk_4_0 has been removed from nixpkgs)
  supportedVersions = lib.mapAttrs mkVersionInfo {
    "25.08.0" = {
      major = "25";
      minor = "08";
      patch = "0";
      x64hash = "19nx7j78c84m6wlidkaicqf5rgy05rm85vzh3admhrl8q9zr1avr";
      x86hash = "";
      x64suffix = "88";
      x86suffix = "";
      homepage = "https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html";
    };
  };

  # Retain attribute-names for abandoned versions of Citrix workspace to
  # provide a meaningful error-message if it's attempted to use such an old one.
  #
  # The lifespans of Citrix products can be found here:
  # https://www.citrix.com/support/product-lifecycle/workspace-app.html
  #
  # Versions before 25.08 are marked as broken because they require webkitgtk_4_0
  # which has been removed. Only 25.08+ supports webkitgtk_4_1.
  unsupportedVersions = [
    "23.02.0"
    "23.07.0"
    "23.09.0"
    "23.11.0"
    "24.02.0"
    "24.05.0"
    "24.08.0"
    "24.11.0"
    "25.03.0"
    "25.05.0"
  ];
in
{
  inherit supportedVersions unsupportedVersions;
}
