pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.common
import qs.greeter.config

Singleton {
    id: sessionManager

    Logger {
        id: logger
        name: "SessionManager"
    }

    readonly property var fallback: {
        "name": "KDE Plasma",
        "exec": "startplasma-wayland",
        "graphical": true
    }

    property var sessions: []
    property int currentIndex: 0

    readonly property var current: sessions.length > 0 ? sessions[currentIndex] : fallback

    function next() {
        if (sessions.length <= 1)
            return;
        currentIndex = (currentIndex + 1) % sessions.length;
        logger.debug(`Session switched to: ${current.name}`);
    }

    function prev() {
        if (sessions.length <= 1)
            return;
        currentIndex = (currentIndex - 1 + sessions.length) % sessions.length;
        logger.debug(`Session switched to: ${current.name}`);
    }

    // Prints one `kind<TAB>name<TAB>exec` line per entry:
    // - `session`: [Desktop Entry] of /usr/share/wayland-sessions/*.desktop,
    //   without Hidden/NoDisplay ones. X11 sessions are skipped: greetd starts
    //   them without an X server.
    // - `shell`: executable shells from /etc/shells, deduplicated by binary name,
    //   without restricted and system shells.
    Process {
        id: finder

        property var found: []

        command: ["sh", "-c", `
for f in /usr/share/wayland-sessions/*.desktop; do
    [ -f "$f" ] || continue
    awk '
        /^\\[/ { section = ($0 == "[Desktop Entry]"); next }
        !section { next }
        /^Name=/ && name == "" { name = substr($0, 6) }
        /^Exec=/ && cmd == "" { cmd = substr($0, 6) }
        /^(Hidden|NoDisplay)=true/ { skip = 1 }
        END { if (!skip && name != "" && cmd != "") printf "session\\t%s\\t%s\\n", name, cmd }
    ' "$f"
done

grep -v -e '^#' -e '^$' /etc/shells 2>/dev/null | while read -r s; do
    [ -x "$s" ] || continue
    name=$(basename "$s")
    case "$name" in rbash|rzsh|rsh|git-shell|nologin|systemd-*) continue ;; esac
    printf '%s\\t%s\\n' "$name" "$s"
done | sort -t "$(printf '\\t')" -k1,1 -u | sed 's/^/shell\\t/'
`]

        stdout: SplitParser {
            onRead: data => {
                const parts = data.split("\t");
                if (parts.length !== 3)
                    return;

                const [kind, rawName, exec] = parts.map(part => part.trim());
                const name = kind === "shell" ? rawName.toUpperCase() : rawName;

                if (finder.found.some(s => s.name.toUpperCase() === name.toUpperCase()))
                    return;

                finder.found.push({
                    name,
                    exec,
                    // shells need the terminal, graphical sessions don't
                    "graphical": kind === "session"
                });
            }
        }

        onExited: {
            if (finder.found.length === 0) {
                logger.warn("No sessions found, using fallback");
                sessionManager.sessions = [sessionManager.fallback];
                return;
            }

            sessionManager.sessions = finder.found;
            sessionManager.currentIndex = sessionManager._defaultIndex();

            logger.info(`Loaded ${sessionManager.sessions.length} session(s):`);
            for (const s of sessionManager.sessions) {
                logger.info(`  ${s.name} -> ${s.exec}`);
            }
            logger.info(`Default session: ${sessionManager.current.name}`);
        }
    }

    // session whose Exec contains modes.greetd.launch, otherwise the first one
    function _defaultIndex() {
        const launch = (Settings.launchCommand || []).join(" ");
        if (!launch)
            return 0;

        const index = sessions.findIndex(s => s.exec.includes(launch));
        return index >= 0 ? index : 0;
    }

    Component.onCompleted: {
        finder.running = true;
    }
}
