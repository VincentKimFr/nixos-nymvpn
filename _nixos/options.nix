{lib, ...}:
with lib; let
  moduleName = "nymvpn";
in {
  options.services.${moduleName} = {
    enable = mkEnableOption "Enable ${moduleName}.";
    logLevel = mkOption {
      default = "debug";
      type = types.enum ["error" "warn" "info" "debug" "trace"];
    };
    users = mkOption {
      type = types.listOf types.str;
      example = ''
        ["john" "jane"]";
      '';
      description = "List of users for whom to allow nym vpn usage (polkit).";
    };
    account.secret.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = "Enable sops account secret management.";
    };
    autoconnect.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = "Connect as soon as possible.";
    };
    core = {
      version = mkOption {
        type = types.str;
        default = "2026.15.0";
        example = "2026.15.0";
      };
      sha256 = mkOption {
        type = types.str;
        default = "sha256-SkbS2fs9ytC8r3PvHrw7/PDyjq1M1TAEsM7QuMTgD80=";
      };
    };
    gui = {
      enable = mkEnableOption "Enable the graphical user interface.";
      version = mkOption {
        type = types.str;
        default = "2026.15.0";
        example = "2026.15.0";
      };
      sha256 = mkOption {
        type = types.str;
        default = "sha256-hZ7H+LVI5jzNuhTRH3HWS5aky8RVLyeUAtpB+gmmVDw=";
      };
    };
  };
}
