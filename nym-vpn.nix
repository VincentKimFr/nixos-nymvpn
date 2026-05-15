{ lib, config, pkgs, ... }:

# Required on NixOS:
# without these tools in the service PATH,
# NymVPN may fail at tunnel setup with:
#
# Error(TunDevice)
#
# even when:
# - /dev/net/tun exists
# - tun kernel module is loaded
# - the daemon runs as root

let
  # Users allowed to access the NymVPN daemon through Polkit.
  # Change this to your local username(s).
  allowedNymVpnUsers = [
    "username"
  ];

  # =========================================================
  # NYM GUI CLIENT — COMMENT THIS WHOLE BLOCK IF USING FLATPAK
  # =========================================================

  nymVpnAppVersion = "1.29.4";

  nym-vpn-app = pkgs.appimageTools.wrapType2 {
    pname = "nym-vpn-app";
    version = nymVpnAppVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/nymtech/nym-vpn-client/releases/download/nym-vpn-app-v${nymVpnAppVersion}/NymVPN_${nymVpnAppVersion}_amd64.AppImage";
      sha256 = "sha256-9JGJZfLtju8PLDj6az0o2U4UYNZ/4hmERHAjx9Ya4+0=";
    };

    extraPkgs = pkgs: with pkgs; [
      xdg-utils
      gtk3
      glib
      webkitgtk_4_1
      libayatana-appindicator
    ];
  };

  nym-vpn-desktop = pkgs.makeDesktopItem {
    name = "nym-vpn";
    desktopName = "NymVPN";
    exec = "${nym-vpn-app}/bin/nym-vpn-app -l %U";
    terminal = false;
    type = "Application";

    categories = [
      "Network"
      "Security"
    ];

    mimeTypes = [
      "x-scheme-handler/nymvpn"
      "x-scheme-handler/nym-vpn"
    ];
  };

  # =========================================================
  # END OF NYM GUI CLIENT BLOCK
  # =========================================================

  nymVpnCoreVersion = "1.29.3";

  nym-vpn-core = pkgs.stdenv.mkDerivation {
    pname = "nym-vpn-core";
    version = nymVpnCoreVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/nymtech/nym-vpn-client/releases/download/nym-vpn-core-v${nymVpnCoreVersion}/nym-vpn-core-v${nymVpnCoreVersion}_linux_x86_64.tar.gz";
      sha256 = "sha256-6A6pLj9VW9uZCOLZs1p+aEIYt0ArGZIhRYTwuyYyrRs=";
    };

    sourceRoot = "nym-vpn-core-v${nymVpnCoreVersion}_linux_x86_64";

    nativeBuildInputs = [
      pkgs.autoPatchelfHook
    ];

    buildInputs = [
      pkgs.stdenv.cc.cc.lib
      pkgs.glibc
      pkgs.openssl
      pkgs.dbus
      pkgs.libmnl
      pkgs.libnftnl
    ];

    installPhase = ''
      mkdir -p $out/bin

      install -m755 nym-vpnd $out/bin/nym-vpnd
      install -m755 nym-vpnc $out/bin/nym-vpnc

      if [ -f nym-exclude ]; then
        install -m755 nym-exclude $out/bin/nym-exclude
      fi
    '';
  };

  nym-vpnd-polkit-policy = pkgs.writeTextFile {
    name = "nym-vpnd-polkit-policy";
    destination = "/share/polkit-1/actions/com.nymvpn.vpnd.policy";

    text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE policyconfig PUBLIC
        "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
        "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">

      <policyconfig>
        <vendor>NymVPN</vendor>
        <vendor_url>https://nym.com</vendor_url>

        <action id="com.nymvpn.vpnd.unix-access">
          <description>Access NymVPN daemon</description>

          <message>
            Authentication is required to access the NymVPN daemon
          </message>

          <defaults>
            <allow_any>auth_admin</allow_any>
            <allow_inactive>auth_admin</allow_inactive>
            <allow_active>auth_self</allow_active>
          </defaults>
        </action>
      </policyconfig>
    '';
  };
in
{
  # =========================================================
  # PACKAGES
  # =========================================================

  environment.systemPackages = [
    nym-vpn-core
    nym-vpnd-polkit-policy

    pkgs.kdePackages.polkit-kde-agent-1
    pkgs.xdg-utils

    # =====================================================
    # COMMENT THESE 2 LINES IF USING THE FLATPAK GUI CLIENT
    # =====================================================

    nym-vpn-app
    nym-vpn-desktop
  ];

  # =========================================================
  # POLKIT
  # =========================================================

  security.polkit = {
    enable = true;

    extraConfig = ''
      polkit.addRule(function(action, subject) {
        var allowedUsers = ${builtins.toJSON allowedNymVpnUsers};

        if (action.id == "com.nymvpn.vpnd.unix-access" &&
            allowedUsers.indexOf(subject.user) >= 0) {
          return polkit.Result.YES;
        }
      });
    '';
  };

  systemd.user.services.polkit-kde-agent = {
    description = "KDE Polkit authentication agent";

    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];

    serviceConfig = {
      Type = "simple";

      ExecStart =
        "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";

      Restart = "on-failure";
    };
  };

  # =========================================================
  # NYM DAEMON
  # =========================================================

  systemd.services.nym-vpnd = {
    description = "nym-vpnd daemon";

    wantedBy = [ "multi-user.target" ];
    before = [ "network-online.target" ];

    after = [
      "NetworkManager.service"
      "systemd-resolved.service"
    ];

    # Required on NixOS:
    # upstream expects these networking tools in PATH.
    # Without this block, this setup reproduced:
    #
    # Error(TunDevice)

    path = [
      pkgs.iproute2
      pkgs.iptables
      pkgs.nftables
      pkgs.coreutils
    ];

    startLimitBurst = 6;
    startLimitIntervalSec = 24;

    serviceConfig = {
      ExecStart =
        "${nym-vpn-core}/bin/nym-vpnd -v run-as-service";

      Restart = "always";
      RestartSec = 2;

      # Required for tunnel creation.

      AmbientCapabilities = [
        "CAP_NET_ADMIN"
        "CAP_NET_RAW"
        "CAP_NET_BIND_SERVICE"
      ];

      CapabilityBoundingSet = [
        "CAP_NET_ADMIN"
        "CAP_NET_RAW"
        "CAP_NET_BIND_SERVICE"
      ];

      NoNewPrivileges = false;
      PrivateNetwork = false;
    };
  };

  # =========================================================
  # MIME ASSOCIATIONS — COMMENT THIS BLOCK IF USING FLATPAK
  # =========================================================
  #
  # Needed only for the AppImage GUI client and browser/deep-link callbacks.
  # The Flatpak client should provide its own .desktop file and URI handlers.

  xdg.mime.enable = true;

  xdg.mime.defaultApplications = {
    "x-scheme-handler/nymvpn" = "nym-vpn.desktop";
    "x-scheme-handler/nym-vpn" = "nym-vpn.desktop";
  };

  # =========================================================
  # END OF MIME ASSOCIATIONS BLOCK
  # =========================================================
}
