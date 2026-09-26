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

    // Tab / Shift+Tab: password → username → session → LOGIN → password.
    // В lockd имя и сессия фиксированы, поэтому остаются только пароль и LOGIN.
    readonly property var _focusChain: Settings.isLockd ? [passwordField, loginScope] : [passwordField, userInput, sessionRow, loginScope]

    function _moveFocus(from, step) {
        const chain = _focusChain;
        const index = chain.indexOf(from);
        chain[(index + step + chain.length) % chain.length].forceActiveFocus();
    }

    function _login() {
        AuthManager.respond(passwordField.text);
    }

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

        TextField {
            id: userInput

            text: AuthManager.user
            placeholderText: "username"

            // lockd: разблокировать можно только сессию текущего пользователя
            readOnly: Settings.isLockd
            activeFocusOnPress: !readOnly

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

            onTextChanged: {
                if (!readOnly) {
                    AuthManager.user = text;
                }
            }

            Keys.onTabPressed: fieldGroup._moveFocus(userInput, 1)
            Keys.onBacktabPressed: fieldGroup._moveFocus(userInput, -1)
            Keys.onReturnPressed: fieldGroup._login()
            Keys.onEnterPressed: fieldGroup._login()

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
                    function onActiveFocusChanged() {
                        if (userInput.activeFocus) {
                            userCursor.opacity = 1;
                            userBlinkTimer.start();
                        } else {
                            userBlinkTimer.stop();
                            userCursor.opacity = 0;
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

        onAccepted: fieldGroup._login()

        Component.onCompleted: {
            passwordField.forceActiveFocus();
        }

        Keys.onTabPressed: fieldGroup._moveFocus(passwordField, 1)
        Keys.onBacktabPressed: fieldGroup._moveFocus(passwordField, -1)

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

    // SECTION Bottom row: session selector + login button
    RowLayout {
        Layout.fillWidth: true
        spacing: 0

        // Session selector: ‹ KDE PLASMA ›
        FocusScope {
            id: sessionRow

            Layout.fillWidth: true
            Layout.preferredHeight: 26 * Units.vh

            // lockd разблокирует уже запущенную сессию, выбирать нечего
            visible: !Settings.isLockd

            Keys.onTabPressed: fieldGroup._moveFocus(sessionRow, 1)
            Keys.onBacktabPressed: fieldGroup._moveFocus(sessionRow, -1)

            // Enter выполняет вход
            Keys.onReturnPressed: fieldGroup._login()
            Keys.onEnterPressed: fieldGroup._login()

            // Стрелки для смены сессии
            Keys.onLeftPressed: SessionManager.prev()
            Keys.onRightPressed: SessionManager.next()

            // Подсветка рамки когда в фокусе
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border {
                    color: sessionRow.activeFocus ? Theme.ctosGray : Theme.secondary
                    width: 1
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 4

                Text {
                    text: "‹"
                    color: sessionRow.activeFocus ? Theme.textPrimary : Theme.textSecondary
                    font {
                        family: Settings.fontFamily
                        pixelSize: 16
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SessionManager.prev()
                    }
                }

                Text {
                    id: sessionName
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: SessionManager.current.name.toUpperCase()
                    color: sessionRow.activeFocus ? Theme.textPrimary : Theme.textSecondary
                    font {
                        family: Settings.fontFamily
                        pixelSize: 12
                        weight: Font.Medium
                    }
                    elide: Text.ElideRight
                }

                Text {
                    text: "›"
                    color: sessionRow.activeFocus ? Theme.textPrimary : Theme.textSecondary
                    font {
                        family: Settings.fontFamily
                        pixelSize: 16
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SessionManager.next()
                    }
                }
            }
        }

        // Login button
        FocusScope {
            id: loginScope

            Layout.preferredHeight: 26 * Units.vh
            Layout.preferredWidth: parent.width * 0.38
            Layout.alignment: Qt.AlignRight

            Keys.onTabPressed: fieldGroup._moveFocus(loginScope, 1)
            Keys.onBacktabPressed: fieldGroup._moveFocus(loginScope, -1)

            // Enter когда кнопка в фокусе — логин
            Keys.onReturnPressed: fieldGroup._login()
            Keys.onEnterPressed: fieldGroup._login()

            Rectangle {
                id: loginButton

                anchors.fill: parent
                color: loginScope.activeFocus ? Theme.buttonFocus : Theme.ctosGray

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: fieldGroup._login()
                }

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
                    color: loginScope.activeFocus ? Theme.buttonFocusText : Theme.background

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
                targets: [userRow, sessionRow, loginScope]
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
