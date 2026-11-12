{...}: {
  imports = [
    ./options.nix
    ./polkit.nix

    ./firewall.nix

    ./daemon.nix

    ./gui.nix
  ];
}
