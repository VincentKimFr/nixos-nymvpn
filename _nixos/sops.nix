{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: {
  ## Secrets management
  sops.secrets."nym-vpn".secret = {
    owner = "root";
    group = "root";
    mode = "0440";
    path = "/var/lib/nym-vpn/secret";
  };

  # Auto-connect.
  # Only on nixos generation rebuild and if sops is enabled.
  #
  # Reads the secret, connect to nym account, then delete the secret.
  systemd.services.nym-vpnd.serviceConfig.ExecStartPost = with lib;
    mkMerge [
      (mkIf (
          (account.secret != null)
          && (builtins.hasAttr "sops" options)
        )
        # Connect to account
        ''
          ${nym-vpn-core}/bin/nym-vpnc account set < $(cat ${config.sops.secrets."nym-vpn".secret.path})
        ''
        # Delete secret
        + ''
          rm -rf ${config.sops.secrets."nym-vpn".secret.path}
        '')
    ];
}
