{...}: {
  imports = [
    ./options.nix
    ./polkit.nix

    ./firewall.nix
    ./dns.nix

    ./daemon

    ./gui.nix
  ];
}
