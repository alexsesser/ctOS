import QtQuick
import QtQuick.Layouts

import qs.common
import qs.greeter.config

ColumnLayout {
    id: root

    Rectangle {
        id: progressBar

        // color: Theme.secondary
        color: "transparent"

        Layout.topMargin: 5 * Units.vh
        Layout.fillWidth: true
        Layout.preferredHeight: 5 * Units.vh

        property alias progress: scaleTransform.xScale

        Rectangle {
            id: fill

            color: Theme.ctosGray

            anchors.fill: parent

            transform: [
                Scale {
                    id: scaleTransform
                    origin.x: 0
                    xScale: 0
                }
            ]
        }
    }

    property real secondaryPercentageDecimal: 0

    Text {
        id: secondaryPercentage
        text: Math.round(root.secondaryPercentageDecimal * 100).toString().padStart(2, "0")

        Layout.rightMargin: Units.vh * 2
        Layout.topMargin: Units.vh * 5
        Layout.alignment: Qt.AlignRight
        Layout.bottomMargin: -3 * Units.vh

        color: Theme.textPrimary
        font {
            family: Settings.fontFamily
            weight: 300
            pixelSize: 12
        }
        opacity: 0
    }

    //SECTION - secondary progress stutter fill
    SequentialAnimation {
        id: animation

        NumberAnimation {
            target: secondaryPercentage
            property: "opacity"
            duration: 200
            to: 1
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "secondaryPercentageDecimal"
                duration: 500
                to: 0.3
            }

            NumberAnimation {
                target: progressBar
                property: "progress"
                duration: 500
                to: 0.3
            }
        }

        PauseAnimation {
            duration: 200
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "secondaryPercentageDecimal"
                duration: 500
                to: 1
                easing.type: Easing.InQuad
            }

            NumberAnimation {
                target: scaleTransform
                property: "xScale"
                duration: 500
                to: 1
                easing.type: Easing.InQuad
            }
        }
    }

    function start() {
        animation.start();
    }
}
