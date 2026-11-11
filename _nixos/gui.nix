# =========================================================
# NYM GUI CLIENT — COMMENT THIS WHOLE BLOCK IF USING FLATPAK
# =========================================================
{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  moduleName = "nymvpn";

  nym-vpn-app = let
    nymVpnAppVersion = config.services.${moduleName}.gui.version;
    sha256 = config.services.${moduleName}.gui.sha256;
    system = "amd64";
  in
    pkgs.appimageTools.wrapType2 {
      pname = "nym-vpn-app";
      version = nymVpnAppVersion;

      src = pkgs.fetchurl {
        url = "https://github.com/nymtech/nym-vpn-client/releases/download/nym-vpn-v${nymVpnAppVersion}/NymVPN_${nymVpnAppVersion}_${system}.AppImage";
        inherit sha256;
      };

      extraPkgs = pkgs:
        with pkgs; [
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
in {
  config = mkMerge [
    (mkIf (config.services.${moduleName}.gui.enable == true)
      {
        environment.systemPackages = [
          nym-vpn-app
          nym-vpn-desktop
        ];
        # Needed only for the AppImage GUI client and browser/deep-link callbacks.
        # The Flatpak client should provide its own .desktop file and URI handlers.
        xdg.mime.enable = true;
        xdg.mime.defaultApplications = {
          "x-scheme-handler/nymvpn" = "nym-vpn.desktop";
          "x-scheme-handler/nym-vpn" = "nym-vpn.desktop";
        };
      })
  ];
}
