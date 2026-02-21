![ctOS](.assets/Logo.png)

A linux rice inspired by the ctOS (Central Operating System) from the Watch Dogs universe ([Disclaimer](#legal)).

> Fork of [TSM-061/ctOS](https://github.com/TSM-061/ctOS) adapted for **Arch Linux with KDE Plasma**.

<br>

## Changes from upstream

- **Editable username field** — username can be changed at the login screen, Tab switches focus to the password field
- **Custom cursor blinking** — cursor stops blinking when a field loses focus
- **Username field overflow** — long usernames scroll left instead of expanding the layout
- **KDE compositor** — uses `kwin_wayland` instead of Hyprland/Niri
- **Session launch** — `startplasma-wayland` instead of `uwsm`
- **install.sh** — auto-detects monitor via `kscreen-doctor`, preserves `user` and `monitor` on reinstall, always overwrites app files

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
cd themes/ctOS
./install.sh
```

On first run the installer will ask for your username and primary monitor. On subsequent runs it preserves your existing settings and overwrites all app files in `/opt/ctos`.

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
- Exit: `Esc`

<br>

## Legal

This project is a non-commercial, fan-made tribute. The **ctOS** name, branding, and logos are trademarks and/or copyrights of **Ubisoft Entertainment**.

- This software is not affiliated with, endorsed by, or supported by Ubisoft.
- All visual assets inspired by the _Watch Dogs_ universe are used strictly for aesthetic and creative purposes.
