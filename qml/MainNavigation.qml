import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "Components"

RowLayout {
    id: mainNavigation
    spacing: 0
    property int currentIndex: 0
    property bool useWideLayout: window.width > 720

    Rectangle {
        Layout.fillHeight: true
        Layout.preferredWidth: sidebarLayout.width
        z: 3
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1d1642" }
            GradientStop { position: 1.0; color: "#0d0a1c" }
        }
        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: "#3b3068"
        }
        ColumnLayout {
            id: sidebarLayout
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            RowLayout {
                Layout.leftMargin: 14
                Layout.bottomMargin: 18
                spacing: 10
                Image {
                    source: "qrc:/Resources/lumen-icon.svg"
                    sourceSize.width: 34
                    sourceSize.height: 34
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                }
                Text {
                    visible: useWideLayout
                    text: "LUMEN"
                    color: "#e8b84a"
                    font.pointSize: 13
                    font.bold: true
                    font.letterSpacing: 3
                }
            }
            MSideBarItem {
                text: qsTr("Home")
                iconSource: "qrc:/Resources/lumen-nav-home.svg"
                showText: useWideLayout
                onClicked: updateIndex(0)
                checked: currentIndex == 0
            }
            MSideBarItem {
                text: qsTr("Servers")
                iconSource: "qrc:/Resources/lumen-nav-servers.svg"
                showText: useWideLayout
                onClicked: updateIndex(7)
                checked: currentIndex === 7
            }
            MSideBarItem {
                text: qsTr("Versions")
                iconSource: "qrc:/Resources/lumen-nav-versions.svg"
                showText: useWideLayout
                onClicked: updateIndex(6)
                checked: currentIndex === 6
            }
            MSideBarItem {
                text: qsTr("Game Log")
                iconSource: "qrc:/Resources/lumen-nav-log.svg"
                showText: useWideLayout
                onClicked: updateIndex(3)
                checked: currentIndex === 3
            }
            MSideBarItem {
                text: qsTr("Settings")
                iconSource: "qrc:/Resources/lumen-nav-settings.svg"
                showText: useWideLayout
                onClicked: updateIndex(4)
                checked: currentIndex == 4
            }
            MSideBarItem {
                visible: launcherSettings.showExitButton
                text: qsTr("Exit")
                iconSource: "qrc:/Resources/icon-exit.png"
                showText: useWideLayout
                onClicked: Qt.quit()
                checked: false
            }
        }
    }

    StackView {
        id: mainStackView
        initialItem: launcherHomePage
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.minimumHeight: 200
        Layout.minimumWidth: 400
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
        ServersScreen {}
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

    function updateIndex(index) {
        if (index === currentIndex)
            return

        mainStackView.pop(null)

        if (index === 6) {
            mainStackView.push(versionsPage)
        } else if (index === 7) {
            mainStackView.push(serversPage)
        } else if (index === 3) {
            mainStackView.push(gameLogPage)
        } else if (index === 4) {
            mainStackView.push(launcherSettingsPage)
        }

        currentIndex = index
    }

    Connections {
        target: gameLauncher
        function onCrashedChanged() {
            if (gameLauncher.crashed || !(launcherSettings.startHideLauncher || launcherSettings.disableGameLog))
                updateIndex(3)
        }
    }
}
