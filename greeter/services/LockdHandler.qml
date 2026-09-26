pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pam

import qs.common

Singleton {
    id: handler

    Logger {
        id: logger
        name: "Lockd"
    }

    signal ready
    signal success
    signal failed

    PamContext {
        id: pam

        // no `user`: PAM authenticates the owner of the locked session (current uid),
        // never whatever is typed into the username field
        config: "login"

        onCompleted: result => {
            if (result === PamResult.Success) {
                handler.success();
                logger.info("Authentication attempt successful.");
            } else {
                handler.failed();
                logger.info("Authentication attempt failed.");
            }
        }
    }

    function start() {
        sessionStarter.start();
    }

    Timer {
        id: sessionStarter
        interval: 200
        repeat: true

        onTriggered: {
            if (!pam.responseRequired) {
                const success = pam.start();

                if (!success) {
                    return;
                }
            }

            logger.info(`Session opened for user ${AuthManager.user}`);

            handler.ready();
            sessionStarter.stop();
        }
    }

    function respond(password: string) {
        if (pam.responseRequired) {
            pam.respond(password);
        } else {
            logger.info("Failed to respond, no open session.");
        }
    }

    function finish() {
        logger.info("Unlocking desktop session.");
        Qt.quit();
    }
}
