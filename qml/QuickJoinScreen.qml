import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Components"
import io.mrarm.mcpelauncher 1.0

ColumnLayout {
    id: page
    spacing: 0
    signal joinRequested(string uri)
    property bool joinAllowed: true // false while no Google account is signed in

    LumenProfiles {
        id: store
        dataDir: launcherSettings.gameDataDir
    }

    BaseHeader {
        title: qsTr("Quick Join")
    }

    CenteredScrollView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        content: ColumnLayout {
            width: parent.width
            spacing: 10

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: "#9a8fd0"
                font.pointSize: 10
                text: !page.joinAllowed ? qsTr("Sign in with Google first: quick join is off until you are signed in.")
                                           : gameLauncher.running ? qsTr("The game is running: close it to start a join from here.")
                                           : qsTr("Click a server to start the game and join it. Servers come from the Servers page.")
            }

            Repeater {
                model: store.profiles
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 56
                    radius: 12
                    color: area.containsMouse ? "#2a2250" : "#1c1638"
                    border.width: 1
                    border.color: "#3b3068"
                    enabled: !gameLauncher.running && page.joinAllowed
                    Text {
                        id: nm
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        text: modelData.label
                        color: "#fff"
                        font.pointSize: 13
                        font.bold: true
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: nm.right
                        anchors.leftMargin: 12
                        anchors.right: go.left
                        anchors.rightMargin: 8
                        text: modelData.hosts
                        color: "#9a8fd0"
                        font.pointSize: 10
                        elide: Text.ElideRight
                    }
                    Text {
                        id: go
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        text: qsTr("Join")
                        color: "#e8b84a"
                        font.pointSize: 12
                        font.bold: true
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { var u = store.joinUri(modelData.key); if (u) page.joinRequested(u) }
                    }
                }
            }
        }
    }
}
