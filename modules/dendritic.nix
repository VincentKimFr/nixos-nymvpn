{self, ...}: {
  flake-file.inputs = {
    # den.url = "github:denful/den";
  };

  nymvpn.aspects = rec {
    default = nymvpn;
    nymvpn = {
      nixos = {
        config,
        user,
        ...
      }: {
        imports = [
          self.nixosModules.nymvpn
        ];
        config.services.nymvpn.users = [user.userName];
      };
    };
  };
}
