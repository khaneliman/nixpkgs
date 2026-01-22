{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.citrix-workspace;
in
{
  meta.maintainers = with lib.maintainers; [ khaneliman ];

  options.programs.citrix-workspace = {
    enable = lib.mkEnableOption "Citrix Workspace App, a remote desktop client for Citrix Virtual Apps and Desktops";

    package = lib.mkPackageOption pkgs "Citrix Workspace" {
      default = [ "citrix_workspace" ];
    };

    usbSupport = {
      enable = lib.mkEnableOption "USB redirection support for Citrix Workspace" // {
        default = true;
      };

      usbRules = lib.mkOption {
        type = lib.types.lines;
        default = "";
        example = ''
          CONNECT: vid=1234 pid=5678  # My custom device
          DENY: class=08  # Mass storage
        '';
        description = ''
          Additional USB redirection rules to append to the default usb.conf.

          See the Citrix documentation for the rule syntax:
          - CONNECT: rules specify devices to redirect
          - DENY: rules specify devices to block from redirection

          Common class codes:
          - class=01: Audio
          - class=03: HID (keyboards, mice)
          - class=08: Mass Storage
          - class=09: Hub
          - class=0b: Smart Card
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # Install udev rules for USB redirection and HID/multitouch support
    services.udev.packages = lib.mkIf cfg.usbSupport.enable [ cfg.package ];

    # Create user-customizable USB config if additional rules are specified
    environment.etc = lib.mkIf (cfg.usbSupport.enable && cfg.usbSupport.usbRules != "") {
      "citrix/usb.conf".text = ''
        # User-defined USB redirection rules for Citrix Workspace
        # These rules are appended to the default rules from the package
        ${cfg.usbSupport.usbRules}
      '';
    };

    # ctxusbd service for USB redirection
    systemd.services.ctxusbd = lib.mkIf cfg.usbSupport.enable {
      description = "Citrix USB Redirection Service";
      documentation = [ "https://docs.citrix.com/en-us/citrix-workspace-app-for-linux" ];

      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "forking";
        ExecStart = "${cfg.package.passthru.icaroot}/ctxusbd";
        Restart = "on-failure";
        RestartSec = 5;

        # Required capabilities for USB device manipulation
        AmbientCapabilities = [
          "CAP_NET_ADMIN"
          "CAP_SYS_ADMIN"
        ];
        CapabilityBoundingSet = [
          "CAP_NET_ADMIN"
          "CAP_SYS_ADMIN"
        ];

        # Security hardening
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = false; # Required for USB operations

        # USB device access
        DeviceAllow = [
          "/dev/bus/usb/* rw"
          "char-usb_device rw"
        ];

        # Runtime directory for PID file
        RuntimeDirectory = "ctxusbd";
        PIDFile = "/run/ctxusbd/ctxusbd.pid";
      };
    };
  };
}
