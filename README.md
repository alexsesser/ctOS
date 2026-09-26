![ctOS](.assets/Logo.png)

A linux rice inspired by the ctOS (Central Operating System) from the Watch Dogs universe ([Disclaimer](#legal)).

> Fork of [TSM-061/ctOS](https://github.com/TSM-061/ctOS) adapted for **Arch Linux with KDE Plasma**.

<br>

## Changes from upstream

- **Editable username field** — username can be changed at the login screen; changing it recreates the greetd session, an empty `user` in the config is allowed
- **Session selector** — `‹ SESSION ›` below the password field lists Wayland sessions from `/usr/share/wayland-sessions` and shells from `/etc/shells`; `←`/`→` or mouse to switch, the session matching `modes.greetd.launch` is preselected
- **Keyboard navigation** — Tab / Shift+Tab cycles password → username → session → LOGIN, Enter logs in from any of them
- **Power keys** — `F1` shutdown, `F2` reboot on the login screen only (press twice to confirm)
- **Lock screen** — in `lockd` mode the username is fixed to the session owner
- **Real device data** — NODE shows the public IPv4 address with leading zeros (`031.076.099.236`), requested from api.ipify.org / icanhazip.com / ifconfig.me (with a VPN it's the VPN exit address); offline it shows the last known address (dimmed, stored in `/var/lib/ctos`) or a random one. `HOST:` shows the hostname. The label next to the barcode encodes the device: `ARCH-<cores>C-<RAM>G-K<kernel>|<hash>`, where the hash is 128 bits of SHA-256 over machine-id, board, CPU model and MAC addresses of physical network interfaces
- **Custom cursor blinking** — cursor stops blinking when a field loses focus
- **Username field overflow** — long usernames scroll left instead of expanding the layout
- **KDE compositor** — uses `kwin_wayland` instead of Hyprland/Niri
- **Session launch** — `startplasma-wayland` instead of `uwsm`
- **install.sh** — installs dependencies from the official repos, auto-detects the primary monitor via `kscreen-doctor`, keeps all existing settings on reinstall (merging in new defaults), mirrors app files to `/opt/ctos`

<br>

## Requirements

- `kwin_wayland`
- `quickshell`
- `greetd`
- `JetBrainsMono Nerd Font`
- `python3`
- `rsync`

<br>

## Installation

```bash
git clone https://github.com/alexsesser/ctOS.git
cd ctOS
./install.sh
```

Run it as your normal user (it calls `sudo` itself). On first run the installer asks for your username and primary monitor. On subsequent runs it keeps your existing settings in `/etc/ctos/greeter.config.json`, adds missing defaults and mirrors the app files to `/opt/ctos` (files removed from the repo are removed there too).

### greetd configuration

`/etc/greetd/config.toml`:

```toml
[terminal]
vt = 1

[default_session]
command = "/etc/ctos/greeter.kwin.conf"
user = "greeter"
```

<br>

## Testing without reboot

```bash
CTOS_DEBUG=1 CTOS_MODE=test quickshell --path greeter.qml
```

- Default password: `password`
- Exit: `Esc`, simulate successful login: `F12`
- `F1`/`F2` are disabled in test mode

<br>

## Legal

This project is a non-commercial, fan-made tribute. The **ctOS** name, branding, and logos are trademarks and/or copyrights of **Ubisoft Entertainment**.

- This software is not affiliated with, endorsed by, or supported by Ubisoft.
- All visual assets inspired by the _Watch Dogs_ universe are used strictly for aesthetic and creative purposes.
