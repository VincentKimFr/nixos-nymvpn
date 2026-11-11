{inputs, ...}: {
  flake = {lib, ...}: rec {
    flakeModule = flakeModules.default;
    flakeModules.default = {...}: {
      imports =
        builtins.filter (
          p: lib.hasSuffix ".nix" p && !lib.hasInfix "/_" p
        ) (
          lib.filesystem.listFilesRecursive ../modules
        );
    };
    # flakeModules.default = inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ../modules);
  };
}
