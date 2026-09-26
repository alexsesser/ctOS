import QtQuick
import Quickshell.Io
import qs.common
import qs.greeter.config
import qs.greeter.services

// [F1] Shutdown • [F2] Reboot. Only on the login screen (greetd/kiosk): in test
// mode it would power off the developer's machine, in lockd it would let anyone
// shut down a machine with someone's session. Requires a second press within
// confirmTimeout.
Item {
    id: root

    readonly property bool powerEnabled: Settings.isGreetd || Settings.isKiosk
    readonly property int confirmTimeout: 2000

    readonly property var actions: ({
            [Qt.Key_F1]: {
                "label": "Shutdown",
                "command": ["systemctl", "poweroff"]
            },
            [Qt.Key_F2]: {
                "label": "Reboot",
                "command": ["systemctl", "reboot"]
            }
        })

    // key waiting for confirmation, 0 if none
    property int pendingKey: 0

    visible: powerEnabled
    implicitWidth: row.width
    implicitHeight: row.height

    opacity: 0
    Behavior on opacity {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutExpo
        }
    }

    // returns true if the key was handled
    function handleKey(key: int): bool {
        const action = actions[key];
        if (!action || !powerEnabled)
            return false;

        if (pendingKey !== key) {
            pendingKey = key;
            confirmTimer.restart();
            return true;
        }

        pendingKey = 0;
        confirmTimer.stop();

        if (power.running)
            return true;

        TerminalManager.displayMessage(`[SENTINEL ] ${action.label.toUpperCase()} REQUESTED`);
        power.command = action.command;
        power.running = true;
        return true;
    }

    Timer {
        id: confirmTimer
        interval: root.confirmTimeout
        onTriggered: root.pendingKey = 0
    }

    Process {
        id: power

        stderr: StdioCollector {
            id: powerError
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                const reason = powerError.text.trim() || `exit code ${exitCode}`;
                TerminalManager.displayMessage(`[SENTINEL ] ${power.command.join(" ")} failed: ${reason}`);
            }
        }
    }

    Row {
        id: row
        spacing: 8

        Text {
            visible: root.pendingKey === 0
            text: "[F1]  Shutdown"
            color: Theme.textPrimaryDimmer
            font {
                family: Settings.fontFamily
                pixelSize: 12
            }
        }
        Text {
            visible: root.pendingKey === 0
            text: "•"
            color: Theme.textSecondary
            font.pixelSize: 12
        }
        Text {
            visible: root.pendingKey === 0
            text: "[F2]  Reboot"
            color: Theme.textPrimaryDimmer
            font {
                family: Settings.fontFamily
                pixelSize: 12
            }
        }

        Text {
            visible: root.pendingKey !== 0
            text: {
                const action = root.actions[root.pendingKey];
                const key = root.pendingKey === Qt.Key_F1 ? "F1" : "F2";
                return action ? `Press [${key}] again to ${action.label.toLowerCase()}` : "";
            }
            color: Theme.error
            font {
                family: Settings.fontFamily
                pixelSize: 12
            }
        }
    }

    function start() {
        opacity = 1;
    }
}
