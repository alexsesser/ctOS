import QtQuick

Text {
    id: root
    required property string initialText

    property string currentText: initialText

    property string nextText

    property var buffer: []

    property int charIndex: 0

    signal finished

    text: nextText.substr(0, charIndex) + currentText.substr(charIndex,
                                                             currentText.length)

    SequentialAnimation {
        id: overwriteAnimation

        NumberAnimation {
            target: root
            property: "charIndex"
            duration: root.nextText.length * 10
            to: root.nextText.length
            easing.type: Easing.InSine
        }

        onFinished: {
            root.currentText = root.text;
            root.charIndex = 0;
            root.finished();
        }
    }

    Timer {
        id: worker
        repeat: true
        interval: 500
        onTriggered: {
            if (overwriteAnimation.running) {
                return;
            }

            if (root.buffer.length === 0) {
                worker.stop();
                return;
            }

            const s = root.buffer.shift();
            root.nextText = s;
            overwriteAnimation.start();
        }
    }

    function overwrite(s: string) {
        const previousText = buffer.length > 0 ? buffer[buffer.length - 1] :
                                                 currentText;
        const previousLength = previousText.length;
        const nextLength = s.length;

        if (nextLength < previousLength) {
            const lengthDifference = previousLength - nextLength;

            const nextText = `${s}${" ".repeat(lengthDifference)}`;
            root.buffer.push(nextText);
        } else {
            root.buffer.push(s);
        }

        worker.start();
    }
}
