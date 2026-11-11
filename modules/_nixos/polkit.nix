# =========================================================
# POLKIT
# =========================================================
{
  lib,
  config,
  pkgs,
  ...
}: let
  moduleName = "nymvpn";

  # Users allowed to access the NymVPN daemon through Polkit.
  # Change this to your local username(s).
  allowedNymVpnUsers = config.services.${moduleName}.users;
in {
  security.polkit = {
    enable = true;

    extraConfig = ''
      polkit.addRule(function(action, subject) {
        var allowedUsers = ${builtins.toJSON allowedNymVpnUsers};
        if (action.id == "com.nymvpn.vpnd.unix-access" &&
            allowedUsers.indexOf(subject.user) >= 0) {
          return polkit.Result.YES;
        }
      });
    '';
  };

  systemd.user.services.polkit-kde-agent = {
    description = "KDE Polkit authentication agent";

    wantedBy = ["graphical-session.target"];
    partOf = ["graphical-session.target"];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
    };
  };

  environment.systemPackages = let
    nym-vpnd-polkit-policy = pkgs.writeTextFile {
      name = "nym-vpnd-polkit-policy";
      destination = "/share/polkit-1/actions/com.nymvpn.vpnd.policy";

      text = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE policyconfig PUBLIC
          "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
          "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">

        <policyconfig>
          <vendor>NymVPN</vendor>
          <vendor_url>https://nym.com</vendor_url>

          <action id="com.nymvpn.vpnd.unix-access">
            <description>Access NymVPN daemon</description>

            <message>
              Authentication is required to access the NymVPN daemon
            </message>

            <defaults>
              <allow_any>auth_admin</allow_any>
              <allow_inactive>auth_admin</allow_inactive>
              <allow_active>auth_self</allow_active>
            </defaults>
          </action>
        </policyconfig>
      '';
    };
  in [
    nym-vpnd-polkit-policy
    pkgs.kdePackages.polkit-kde-agent-1
  ];
}
