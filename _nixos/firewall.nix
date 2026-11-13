# Firewall
{
  config,
  pkgs,
  lib,
  ...
}: let
  moduleName = "nymvpn";
in
  with lib; {
    # FIX:
    # ERROR nym_wg_go::wireguard_go: sendmmsg: operation not permitted
    networking.nftables.enable = true;

    # Mandatory port list taken from `nft list ruleset` and table `nym`
    networking.firewall = {
      checkReversePath = "loose";
      # enable = mkForce false;
      enable = true;
      allowedTCPPorts = [
        # dns-over-tls
        8153

        # wireguard
        51820
        # AmneziaWG
        51822

        # systemd-resolved
        5355
        53

        9000
        9001
      ];
      # Nym AmneziaWG (wireguar)
      allowedUDPPorts = [
        # dns
        547
        546
        67
        68

        # dns-over-tls
        8153

        # wireguard
        51820
        # AmneziaWG
        51822

        # systemd-resolved
        5355
        53
      ];
      allowedTCPPortRanges = [
        {
          from = 30000;
          to = 61000;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 30000;
          to = 61000;
        }
      ];
    };
    networking.nftables.tables."nixos-fw".content = ''
    '';
  }
