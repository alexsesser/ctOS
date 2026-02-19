import QtQuick

import qs.greeter.config
import qs.common

Item {
    id: root

    signal progressBarMidway
    signal revealFinished
    signal exitFinished

    Text {
        id: os
        text: "OS"
        width: parent.width * 0.26  // progress is 0.73 of parent

        TextMetrics {
            id: osMetrics
            font: ct.font
            text: ct.text
        }

        anchors {
            right: parent.right
            baseline: parent.bottom
            baselineOffset: -3
        }

        color: Theme.textPrimary

        font {
            family: Settings.fontFamily
            weight: 300
            pixelSize: 64
        }
        fontSizeMode: Text.Fit
    }

    Rectangle {
        id: progress

        color: Theme.ctosGray

        anchors.fill: parent

        transformOrigin: Item.Left

        transform: [
            Scale {
                id: progressX
                origin.x: 0
                xScale: 0.73
            },
            Scale {
                id: progressY
                origin.y: progress.height / 2
            }
        ]
    }

    Text {
        id: ct
        text: "CT"

        width: os.width / 2

        TextMetrics {
            id: ctMetrics
            font: ct.font
            text: ct.text
        }

        anchors {
            left: parent.left
            baseline: parent.bottom
            baselineOffset: -5

            leftMargin: -ctMetrics.tightBoundingRect.x + 0.58 * parent.width
        }
        color: Theme.background
        font {
            family: Settings.fontFamily
            weight: 500
            pixelSize: 34
        }
        fontSizeMode: Text.Fit
    }

    SequentialAnimation {
        id: startupAnimation
        running: Settings.animationProfile(Settings.AnimationMode.All)

        // SECTION - setup

        PropertyAction {
            target: progressX
            property: "xScale"
            value: 0
        }
        PropertyAction {
            target: progressY
            property: "yScale"
            value: 0.7
        }
        PropertyAction {
            targets: [ct, os]
            property: "opacity"
            value: 0
        }

        ScriptAction {
            script: startupAnimation.pause()
        }

        // SECTION - begin splash reveal

        PauseAnimation {
            duration: 500
        }

        NumberAnimation {
            target: progressX
            property: "xScale"
            to: 0.4
            duration: 700
        }

        ScriptAction {
            script: {
                root.progressBarMidway();
            }
        }

        NumberAnimation {
            target: progressX
            property: "xScale"
            to: 1
            duration: 300
            easing.type: Easing.OutSine
        }

        PauseAnimation {
            duration: 300
        }

        //SECTION - expand and retract to reveal OS text

        NumberAnimation {
            target: progressY
            property: "yScale"
            to: 1
            duration: 350
            easing.type: Easing.OutCubic
        }

        PauseAnimation {
            duration: 500
        }

        NumberAnimation {
            target: os
            property: "opacity"
            to: 1
            duration: 0
        }

        NumberAnimation {
            target: progressX
            property: "xScale"
            to: 0.73  // percentage of rect in final state
            duration: 300
            easing.type: Easing.OutQuart
        }

        NumberAnimation {
            target: ct
            property: "opacity"
            to: 1
            duration: 100
        }

        onFinished: {
            root.revealFinished();
        }
    }

    SequentialAnimation {
        id: exitAnimation

        //SECTION - hide text and fill bar

        ParallelAnimation {
            NumberAnimation {
                target: ct
                property: "opacity"
                to: 0
                duration: 200
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                target: progressX
                property: "xScale"
                to: 1
                duration: 500
                easing.type: Easing.OutCubic
            }
        }

        PauseAnimation {
            duration: 400
        }

        PropertyAction {
            target: os
            property: "opacity"
            value: 0
        }

        ParallelAnimation {

            NumberAnimation {
                target: progress
                property: "opacity"
                to: 0.1
                duration: 250
                easing.type: Easing.InOutCirc
            }

            NumberAnimation {
                target: progressY
                property: "yScale"
                to: 0.075
                duration: 250
                easing.type: Easing.OutCirc
            }
        }

        PauseAnimation {
            duration: 300
        }

        onFinished: root.exitFinished()
    }

    function start() {
        startupAnimation.resume();
    }

    function startExit() {
        exitAnimation.start();
    }
}
