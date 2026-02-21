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

    readonly property var current: sessions[currentIndex] ?? { name: "plasma", exec: "startplasma-wayland" }

    function next() {
        if (sessions.length === 0) return
        currentIndex = (currentIndex + 1) % sessions.length
        logger.debug(`Session: ${current.name}`)
    }

    function prev() {
        if (sessions.length === 0) return
        currentIndex = (currentIndex - 1 + sessions.length) % sessions.length
        logger.debug(`Session: ${current.name}`)
    }

    Component.onCompleted: {
        _loadSessions()
    }

    function _parseName(text) {
        const match = text.match(/^Name=(.+)$/m)
        return match ? match[1].trim() : null
    }

    function _parseExec(text) {
        const match = text.match(/^Exec=(.+)$/m)
        return match ? match[1].trim() : null
    }

    function _loadSessions() {
        const dirs = [
            "/usr/share/wayland-sessions",
            "/usr/share/xsessions"
        ]

        let found = []

        for (const dir of dirs) {
            const result = Quickshell.execSync(["sh", "-c", `ls "${dir}"/*.desktop 2>/dev/null`])
            if (!result || result.trim() === "") continue

            const files = result.trim().split("\n")

            for (const file of files) {
                const content = Quickshell.execSync(["cat", file.trim()])
                if (!content) continue

                const name = _parseName(content)
                const exec = _parseExec(content)

                if (name && exec) {
                    found.push({ name, exec, file: file.trim() })
                    logger.debug(`Found session: ${name} -> ${exec}`)
                }
            }
        }

        if (found.length > 0) {
            sessions = found
            logger.info(`Loaded ${sessions.length} session(s)`)
        } else {
            // Fallback если .desktop файлы не найдены
            sessions = [{ name: "KDE Plasma", exec: "startplasma-wayland" }]
            logger.warn("No session files found, using fallback")
        }
    }
}
