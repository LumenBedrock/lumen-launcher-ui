import QtQuick
import QtCore
import QtQuick.Window
import QtQuick.Dialogs
import QtQuick.Controls
import Qt.labs.platform
import io.mrarm.mcpelauncher 1.0

Window {
    id: window
    visible: true
    width: 640
    height: 480
    title: qsTr("Request Google Credentials")
    color: "#0d0a1c"
    property bool hasUpdate: false
    property bool hasAskedForKey: false
    property string updateDownloadUrl: ""
    property bool isVersionsInitialized: false
    property string currentGameDataDir: ""

    // same look as the main window: the shared pages read these
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
    property bool lumenAnimate: window.visible
    property bool lumenCalm: true

    StackView {
        id: stackView
        anchors.fill: parent
    }

    GoogleLoginHelper {
        id: googleLoginHelperInstance
        includeIncompatible: launcherSettings.showUnsupported
        singleArch: launcherSettings.singleArch
        chromeOS: launcherSettings.chromeOSMode || launcherSettings.trialMode
    }

    Component {
        id: panelError
        ErrorScreen {
            onFinished: defaultnext()
        }
    }

    StdioHelper {
        id: stdio
    }

    Component {
        id: panelDefault
        ErrorScreen {
            message: qsTr("A mod at '%1'<br/>is requesting access to your google credentials,<br/>to reject this request close this window").arg(SOURCE_MOD)
            onFinished: {
                stdio.error("CRED=" + googleLoginHelperInstance.account.accountIdentifier + ":" + googleLoginHelperInstance.account.accountToken)
                stdio.error("CREDB64=" + Qt.btoa(JSON.stringify(googleLoginHelperInstance.account)))
                window.close()
                application.quit()
            }
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

    LauncherSettings {
        id: launcherSettings
    }

    Connections {
        target: window
        function onClosing() {
            application.quit()
        }
    }

    function needsToLogIn() {
        return googleLoginHelperInstance.account == null && !googleLoginHelperInstance.hasEncryptedCredentials && versionManagerInstance.versions.size === 0
    }

    Component.onCompleted: {
        next()
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
        stackView.push(panelDefault)
    }
}
