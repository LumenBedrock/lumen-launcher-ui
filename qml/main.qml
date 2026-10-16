import QtQuick
import QtCore
import QtQuick.Window
import QtQuick.Dialogs
import QtQuick.Controls
import Qt.labs.platform
import io.mrarm.mcpelauncher 1.0
import "Components"

Window {
    id: window
    visible: true
    // resizable popup window (opens at 860x560)
    width: 860
    height: 560
    minimumWidth: 640
    minimumHeight: 440
    title: qsTr("Lumen Launcher")
    color: "#0d0a1c"
    property bool hasUpdate: false
    property bool hasAskedForKey: false
    property string updateDownloadUrl: ""
    property bool isVersionsInitialized: false
    property string currentGameDataDir: ""

    // Lumen designs: "sun", "classic", "orbit", "nebula", "pixel" (picked in the top right, saved)
    Settings {
        id: lumenLook
        category: "LumenLook"
        property string theme: "sun"
        property string colors: "{}"   // per design overrides: {"sun": {"accent": "#..."}}
    }
    property alias lumenTheme: lumenLook.theme

    // Colours of each design: accent (buttons, highlights), glow (star, gradients, gold marks), sky (background tint)
    readonly property var lumenDefaults: ({
        sun: { accent: "#9b80ff", glow: "#ffd166", sky: "#5a3fb0", nav: "#1a1338" },
        classic: { accent: "#9b80ff", glow: "#ffd166", sky: "#5a3fb0", nav: "#0d0a1c" },
        orbit: { accent: "#9b80ff", glow: "#ffd166", sky: "#4a3aa8", nav: "#b59cff" },
        nebula: { accent: "#ff9ecf", glow: "#ffe2a0", sky: "#8c64ff", nav: "#140e28" },
        pixel: { accent: "#7c5cff", glow: "#ffd166", sky: "#1a1428", nav: "#120d1f" }
    })
    readonly property var lumenOverrides: { try { return JSON.parse(lumenLook.colors) } catch (e) { return {} } }
    function lumenColor(key) {
        const own = lumenOverrides[lumenTheme] || {}
        return own[key] || (lumenDefaults[lumenTheme] || lumenDefaults.sun)[key]
    }
    function setLumenColor(key, value) {
        const all = Object.assign({}, lumenOverrides)
        const own = Object.assign({}, all[lumenTheme] || {})
        if (value) own[key] = value; else delete own[key]
        all[lumenTheme] = own
        lumenLook.colors = JSON.stringify(all)
    }
    function resetLumenColors() {
        const all = Object.assign({}, lumenOverrides)
        delete all[lumenTheme]
        lumenLook.colors = JSON.stringify(all)
    }
    function lumenAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
    // readable text on a coloured surface: dark on light colours, white on dark ones
    function lumenOn(c) { return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) > 0.55 ? "#120c26" : "#ffffff" }
    readonly property color lumenAccent: lumenColor("accent")
    readonly property color lumenGlow: lumenColor("glow")
    readonly property color lumenSky: lumenColor("sky")
    readonly property color lumenNav: lumenColor("nav")   // tab bar / navigation of the design
    // page colours derived from sky and accent, used by every sub page
    function lumenMix(a, b, t) { return Qt.rgba(a.r * (1 - t) + b.r * t, a.g * (1 - t) + b.g * t, a.b * (1 - t) + b.b * t, 1) }
    readonly property color lumenBase: "#0d0a1c"
    readonly property color lumenSurface: lumenMix(lumenSky, lumenBase, 0.75)        // cards
    readonly property color lumenSurfaceLow: lumenMix(lumenSky, lumenBase, 0.86)     // inputs, inner boxes
    readonly property color lumenSurfaceHigh: lumenMix(lumenMix(lumenSky, lumenBase, 0.62), lumenAccent, 0.12) // hover, selected
    readonly property color lumenLine: lumenMix(lumenAccent, lumenBase, 0.6)         // borders
    readonly property color lumenMuted: lumenMix(lumenAccent, "#a39cbd", 0.55)       // secondary text
    // text on the tab bar: white on dark bars, dark on light ones
    readonly property bool lumenNavLight: lumenOn(lumenNav) !== "#ffffff"
    readonly property color lumenNavText: lumenNavLight ? "#120c26" : "#ffffff"
    readonly property color lumenNavTextDim: lumenNavLight ? "#4a4266" : "#a39cbd"
    // animations pause while the game runs in front
    property bool lumenAnimate: window.visible && !(gameLauncher.running && !window.active)
    // sub pages: calmer background
    property bool lumenCalm: false

    // Lumen look: the background of the active design behind every page
    Loader {
        id: themeBackground
        anchors.fill: parent
        sourceComponent: window.lumenTheme === "pixel" ? pixelBackground : spaceBackgroundComponent
    }
    Component {
        id: spaceBackgroundComponent
        SpaceBackground {
            animated: window.lumenAnimate
            calm: window.lumenCalm
            nebula: window.lumenTheme === "nebula"
            showPlanet: window.lumenTheme === "classic"
            sky: window.lumenSky
            accent: window.lumenAccent
            glow: window.lumenGlow
            mx: parallax.hovered ? parallax.point.position.x / Math.max(1, width) - 0.5 : 0
            my: parallax.hovered ? parallax.point.position.y / Math.max(1, height) - 0.5 : 0
            HoverHandler { id: parallax }
        }
    }
    Component {
        id: pixelBackground
        Rectangle {
            color: window.lumenSky
            Image {
                anchors.fill: parent
                source: "qrc:/Resources/pixel-tile.png"
                fillMode: Image.Tile
                smooth: false
            }
        }
    }

    StackView {
        id: stackView
        anchors.fill: parent
        // pages fade and rise in, like the website's scroll reveals
        pushEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
                NumberAnimation { property: "y"; from: 18; to: 0; duration: 420; easing.type: Easing.OutCubic }
            }
        }
        pushExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 200 } }
        replaceEnter: pushEnter
        replaceExit: pushExit
    }

    ThemePicker {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: window.lumenTheme === "classic" ? 11 : (window.lumenTheme === "pixel" ? 6 : 12)
        anchors.rightMargin: 14
        z: 20
        theme: window.lumenTheme
        onPicked: function (t) { window.lumenTheme = t }
    }

    GoogleLoginHelper {
        id: googleLoginHelperInstance
        includeIncompatible: launcherSettings.showUnsupported
        singleArch: launcherSettings.singleArch
        chromeOS: launcherSettings.chromeOSMode || launcherSettings.trialMode
    }

    function mergeVersions(versions, extraVersions) {
        for (var i = 0; i < extraVersions.length; i++) {
            var extra = extraVersions[i];
            var found = false;

            for (var j = 0; j < versions.length; j++) {
                var v = versions[j];
                if (v.versionCode === extra.versionCode &&
                    v.abi === extra.abi) {
                    found = true;
                    break;
                }
            }

            if (!found)
                versions.unshift(extra);
        }

        return versions;
    }

    function updateAvailableArchivalVersions() {
        versionManagerInstance.availableArchivalVersions = mergeVersions(versionManagerInstance._archival.slice(), versionManagerInstance.extraVersions);
    }

    VersionManager {
        id: versionManagerInstance
        property var extraVersions: [];
        property var _archival: []
        property var availableArchivalVersions: []

        function setExtraVersions(extraVersions) {
            if(SAFE_MODE) {
                return;
            }
            versionManagerInstance.extraVersions = extraVersions;
            updateAvailableArchivalVersions();
        }

        Component.onCompleted: {
            versionManagerInstance._archival = versionManagerInstance.archivalVersions.versions.slice();
            updateAvailableArchivalVersions();
        }
    }

    Connections {
        target: versionManagerInstance.archivalVersions
        onVersionsChanged: {
            versionManagerInstance._archival = versionManagerInstance.archivalVersions.versions.slice();
            updateAvailableArchivalVersions();
        }
    }

    ProfileManager {
        id: profileManagerInstance
    }

    GamepadTool {
        id: gamepadTool
    }

    Component {
        id: panelLogin
        LoginScreen {
            googleLoginHelper: googleLoginHelperInstance
            versionManager: versionManagerInstance
            onFinished: stackView.replace(panelMain)
        }
    }

    GooglePlayApi {
        id: playApiInstance
        login: googleLoginHelperInstance

        property string googleLoginError: ""

        onAppInfoReceived: function (app, det) {
            playApiInstance.googleLoginError = ""
        }

        onInitError: function (err) {
            playApiInstance.googleLoginError = qsTr("<b>Cannot initialize Google Play Access</b>, Details:<br/>%1").arg(err)
        }

        onAppInfoFailed: function (app, err) {
            playApiInstance.googleLoginError = qsTr("<b>Cannot Access App Details</b> (%1), Details:<br/>%2").arg(app).arg(err)
        }
    }

    GoogleVersionChannel {
        id: playVerChannelInstance
        playApi: playApiInstance
        trialMode: launcherSettings.trialMode
    }

    Component {
        id: panelMain
        MainNavigation {}
    }

    Component {
        id: panelError
        UnsupportedScreen {
            googleLoginHelper: googleLoginHelperInstance
            onFinished: defaultnext()
        }
    }

    Component {
        id: panelUnlock
        UnlockScreen {
            onFinished: {
                next()
            }
        }
    }

    Component {
        id: panelSafeMode
        ErrorScreen {
            message: qsTr("UI Crashed :(<br/>Switched to safe mode with limited features<br/>A stack trace might have been written to your console")
            confirm: qsTr("Continue")
            onFinished: {
                next()
            }
        }
    }

    Component {
        id: panelChangelog
        ChangelogScreen {
            onFinished: {
                launcherSettings.lastVersion = LAUNCHER_VERSION_CODE
                next()
            }
        }
    }

    LauncherSettings {
        id: launcherSettings
    }

    MessageDialog {
        id: playDownloadError
        title: qsTr("Connecting to Google Play failed")
    }

    MessageDialog {
        id: errorDialog
        title: qsTr("Launcher Error")
    }

    TroubleshooterWindow {
        id: troubleshooterWindow
        googleLoginHelper: googleLoginHelperInstance
        playVerChannel: playVerChannelInstance
        playApi: playApiInstance
        modality: Qt.ApplicationModal
    }

    GoogleTosApprovalWindow {
        id: googleTosApprovalWindow
        onDone: function (approved, marketing) {
            playApiInstance.setTosApproved(approved, marketing)
        }
    }

    MessageDialog {
        id: corruptedInstallDialog
        title: qsTr("Unsupported Minecraft Version")
        text: qsTr("The Minecraft Version you are trying to run is unsupported.<br/><b>if you wanted to play a new Release please wait patiently for an update,<br/>please choose a compatible version from the profile Editor</b>")
    }

    GameLauncher {
        id: gameLauncher

        property var pendingFiles: []

        onLaunchFailed: {
            exited()
            showLaunchError(qsTr("Could not execute the game launcher. Please make sure it's dependencies are properly installed.<br><a href=\"%1\">Click here for more information Linux</a>").arg("https://github.com/minecraft-linux/mcpelauncher-manifest/issues/796"))
        }
        onStateChanged: {
            if (!running) {
                exited()
            }
            if (crashed) {
                application.setVisibleInDock(true)
            }
            importFiles()
        }
        onFileStarted: {
            importFiles()
        }

        onCorruptedInstall: {
            corruptedInstallDialog.open()
        }
        function exited() {
            application.setVisibleInDock(true)
            window.show()
        }
        function importFiles() {
            if (running) {
                if (pendingFiles.length > 0) {
                    var file = pendingFiles.shift()
                    startFile(file)
                }
            }
        }

        Component.onCompleted: {
            GamepadManager.gameRunning = Qt.binding(function() {
                return gameLauncher.running
            });
        }
    }

    MessageDialog {
        id: closeRunningDialog
        title: qsTr("Game is running")
        text: qsTr("Minecraft is currently running. Would you like to forcibly close it?\nHint: Press ignore to just close the Launcher UI")
        buttons: MessageDialog.Ignore | MessageDialog.Yes | MessageDialog.No
        modality: Qt.ApplicationModal

        onYesClicked: {
            gameLauncher.kill()
            application.quit()
        }

        onIgnoreClicked: {
            if (window.visible) {
                window.hide()
            }
        }
    }

    MessageDialog {
        id: restartDialog
        title: qsTr("Please restart")
        text: qsTr("Update finished, please restart the AppImage")
    }

    UpdateChecker {
        id: updateChecker

        onUpdateAvailable: {
            window.hasUpdate = true
            window.updateDownloadUrl = downloadUrl
        }
        onRequestRestart: {
            restartDialog.open()
        }
    }

    Connections {
        target: googleLoginHelperInstance
        function onLoginError(err) {
            playDownloadError.text = qsTr("The Launcher failed to sign you in\nPlease login again\n%1").arg(err)
            playDownloadError.open()
        }
    }

    Connections {
        target: window
        function onClosing() {
            if (true) {
                if (gameLauncher.running) {
                    close.accepted = false
                    closeRunningDialog.open()
                } else {
                    application.quit()
                }
            }
        }
    }

    function needsToLogIn() {
        return googleLoginHelperInstance.account == null && !googleLoginHelperInstance.hasEncryptedCredentials && versionManagerInstance.versions.size === 0
    }

    Component.onCompleted: {
        if (launcherSettings.checkForUpdates) {
            updateChecker.checkForUpdates()
        }
        versionManagerInstance.archivalVersions.versionsChanged.connect(function () {
            isVersionsInitialized = true
            console.log("Versionslist initialized")
        })
        versionManagerInstance.downloadLists(googleLoginHelperInstance.getAbis(true), launcherSettings.versionsFeedBaseUrl)
        if (SAFE_MODE) {
            stackView.push(panelSafeMode)
        } else if (LAUNCHER_CHANGE_LOG.length !== 0 && launcherSettings.lastVersion < LAUNCHER_VERSION_CODE) {
            stackView.push(panelChangelog)
        } else {
            next()
        }
    }

    function next() {
        if (!googleLoginHelperInstance.isSupported()) {
            stackView.push(panelError)
        } else if (googleLoginHelperInstance.hasEncryptedCredentials && !hasAskedForKey) {
            hasAskedForKey = true
            stackView.push(panelUnlock)
        } else {
            defaultnext()
        }
    }

    function defaultnext() {
        if (needsToLogIn()) {
            stackView.push(panelLogin)
        } else {
            stackView.push(panelMain)
        }
    }

    function showLaunchError(message) {
        errorDialog.text = message
        errorDialog.open()
    }

    function getCurrentGameDataDir() {
        if (window.currentGameDataDir && window.currentGameDataDir.length > 0) {
            return window.currentGameDataDir
        }
        return launcherSettings.gameDataDir
    }
}
