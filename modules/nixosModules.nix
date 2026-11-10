{...}: {
  flake = {
    nixosModules = rec {
      default = nymvpn;
      nymvpn = ./default.nix;
    };
  };
}
