pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

import qs.common

TextField {
    id: passwordField

    property alias rem: cursorMetrics.width

    font {
        pixelSize: 16
        letterSpacing: 5
    }

    echoMode: TextInput.Password
    passwordCharacter: "█"

    TextMetrics {
        id: cursorMetrics
        font: passwordField.font
        text: "▁"
    }

    leftPadding: 8
    rightPadding: cursorMetrics.width + 6

    cursorVisible: false

    cursorDelegate: Text {
        id: cursor

        color: passwordField.color
        font: passwordField.font
        text: "▁"
        opacity: 0

        Timer {
            id: blinkTimer
            interval: 500
            repeat: true
            running: false
            onTriggered: cursor.opacity = cursor.opacity === 1 ? 0 : 1
        }

        Connections {
            target: passwordField

            function onActiveFocusChanged() {
                if (passwordField.activeFocus) {
                    cursor.opacity = 1
                    blinkTimer.start()
                } else {
                    blinkTimer.stop()
                    cursor.opacity = 0
                }
            }

            function onEnabledChanged() {
                if (!passwordField.enabled) {
                    blinkTimer.stop()
                    cursor.opacity = 0
                }
            }

            function onTextEdited() {
                cursor.opacity = 1
                blinkTimer.restart()
            }
        }

        Component.onCompleted: {
            if (passwordField.activeFocus) {
                cursor.opacity = 1
                blinkTimer.start()
            }
        }
    }

    background: Rectangle {
        color: "transparent"
        border {
            color: Theme.ctosGray
            width: 2
        }
    }

    Component.onDestruction: {
        passwordField.focus = false
    }
}
