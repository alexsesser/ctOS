![ctOS](.assets/Logo.png)

A login screen (greetd) and lock screen for Linux inspired by ctOS, the Central Operating System from the Watch Dogs universe ([Disclaimer](#legal)). Built with [Quickshell](https://quickshell.org/) / QML.

> **This is a fork of [TSM-061/ctOS](https://github.com/TSM-061/ctOS)** that makes the greeter a first-class login screen for **Arch Linux + KDE Plasma**.
> All credit for the design and the original implementation goes to the upstream author.

[Demo video (upstream)](.assets/ctos-greeter.mp4)

<br>

## Why this fork

Upstream ctOS targets tiling Wayland compositors: the greeter runs inside Hyprland or Niri (or `cage`) and starts the desktop through `uwsm`. On a KDE Plasma machine that means installing and configuring a second compositor just for the login screen, and you still log into one hard-coded user and session.

This fork is for people who use Plasma and simply want the ctOS look instead of SDDM:

- **The greeter runs inside `kwin_wayland`** — the compositor you already have. No Hyprland, Niri, cage or uwsm required.
- **It behaves like a real display manager** — pick the user, pick the session (Plasma, GNOME, any Wayland session or a plain shell), shut down or reboot from the login screen.
- **One command to install and update** — `install.sh` handles packages, config, the kwin launch script and the app files, and can be re-run safely.
- **Hardened authentication flow** — the lock screen always checks the owner of the locked session, the greetd session always matches the username on screen (see below).
- **Real data instead of placeholders** in the HUD: public IP, hostname and a device fingerprint.

<br>

## What's different from upstream

| | Upstream | This fork |
|---|---|---|
| Host compositor | Hyprland / Niri / cage | `kwin_wayland` (KDE) |
| Starting the desktop | `launch` command from the config, usually via `uwsm`; newer upstream: `chdesk` terminal command | session selector in the UI: `/usr/share/wayland-sessions/*.desktop` + shells from `/etc/shells` |
| User | from the config; newer upstream: `chusr` terminal command | editable field on the login screen; config `user` is only the default (may be empty) |
| Power | — | `F1` shutdown, `F2` reboot, press twice to confirm |
| Keyboard / mouse | password field only | Tab / Shift+Tab through password → username → session → LOGIN, Enter logs in from any of them, clickable LOGIN and session arrows |
| Status panel (top right) | fake `NODE` value from the config | real public IPv4 with leading zeros (`031.076.099.236`) + `HOST: <hostname>` |
| Label next to the barcode | fixed text | generated from the device: `ARCH-<cores>C-<RAM>G-K<kernel>\|<device hash>` |
| Installer | Hyprland/Niri/cage setup | Arch + KDE: official-repo packages, monitor auto-detection, config merge on update, `rsync --delete` |

### Authentication details

- **Lock screen (`lockd`) always authenticates the session owner.** Upstream checks the user from the config rather than the owner of the locked session. Here PAM uses the current user, the username is read-only and the session selector is hidden, so a session can't be unlocked with another local user's password.
- **Changing the username recreates the greetd session** (with the required delay between cancel and create), so the password always goes to the user shown on screen. An empty default user works too.
- **All sessions are listed** — session files are parsed in one pass (only `[Desktop Entry]`, `Hidden`/`NoDisplay` entries skipped, `Exec` values containing `=` kept). X11 sessions are not offered because greetd starts them without an X server.
- **No `pkill` on login** — `Greetd.launch()` quits Quickshell after greetd has accepted the session and kwin exits with it (`--exit-with-session`), instead of killing processes while the session is starting.

### Screen layout

- **Center** — username, password, session selector `‹ PLASMA (WAYLAND) ›`, LOGIN.
- **Top right** — battery (or `fakeStatus.env` on desktops), `NODE`: public IP, `HOST:` hostname.
  - The IP is requested from api.ipify.org, icanhazip.com or ifconfig.me (first that answers). With a VPN active this is the VPN exit address.
  - Offline, the last known address is shown dimmed (stored in `/var/lib/ctos/state.json`); if there is none yet, a random one.
- **Right edge** — barcode with the device label. The hash part is the first 128 bits of SHA-256 over machine-id, board, CPU model and MAC addresses of physical network interfaces: stable for the machine, without exposing the raw identifiers.
- **Bottom left** — the fake terminal log and the `[F1] Shutdown • [F2] Reboot` hint.

<br>

## Requirements

- Arch Linux (or derivative) with KDE Plasma 6 on Wayland
- `greetd`, `kwin`, `quickshell` (0.3+), `ttf-jetbrains-mono-nerd`, `python`, `rsync`, `curl` — the installer installs whatever is missing from the official repositories

<br>

## Installation

```bash
git clone https://github.com/alexsesser/ctOS.git
cd ctOS
./install.sh
```

Run it as your normal user from inside your Plasma session (it calls `sudo` itself and uses `kscreen-doctor` to find the primary monitor). On the first run it asks for the default user and the monitor.

What it does:

| Path | Contents |
|---|---|
| `/opt/ctos` | the app, mirrored from the repo (`rsync --delete`) |
| `/etc/ctos/greeter.config.json` | configuration; on re-runs your values are kept and new defaults merged in |
| `/etc/ctos/greeter.kwin.conf` | shell script greetd runs: starts `kwin_wayland` with the greeter |
| `/var/lib/ctos` | writable state for the `greeter` user (last known IP) |

Then point greetd at the launch script in `/etc/greetd/config.toml` (the installer warns if it isn't):

```toml
[terminal]
vt = 1

[default_session]
command = "/etc/ctos/greeter.kwin.conf"
user = "greeter"
```

Disable SDDM if it's enabled and enable greetd:

```bash
sudo systemctl disable sddm
sudo systemctl enable greetd
```

**Updating:** `git pull && ./install.sh`.

> **Before the first reboot** make sure you can log in on a text console (`Ctrl+Alt+F2`). If the greeter doesn't come up, log in there and switch `/etc/greetd/config.toml` back to e.g. `command = "agreety --cmd startplasma-wayland"`, or re-enable SDDM.

<br>

## Configuration

`/etc/ctos/greeter.config.json` (schema: [`schema/greeter.schema.json`](schema/greeter.schema.json), example: [`greeter/examples/greeter.config.json`](greeter/examples/greeter.config.json)):

| Key | Default | Meaning |
|---|---|---|
| `user` | `""` | username pre-filled on the login screen; empty = type it |
| `monitor` | first screen | output that shows the login form, e.g. `eDP-1` (`kscreen-doctor -o`) |
| `fontFamily` | `JetBrainsMono Nerd Font` | monospace font |
| `fakeStatus.env` | `Workstation` | shown instead of battery on machines without one |
| `modes.greetd.launch` | `["startplasma-wayland"]` | preselects the session whose `Exec` contains this command |
| `modes.greetd.exit` | none | optional command run after the session is launched; normally not needed |
| `modes.<mode>.animations` | `all` | `all` or `reduced` (no splash); any root key can be overridden per mode |

<br>

## Testing without logging out

```bash
CTOS_DEBUG=1 CTOS_MODE=test quickshell --path greeter.qml
```

- Password: `password`, `F12` simulates a successful login, `Esc` exits.
- `F1`/`F2` are disabled in test mode (and on the lock screen).

Lock screen:

```bash
CTOS_MODE=lockd quickshell --path /opt/ctos/greeter.qml
```

Greeter logs under greetd: add `exec >/tmp/ctos-greeter.log 2>&1` before the `exec /usr/bin/kwin_wayland` line in `/etc/ctos/greeter.kwin.conf`.

<br>

## Uninstall

```bash
sudo systemctl disable greetd && sudo systemctl enable sddm   # or your previous display manager
sudo rm -rf /opt/ctos /etc/ctos /var/lib/ctos
```

<br>

## Credits

- [TSM-061/ctOS](https://github.com/TSM-061/ctOS) — original design and code.
- [Quickshell](https://quickshell.org/), [greetd](https://git.sr.ht/~kennylevinsen/greetd), KWin.

Licensed under the [GNU GPL v3](LICENSE), same as upstream.

<br>

## Legal

This project is a non-commercial, fan-made tribute. The **ctOS** name, branding, and logos are trademarks and/or copyrights of **Ubisoft Entertainment**.

- This software is not affiliated with, endorsed by, or supported by Ubisoft.
- All visual assets inspired by the _Watch Dogs_ universe are used strictly for aesthetic and creative purposes.
