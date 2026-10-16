import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "Components"

// Page frame: the navigation of the active launcher design (window.lumenTheme) plus the page stack
Item {
    id: mainNavigation
    property int currentIndex: 0
    readonly property bool joinSignedIn: googleLoginHelperInstance.account != null || googleLoginHelperInstance.hasEncryptedCredentials
    property bool useWideLayout: window.width > 720
    readonly property var pages: [
        { label: qsTr("Home"), index: 0, icon: "qrc:/Resources/lumen-nav-home.svg" },
        { label: qsTr("Servers"), index: 7, icon: "qrc:/Resources/lumen-nav-servers.svg" },
        { label: qsTr("Quick Join"), index: 8, icon: "qrc:/Resources/lumen-nav-servers.svg" },
        { label: qsTr("Versions"), index: 6, icon: "qrc:/Resources/lumen-nav-versions.svg" },
        { label: qsTr("Game Log"), index: 3, icon: "qrc:/Resources/lumen-nav-log.svg" },
        { label: qsTr("Settings"), index: 4, icon: "qrc:/Resources/lumen-nav-settings.svg" }
    ]

    Loader {
        id: nav
        anchors.fill: parent
        z: 3
        sourceComponent: ({ classic: navTopBar, pixel: navPixel, nebula: navDock, orbit: navArc })[window.lumenTheme] || navSidebar
    }
    Component { id: navSidebar; NavSidebar { navigation: mainNavigation } }
    Component { id: navTopBar; NavTopBar { navigation: mainNavigation } }
    Component { id: navPixel; NavPixel { navigation: mainNavigation } }
    Component { id: navDock; NavDock { navigation: mainNavigation } }
    Component { id: navArc; NavArc { navigation: mainNavigation } }

    StackView {
        id: mainStackView
        initialItem: launcherHomePage
        // sub pages fade and slide in
        pushEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; from: 24; to: 0; duration: 340; easing.type: Easing.OutCubic }
            }
        }
        pushExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 } }
        popEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; from: -24; to: 0; duration: 340; easing.type: Easing.OutCubic }
            }
        }
        popExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 160 } }
        replaceEnter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; from: 18; to: 0; duration: 300; easing.type: Easing.OutCubic }
            }
        }
        replaceExit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 } }
        anchors.fill: parent
        anchors.leftMargin: nav.item ? nav.item.reserveLeft : 0
        anchors.topMargin: nav.item ? nav.item.reserveTop : 0
        anchors.bottomMargin: nav.item ? nav.item.reserveBottom : 0
    }

    Component {
        id: launcherHomePage
        HomeScreen {
            googleLoginHelper: googleLoginHelperInstance
            versionManager: versionManagerInstance
            profileManager: profileManagerInstance
            playApi: playApiInstance
            playVerChannel: playVerChannelInstance
            hasUpdate: window.hasUpdate
            updateDownloadUrl: window.updateDownloadUrl
            isVersionsInitialized: window.isVersionsInitialized
        }
    }

    Component {
        id: serversPage
        ServersScreen {
            joinAllowed: joinSignedIn
            onJoinRequested: function (uri) { joinQueued(uri) }
        }
    }

    Component {
        id: quickJoinPage
        QuickJoinScreen {
            joinAllowed: joinSignedIn
            onJoinRequested: function (uri) { joinQueued(uri) }
        }
    }

    Component {
        id: versionsPage
        VersionsScreen {}
    }

    ListModel {
        id: gameLog
    }

    Connections {
        target: gameLauncher
        function onLogCleared() {
            gameLog.clear()
        }
        function onLogAppended(text) {
            // Lumen: the game logs this harmless texture warning over and over; don't show it
            if (/failed to load from memory|unknown image type/i.test(text))
                return
            gameLog.append({
                               "display": text.trim()
                           })
        }
    }

    Component {
        id: gameLogPage
        GameLogScreen {
            launcher: gameLauncher
        }
    }

    Component {
        id: launcherSettingsPage
        SettingsScreen {
            googleLoginHelper: googleLoginHelperInstance
            versionManager: versionManagerInstance
            playVerChannel: playVerChannelInstance
        }
    }

    Component.onCompleted: {
        if (LUMEN_START_SET && LUMEN_START_PAGE > 0)
            updateIndex(LUMEN_START_PAGE)
    }

    // start the game and hand it the Bedrock connect link
    function joinQueued(uri) {
        updateIndex(0)
        if (mainStackView.currentItem) mainStackView.currentItem.playUri(uri)
    }

    function updateIndex(index) {
        if (index === currentIndex)
            return

        const page = ({ 6: versionsPage, 7: serversPage, 8: quickJoinPage, 3: gameLogPage, 4: launcherSettingsPage })[index]
        if (!page)
            mainStackView.pop(null)                                   // back home
        else if (mainStackView.depth > 1)
            mainStackView.replace(mainStackView.currentItem, page)    // page to page: home never shows in between
        else
            mainStackView.push(page)

        currentIndex = index
        window.lumenCalm = index !== 0
    }

    Connections {
        target: gameLauncher
        function onCrashedChanged() {
            if (gameLauncher.crashed || !(launcherSettings.startHideLauncher || launcherSettings.disableGameLog))
                updateIndex(3)
        }
    }
}
