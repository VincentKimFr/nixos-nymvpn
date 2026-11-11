{
  inputs,
  den,
  ...
}: {
  imports = [
    (inputs.den.namespace "nymvpn" true)
  ];
  _module.args.__findFile = den.lib.__findFile;
}
