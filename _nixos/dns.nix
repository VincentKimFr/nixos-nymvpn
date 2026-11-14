# Fix dns issues.
{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  moduleName = "nymvpn";
in {
  ## Create a default resolv.conf containing user defined nameservers if any.
  # The file is used later bellow inside the service definition to force static content inside /etc/resolv.conf and bring back old
  # behavior when systemd-resolved stops.
  environment.etc."resolv.conf.d/resolv.conf.nymdefault".text = mkDefault (
    concatMapStrings
    (x: "nameserver ${x}\n")
    config.networking.nameservers
    + "options edns0 trust-ad"
  );

  ## Add some tweaks to the default service.
  systemd.services.systemd-resolved = {
    # overrideStrategy = "asDropin";
    after = [
      "unbound.service"
    ];
    # Stops the service when nym-vpnd stops.
    # bindTo = mkDefault ["nym-vpnd.service"];
    # partOf = mkDefault ["nym-vpnd.service"];

    # Stop if unbound is running, thus stopping the nym-vpnd daemon.
    conflicts = with lib;
      mkMerge [
        (mkIf ((config.services.unbound.enable == true)
            && (config.services.nsd.port == 53)) ["nsd.service"])
        (mkIf
          ((config.services.unbound.enable == true)
            || (config.services.unbound.settings.server.port == "53"))
          ["unbound.service"])
        ["resolvconf.service"]
      ];

    serviceConfig = {
      # On start.
      # Recreate a compatible /etc/resolv.conf that points to this service.
      ExecStartPre = let
        name = "systemd-resolved-start-script";
        config = "/run/systemd/reslove/stub/stub-resolv.conf";
        text = ''
          set -x
          set +e
          if [ -f "${config}" ]; then
            ${pkgs.coreutils}/bin/ln -s ${config} /etc/resolv.conf
          fi
          exit 0
        '';
        script = pkgs.writeShellScriptBin name text;
      in "${script}/bin/${name}";
      # On stop.
      # Recreate a default /etc/resolv.conf usable as is and unbound.
      ExecStopPost = let
        name = "nym-vpnd-stop-script";
        text = ''
          set -x
          set +e
          if [ -f "/etc/resolv.conf.d/reslov.conf.nymdefault" ]; then
            ${pkgs.coreutils}/bin/ln -s /etc/resolv.conf.d/resolv.conf.nymdefault /etc/resolv.conf
          elif [ -f "/etc/resolv.conf.nymbackup" ]; then
            ${pkgs.coreutils}/bin/ln -s /etc/resolv.conf.nymbackup /etc/resolv.conf
          fi
          exit 0
        '';
        script = pkgs.writeShellScriptBin name text;
      in "${script}/bin/${name}";
    };
  };

  ## FIX Nym: no existing dns manager error.
  # Nym can't run alongside the "unbound" dns resolver.
  # Compatible resolvers are:
  # - /etc/resolv.conf
  # - systemd-resolved
  # - reslvconf
  # - NetworkManager
  # Here we arbitrarily chose to use systemd-resolved.
  services.resolved = {
    enable = true;
    settings = {
      Resolve.DNSSEC = false;
      # Resolve.DNSSEC = "allow-downgrade";
      Resolve.DNSOverTLS = "opportunistic";
    };
  };

  # Restarts unbound when nym-vpnd / systemd-resolved service is down.
  systemd.services.unbound = {
    before = ["systemd-resolved.service"];
    conflicts = [
      "systemd-resolved.service"
    ];
  };
}
