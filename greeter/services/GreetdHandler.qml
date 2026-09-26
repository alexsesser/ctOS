pragma Singleton

import Quickshell
import Quickshell.Services.Greetd
import QtQuick

import qs.greeter.config
import qs.common

Singleton {
    id: handler

    signal ready
    signal success
    signal failed

    // password entered before the greetd session for the current user existed;
    // sent as soon as greetd asks for it
    property string _pendingPassword: ""
    property bool _hasPending: false

    Logger {
        id: logger
        name: "Greetd"
    }

    Connections {
        id: connection
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            // info/error messages are acknowledged by Quickshell itself
            if (!responseRequired) {
                logger.info(`greetd: ${message}`);
                return;
            }

            if (handler._hasPending) {
                const password = handler._pendingPassword;
                handler._clearPending();
                Greetd.respond(password);
                return;
            }

            // requesting password
            logger.info("Credentials requested...");
            handler.ready();
        }

        function onAuthFailure(message) {
            // password is wrong
            logger.info("// AUTH_ERROR");
            handler._clearPending();
            handler.failed();
        }

        function onError(error) {
            logger.error(`greetd error: ${error}`);
            handler._fail();
        }

        function onReadyToLaunch() {
            // password is correct
            handler._clearPending();
            handler.success();
        }
    }

    function _clearPending() {
        _pendingPassword = "";
        _hasPending = false;
    }

    // failure not reported by greetd: drop the session, otherwise start()
    // would wait for Inactive forever
    function _fail() {
        _clearPending();
        if (Greetd.state !== GreetdState.Inactive) {
            Greetd.cancelSession();
        }
        handler.failed();
    }

    function start() {
        sessionStarter.restart();
    }

    // createSession() must not run in the same tick as cancelSession(): greetd
    // answers cancel_session with `success`, which would be taken for a successful
    // authentication. Wait for Inactive before creating the session.
    Timer {
        id: sessionStarter
        interval: 200
        repeat: true
        onTriggered: {
            if (Greetd.state !== GreetdState.Inactive) {
                return;
            }

            sessionStarter.stop();

            if (!AuthManager.user) {
                // nothing to authenticate yet, let the user type a username
                handler._clearPending();
                handler.ready();
                return;
            }

            logger.info(`Initializing session...(user:${AuthManager.user})`);
            Greetd.createSession(AuthManager.user);
        }
    }

    function respond(password) {
        if (!Greetd.available) {
            logger.error("Failed to respond, greetd not available.");
            handler._fail();
            return;
        }

        if (!AuthManager.user) {
            logger.info("Username is empty.");
            handler._fail();
            return;
        }

        if (Greetd.state === GreetdState.Authenticating && Greetd.user === AuthManager.user) {
            Greetd.respond(password);
            return;
        }

        // username changed (or no session yet): recreate the session and send
        // the password once greetd asks for it
        logger.info(`Recreating session for user ${AuthManager.user}`);
        _pendingPassword = password;
        _hasPending = true;

        if (Greetd.state !== GreetdState.Inactive) {
            Greetd.cancelSession();
        }

        sessionStarter.restart();
    }

    function finish() {
        const launchCmd = SessionManager.current.exec.trim().split(/\s+/);
        logger.info(`Launching session: ${SessionManager.current.name} -> ${launchCmd.join(" ")}`);

        Greetd.launch(launchCmd);

        if (Settings.exitCommand.length) {
            Quickshell.execDetached(Settings.exitCommand);
        }
    }
}
