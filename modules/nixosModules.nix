{...}: {
  flake = {
    nixosModules = rec {
      default = nymvpn;
      nymvpn = ./_nixos/default.nix;
    };
  };
}
