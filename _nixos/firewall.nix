# Firewall
{
  config,
  pkgs,
  ...
}: let
  moduleName = "nymvpn";
in {
  networking.nftables.enable = true;
  networking.firewall = {
    # Nym AmneziaWG (wireguar)
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
}
