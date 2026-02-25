import QtQuick
import qs.common
import qs.greeter.config

Item {
    id: root
    implicitWidth: row.width
    implicitHeight: row.height

    opacity: 0
    Behavior on opacity {
    NumberAnimation {
        duration: 300
        easing.type: Easing.OutExpo
    }
}

Row {
    id: row
    spacing: 8

    Text {
        text: "[F1]  Shutdown"
        color: Theme.textPrimaryDimmer
        font {
            family: Settings.fontFamily
            pixelSize: 12
        }
    }
    Text {
        text: "•"
        color: Theme.textSecondary
        font.pixelSize: 12
    }
    Text {
        text: "[F2]  Reboot"
        color: Theme.textPrimaryDimmer
        font {
            family: Settings.fontFamily
            pixelSize: 12
        }
    }
}

function start()
{
    opacity = 1;
}
}