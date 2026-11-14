{...}: {
  imports = [
    ./options.nix
    ./polkit.nix

    ./firewall.nix
    ./dns.nix

    ./daemon.nix

    ./gui.nix
  ];
}
