pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import qs.common

Singleton {
    id: sessionManager

    Logger {
        id: logger
        name: "SessionManager"
    }

    property var sessions: []
    property int currentIndex: 0

    readonly property var current: sessions.length > 0
        ? sessions[currentIndex]
        : { name: "KDE Plasma", exec: "startplasma-wayland" }

    function next() {
        if (sessions.length <= 1) return
        currentIndex = (currentIndex + 1) % sessions.length
        logger.debug(`Session switched to: ${current.name}`)
    }

    function prev() {
        if (sessions.length <= 1) return
        currentIndex = (currentIndex - 1 + sessions.length) % sessions.length
        logger.debug(`Session switched to: ${current.name}`)
    }

    // Step 1: find .desktop session files
    Process {
        id: findProcess

        command: ["sh", "-c",
            "find /usr/share/wayland-sessions /usr/share/xsessions -name '*.desktop' 2>/dev/null"
        ]

        stdout: SplitParser {
            onRead: data => {
                const path = data.trim()
                if (path !== "") fileLoader.paths.push(path)
            }
        }

        onExited: fileLoader.loadNext()
    }

    // Step 2: read each .desktop file
    QtObject {
        id: fileLoader

        property var paths: []
        property int index: 0
        property var parsed: []

        function loadNext() {
            if (index >= paths.length) {
                // All .desktop done — find shells
                shellFinder.running = true
                return
            }
            reader.path = paths[index]
            reader.reload()
        }

        function onFileRead(text) {
            const nameMatch = text.match(/^Name=(.+)$/m)
            const execMatch = text.match(/^Exec=(.+)$/m)
            if (nameMatch && execMatch) {
                parsed.push({
                    name: nameMatch[1].trim(),
                    exec: execMatch[1].trim()
                })
            }
            index++
            loadNext()
        }
    }

    FileView {
        id: reader
        onTextChanged: {
            if (path !== "") fileLoader.onFileRead(reader.text())
        }
    }

    // Step 3: find available shells from /etc/shells
    // Deduplicates by binary name, skips restricted and system shells
    Process {
        id: shellFinder

        command: ["sh", "-c",
            "cat /etc/shells 2>/dev/null | grep -v '^#' | grep -v '^$' | while read s; do " +
            "  [ -x \"$s\" ] || continue; " +
            "  name=$(basename \"$s\"); " +
            "  case \"$name\" in rbash|rzsh|rsh|git-shell|systemd-*) continue;; esac; " +
            "  echo \"$name|$s\"; " +
            "done | sort -t'|' -k1,1 -u"
        ]

        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split("|")
                if (parts.length !== 2) return

                const name = parts[0].toUpperCase()
                const exec = parts[1]

                const exists = fileLoader.parsed.some(s =>
                    s.name.toUpperCase() === name
                )

                if (!exists) {
                    fileLoader.parsed.push({ name: name, exec: exec })
                    logger.debug(`Found shell: ${name} -> ${exec}`)
                }
            }
        }

        onExited: {
            if (fileLoader.parsed.length > 0) {
                sessionManager.sessions = fileLoader.parsed
                logger.info(`Loaded ${sessionManager.sessions.length} session(s):`)
                for (const s of sessionManager.sessions) {
                    logger.info(`  ${s.name} -> ${s.exec}`)
                }
            } else {
                logger.warn("No sessions found, using fallback")
                sessionManager.sessions = [
                    { name: "KDE Plasma", exec: "startplasma-wayland" }
                ]
            }
        }
    }

    Component.onCompleted: {
        findProcess.running = true
    }
}
