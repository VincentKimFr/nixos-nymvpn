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
      # NymVPN may fail at tunnel setup with: Error(TunDevice)
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
  # Sops
  imports = [
    (import ./sops.nix {
      inherit lib;
      inherit config;
      inherit options;
      inherit pkgs;
      inherit nym-vpn-core;
    })
  ];

  environment.systemPackages = [
    nym-vpn-core
    # pkgs.xdg-utils
    # pkgs.iproute2
    # pkgs.iptables
    # pkgs.nftables
    # pkgs.coreutils
  ];

  # Force static content inside /etc/resolv.conf
  # to override nixpkgs systemd-resolved configuration.
  environment.etc."resolv.conf.default".text = mkDefault (
    concatMapStrings
    (x: "nameserver ${x}\n")
    config.networking.nameservers
    + "options edns0 trust-ad"
  );

  ### Firewall/ Blacklisting error
  services.resolved = {
    enable = true;
    settings = {
      Resolve.DNSSEC = false;
      # Resolve.DNSSEC = "allow-downgrade";
      Resolve.DNSOverTLS = "opportunistic";
    };
  };

  # NYM DAEMON
  systemd.services.nym-vpnd = {
    description = "nym-vpnd daemon";

    after = [
      # Dns
      "systemd-resolved.service"
      "unbound.service"

      "NetworkManager.service"
    ];
    before = ["network-online.target"];

    wantedBy = [
      "multi-user.target"
      "NetworkManager.service"
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
    path =
      [
        pkgs.iproute2
        pkgs.coreutils
      ]
      ++ (
        if config.networking.nftables.enable
        then [pkgs.nftables]
        else pkgs.iptables
      );

    startLimitBurst = 6;
    startLimitIntervalSec = 24;

    serviceConfig = let
      verbosity =
        {
          "error" = "";
          "warn" = "";
          "info" = "";
          "debug" = "-v";
          "trace" = "-vv";
        }.${
          config.services.${moduleName}.logLevel
        };
    in {
      # Type = "forking";
      Type = "exec";

      # ExecStart = "${nym-vpn-core}/bin/nym-vpnd -v run-as-service";
      ExecStart = "${nym-vpn-core}/bin/nym-vpnd ${verbosity} run-with-args";

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
