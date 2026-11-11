# nymvpn.nixos

[NymVPN](https://github.com/nymtech/nym-vpn-client)
module/flake for NixOS with Polkit, `TunDevice`, and systemd runtime fixes.

## Scope

This repository documents a working NymVPN setup for recent NymVPN releases on NixOS-like systems.

The issues and fixes described here were observed with NymVPN releases starting from 1.27.0, including:

- NymVPN AppImage 1.29.4
- nym-vpnd 1.29.3

Older releases may behave differently and may not require all fixes documented here.

## Install

### With flake

Add the repo url to your configuration(flake) input.

```nix
#flake.nix
inputs = {
  nymvpn.url = "github:crocuda/nixos-nymvpn";
}
```

Import and configure the nixos module.

```nix
# random config file
{
config,
user,
...
}: {
  imports = [
    inputs.nymvpn.nixosModules.nymvpn
  ];
  config.services.nymvpn.users = [ <your_username> ];
}
```

You may find the full list of options at `_nixos/options.nix`

For example, you can set your favorite version for the core and the gui.

```nix
# random config file
{
config,
user,
...
}: {
  imports = [
    inputs.nymvpn.nixosModules.nymvpn
  ];
  config.services.nymvpn = {
    enable = true;
    users = [ <your_username> ];
    # Pin a core version.
    core = {
        version = "2026.15.0";
        sha256 = "sha256-SkbS2fs9ytC8r3PvHrw7/PDyjq1M1TAEsM7QuMTgD80=";
    };
    # Pin a gui version.
    gui = {
        enable = true;
        version = "2026.15.0";
        sha256 = "sha256-SkbS2fs9ytC8r3PvHrw7/PDyjq1M1TAEsM7QuMTgD80=";
    };
  };
}
```

### With flake + Flatpak client support

This module can also be used with the official NymVPN Flatpak client.

In that case:

- Disable the GUI installation via nix.

```nix
config.services.nymvpn.gui.enable = false;
```

This option will:

- keep the `nym-vpnd` service,
- keep the Polkit configuration,
- keep the runtime PATH and capabilities fixes,
- and remove the AppImage client package and MIME associations.

However, using the AppImage client keeps GUI and daemon versions synchronized through NixOS configuration, which is generally more reproducible and reliable on NixOS systems.

### With denful flake (dendritic)

Add the repo url to your configuration(flake) input.

```nix
#flake.nix
inputs = {
  nymvpn.url = "github:crocuda/nixos-nymvpn";
}
```

The user will be automatically detected from your configuration.
No need to set further configuration.

```nix
# random config file
imports = [
  inputs.nymvpn.flakeModules.default
];
den.aspects.<my_aspect> = {
  includes = [
    nymvpn.aspects.nymvpn
  ];
};
```

## Usage

### Auto-connect (with sops)

```nix
#flake.nix
inputs = {
  nymvpn.url = "github:crocuda/nixos-nymvpn";
}
```

Add your nym account secret key to your secret file.

```sh
sops edit secrets/secrets.yaml
```

```yaml
nym-vpn:
  secret: |
    your 24 word secret seed
```

Enable secret management in your config.

```nix
config.services.nymvpn.account.secret.enable = true;

```

## Problems

Two separate issues may occur on NixOS.

### 1. Authentication / daemon access failure

The GUI may fail to communicate correctly with `nym-vpnd` because NixOS does not automatically provide the expected Polkit integration for this setup.

This requires:

- a Polkit policy,
- a Polkit authentication agent,
- explicit NixOS configuration.

### 2. Tunnel creation failure

NymVPN may fail with:

```text
Error(TunDevice)
```

even when:

- `/dev/net/tun` exists,
- the `tun` kernel module is loaded,
- the daemon runs as root.

---

## Cause

On NixOS, systemd services run in an isolated environment and do not expose the standard runtime PATH commonly expected by upstream Linux binaries.

With NymVPN releases starting from 1.27.0, `nym-vpnd` expects networking tools such as:

- `iproute2`
- `iptables`
- `nftables`

to be available in the service runtime environment.

The daemon also requires explicit network capabilities for tunnel creation.

## Required fixes

### Capabilities

```nix
serviceConfig = {
  AmbientCapabilities = [
    "CAP_NET_ADMIN"
    "CAP_NET_RAW"
    "CAP_NET_BIND_SERVICE"
  ];

  CapabilityBoundingSet = [
    "CAP_NET_ADMIN"
    "CAP_NET_RAW"
    "CAP_NET_BIND_SERVICE"
  ];
};
```

### Runtime PATH

```nix
path = [
  pkgs.iproute2
  pkgs.iptables
  pkgs.nftables
  pkgs.coreutils
];
```

### Polkit

A Polkit rule and authentication agent are also required.
