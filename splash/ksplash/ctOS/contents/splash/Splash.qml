// ctOS splash for Plasma (KSplash). Repeats the last frame of the ctOS greeter
// (logo at 40.6% of the height, accents around a thin progress bar), so after
// login the screen goes greeter → same picture → desktop.
// Geometry is taken from the greeter at 1080p and scaled by height / 1080.

import QtQuick

Rectangle {
    id: root

    // set by ksplashqml: 1 … 6, the splash closes after the last stage
    property int stage

    readonly property real vh: height / 1080
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    // ctOS common/Theme.qml
    readonly property color background: "#0E0E0E"
    readonly property color ctosGray: "#D9D9D9"
    readonly property color textPrimary: "#FFFFFF"
    readonly property color textDim: "#CACACA"
    readonly property color textDimmer: "#C3C3C3"
    readonly property color secondary: "#7A7A7A"

    color: background

    // same background grid as the greeter (MainLayout.qml)
    Image {
        anchors.fill: parent
        source: "images/lock.png"
    }

    // SECTION Logo: [ ███████ CT ] OS (greeter Splash.qml, final state)

    Item {
        id: logo

        width: 294 * root.vh
        height: 48 * root.vh
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.406 - height / 2

        Rectangle {
            width: parent.width * 0.73
            height: parent.height
            color: root.ctosGray
        }

        Text {
            id: os

            text: "OS"
            width: parent.width * 0.26
            anchors {
                right: parent.right
                baseline: parent.bottom
                baselineOffset: -3 * root.vh
            }
            color: root.textPrimary
            font {
                family: root.fontFamily
                weight: 300
                pixelSize: 64 * root.vh
            }
            fontSizeMode: Text.Fit
        }

        Text {
            text: "CT"
            width: os.width / 2
            anchors {
                left: parent.left
                leftMargin: 0.58 * parent.width
                baseline: parent.bottom
                baselineOffset: -5 * root.vh
            }
            color: root.background
            font {
                family: root.fontFamily
                weight: 500
                pixelSize: 34 * root.vh
            }
            fontSizeMode: Text.Fit
        }
    }

    // SECTION Progress (greeter FieldGroup after login)

    Item {
        id: field

        width: logo.width
        height: 56 * root.vh
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: logo.bottom
        anchors.topMargin: 50 * root.vh

        property real progress: Math.min(1, root.stage / 6)
        Behavior on progress {
            NumberAnimation {
                duration: 600
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            id: track
            y: 27 * root.vh
            width: parent.width
            height: 4 * root.vh
            color: root.secondary

            Rectangle {
                width: parent.width * field.progress
                height: parent.height
                color: root.ctosGray
            }
        }

        Text {
            id: status

            property int dots: 1

            anchors.top: track.bottom
            anchors.topMargin: 5 * root.vh
            text: "ESTABLISHING SESSION" + ".".repeat(dots)
            color: root.textDimmer
            font {
                family: root.fontFamily
                pixelSize: 14 * root.vh
            }

            NumberAnimation on dots {
                from: 1
                to: 3
                duration: 900
                loops: Animation.Infinite
            }
        }

        Text {
            anchors.top: status.top
            anchors.right: parent.right
            text: Math.round(field.progress * 100).toString().padStart(2, "0")
            color: root.textDim
            font {
                family: root.fontFamily
                pixelSize: 14 * root.vh
                weight: 500
            }
        }
    }

    // SECTION Accents: 4px, 18px/10px outside the field (greeter Accents.qml)

    component Accent: Image {
        source: "images/accent.svg"
        sourceSize: Qt.size(4, 4)
    }

    Accent {
        x: field.x - 18
        y: field.y - 10
    }
    Accent {
        x: field.x + field.width + 14
        y: field.y - 10
        rotation: 90
    }
    Accent {
        x: field.x + field.width + 14
        y: field.y + field.height + 6
        rotation: 180
    }
    Accent {
        x: field.x - 18
        y: field.y + field.height + 6
        rotation: 270
    }
}
