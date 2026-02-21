import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.common
import qs.greeter.components
import qs.greeter.config
import qs.greeter.services

ColumnLayout {
    id: fieldGroup

    signal finished

    width: 294 * Units.vh
    spacing: 0

    // SECTION Username row
    RowLayout {
        id: userRow

        spacing: 5
        transform: [
            Translate {
                id: userRowTranslate
            }
        ]

        Image {
            id: barcode

            Layout.preferredHeight: 10
            fillMode: Image.PreserveAspectCrop
            source: "../resources/barcode.svg"
        }

        // Редактируемое поле имени пользователя
        TextField {
            id: userInput

            text: AuthManager.user
            placeholderText: "username"

            // Фиксированная ширина — текст уходит влево при переполнении
            Layout.fillWidth: true
            Layout.maximumWidth: fieldGroup.width - barcode.width - userRow.spacing
            clip: true

            color: Theme.textPrimary
            font {
                family: Settings.fontFamily
                pixelSize: 14
                bold: true
            }

            background: Rectangle {
                color: "transparent"
                border.color: "transparent"
            }

            cursorVisible: false

            // Синхронизируем ввод с AuthManager
            onTextChanged: AuthManager.user = text

            // Tab переключает фокус на поле пароля
            Keys.onTabPressed: passwordField.forceActiveFocus()
            Keys.onReturnPressed: passwordField.forceActiveFocus()

            cursorDelegate: Text {
                id: userCursor

                color: Theme.textPrimary
                font: userInput.font
                text: "▁"
                opacity: 0

                Timer {
                    id: userBlinkTimer
                    interval: 500
                    repeat: true
                    running: false
                    onTriggered: userCursor.opacity = userCursor.opacity === 1 ? 0 : 1
                }

                Connections {
                    target: userInput
                    function onFocusChanged() {
                        if (userInput.focus) {
                            userCursor.opacity = 1
                            userBlinkTimer.start()
                        } else {
                            userBlinkTimer.stop()
                            userCursor.opacity = 0
                        }
                    }
                }
            }
        }
    }

    // SECTION Password field
    PasswordField {
        id: passwordField

        property int progressPercentage: 0

        enabled: AuthManager.state === AuthManager.State.Ready
        Layout.fillWidth: true
        Layout.preferredHeight: 40 * Units.vh
        Layout.alignment: Qt.AlignCenter

        color: {
            switch (AuthManager.state) {
            case AuthManager.State.Loading:
                return Theme.textPrimaryDim;
            case AuthManager.State.Success:
            case AuthManager.State.Finish:
                return Theme.success;
            case AuthManager.State.Failed:
                return Theme.error;
            default:
                return Theme.textPrimary;
            }
        }

        z: 5

        onAccepted: {
            AuthManager.respond(passwordField.text);
        }

        Component.onCompleted: {
            passwordField.forceActiveFocus();
        }

        Rectangle {
            id: progress

            anchors.fill: parent
            color: Theme.ctosGray

            transform: Scale {
                id: progressScale

                xScale: passwordField.progressPercentage / 100
            }
        }

        Text {
            id: progressValue

            text: passwordField.progressPercentage.toString().padStart(2, "0")

            anchors {
                top: parent.bottom
                topMargin: 5 * Units.vh
                right: parent.right
            }
            color: Theme.textPrimaryDim
            font {
                pixelSize: 14
                family: Settings.fontFamily
                weight: 500
            }
            opacity: 0
        }

        Text {
            id: progressDescription

            text: "INITIALIZING" + ".".repeat(fieldGroup.dotCount)

            anchors {
                top: parent.bottom
                topMargin: 5 * Units.vh
                left: parent.left
            }
            color: Theme.textPrimaryDimmer
            font {
                pixelSize: 14
                family: Settings.fontFamily
            }
            opacity: 0
        }

        background: Rectangle {
            id: passwordFieldBg

            color: Theme.background

            border {
                color: Theme.ctosGray
                width: 2
            }
        }

        transform: Scale {
            id: passwordFieldScale
        }
    }

    // SECTION Login button
    Rectangle {
        id: loginButton

        Layout.preferredHeight: 26 * Units.vh
        Layout.preferredWidth: parent.width * 0.38
        Layout.alignment: Qt.AlignRight
        color: Theme.ctosGray
        transform: [
            Scale {
                id: loginScale

                origin.x: loginButton.width
                origin.y: 0
            },
            Translate {
                id: loginTranslate
            }
        ]

        Text {
            id: loginText

            text: "LOGIN"
            visible: AuthManager.state !== AuthManager.State.Loading
            color: Theme.background

            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenter: parent.verticalCenter
            }

            font {
                pixelSize: 16
                family: Settings.fontFamily
            }
        }

        Spinner {
            active: AuthManager.state === AuthManager.State.Loading

            anchors {
                horizontalCenter: loginButton.horizontalCenter
                verticalCenter: loginButton.verticalCenter
            }
        }
    }

    // SECTION Success animation
    SequentialAnimation {
        id: animation

        PauseAnimation {
            duration: 200
        }

        ScriptAction {
            script: passwordField.text = ""
        }

        ParallelAnimation {
            NumberAnimation {
                targets: [userRow, loginText]
                property: "opacity"
                duration: 150
                to: 0
            }
            NumberAnimation {
                target: loginScale
                property: "yScale"
                to: 0
                duration: 275
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {

            ColorAnimation {
                target: passwordFieldBg
                property: "border.color"
                to: Theme.secondary
                duration: 200
            }

            NumberAnimation {
                target: passwordField
                property: "Layout.preferredHeight"
                to: 4 * Units.vh
                duration: 300
                easing.type: Easing.OutCubic
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: 150
                }
                NumberAnimation {
                    targets: [progressDescription, progressValue]
                    property: "opacity"
                    to: 1
                    duration: 150
                }

                ScriptAction {
                    script: textSpinner.start()
                }
            }
        }

        PauseAnimation {
            duration: 400
        }

        NumberAnimation {
            target: passwordField
            property: "progressPercentage"
            to: 40
            duration: 1000
            easing.type: Easing.InSine
        }

        PauseAnimation {
            duration: 300
        }

        NumberAnimation {
            target: passwordField
            property: "progressPercentage"
            to: 100
            duration: 300
            easing.type: Easing.InSine
        }

        onFinished: fieldGroup.finished()
    }

    property int dotCount: 0

    SequentialAnimation {
        id: textSpinner

        loops: Animation.Infinite

        NumberAnimation {
            target: fieldGroup
            property: "dotCount"
            from: 1
            to: 3
            duration: 900
        }
    }

    function start() {
        animation.start();
    }
}
