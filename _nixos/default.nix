{
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    ./options.nix
    ./polkit.nix
    ./daemon.nix
    ./gui.nix
  ];
}
