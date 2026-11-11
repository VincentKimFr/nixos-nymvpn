{inputs, ...}: {
  flake = {lib, ...}: rec {
    flakeModule = flakeModules.default;
    flakeModules.default = inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ../modules);
  };
}
