{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  moduleName = "nymvpn";

  nym-vpn-core = let
    nymVpnCoreVersion = config.services.${moduleName}.core.version;
    sha256 = config.services.${moduleName}.core.sha256;
    # system = pkgs.stdenv.hostPlatform.system;
    system = "x86_64";
  in
    pkgs.stdenv.mkDerivation {
      pname = "nym-vpn-core";
      version = nymVpnCoreVersion;
      src = pkgs.fetchurl {
        url = "https://github.com/nymtech/nym-vpn-client/releases/download/nym-vpn-v${nymVpnCoreVersion}/nym-vpn-core-v${nymVpnCoreVersion}_linux_${system}.tar.gz";
        inherit sha256;
      };

      sourceRoot = "nym-vpn-core-v${nymVpnCoreVersion}_linux_x86_64";

      nativeBuildInputs = [
        pkgs.autoPatchelfHook
      ];

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
in {
  environment.systemPackages = [
    nym-vpn-core
    # pkgs.xdg-utils
  ];

  # NYM DAEMON
  systemd.services.nym-vpnd = {
    description = "nym-vpnd daemon";

    wantedBy = ["multi-user.target"];
    before = ["network-online.target"];

    after = [
      "NetworkManager.service"
      "systemd-resolved.service"
    ];

    # Starting nym-vpnd.service stops the local dns resolver if one is already running on port 53.
    # Invertly starting the local resolver "nsd.service" or "unbound.service" will stop "nym-vpnd.service"
    conflicts = with lib;
      mkMerge [
        (mkIf (config.services.nsd.port == 53) ["nsd.service"])
        (mkIf (
            (config.services.unbound.enable == true)
            || (config.services.unbound.settings.server.port == "53")
          )
          ["unbound.service"])
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
      ExecStart = "${nym-vpn-core}/bin/nym-vpnd -v run-as-service";

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
}
