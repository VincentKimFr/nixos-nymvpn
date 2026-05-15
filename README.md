# nixos-nymvpn

Reusable NymVPN module for NixOS with Polkit, `TunDevice`, and systemd runtime fixes.

Working NymVPN configuration for NixOS / GLF OS.

Tested on:

- GLF OS 25.11 (NixOS-based)
- Linux kernel 6.18.28
- KDE Plasma X11
- NymVPN AppImage 1.29.4
- nym-vpnd 1.29.3

## Scope

This repository documents a working NymVPN setup for recent NymVPN releases on NixOS-like systems.

The issues and fixes described here were observed with NymVPN releases starting from 1.27.0, including:

- NymVPN AppImage 1.29.4
- nym-vpnd 1.29.3

Older releases may behave differently and may not require all fixes documented here.

---

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

---

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

---

## Flatpak client support

This configuration can also be used with the official NymVPN Flatpak client.

In that case:

- keep the `nym-vpnd` service,
- keep the Polkit configuration,
- keep the runtime PATH and capabilities fixes,
- remove the AppImage client package and MIME associations.

However, using the AppImage client keeps GUI and daemon versions synchronized through NixOS configuration, which is generally more reproducible and reliable on NixOS systems.
