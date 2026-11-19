import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import io.mrarm.mcpelauncher 1.0
import "Components"

// Pack porting: token balance, next refill, Port button. Discord is linked in the Lumen settings category.
ColumnLayout {
    id: page
    spacing: 0
    readonly property var pp: window.packPort
    Component.onCompleted: pp.refresh()

    BaseHeader { title: qsTr("Pack porting") }

    CenteredScrollView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        content: ColumnLayout {
            width: parent.width
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: card.implicitHeight + 32
                radius: 12
                color: window.lumenSurface
                border.width: 1
                border.color: window.lumenLine
                ColumnLayout {
                    id: card
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                    spacing: 8
                    Text {
                        visible: !pp.linked
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        color: window.lumenMuted
                        text: qsTr("Log in with Discord to port packs. The login is shared with the game.")
                    }
                    Button { visible: !pp.linked; enabled: !pp.loggingIn; text: pp.loggingIn ? qsTr("Waiting for the browser...") : qsTr("Link Discord"); onClicked: pp.login() }
                    Text { visible: pp.loggingIn && pp.loginUrl !== ""; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; color: window.lumenMuted; font.pointSize: 9; text: qsTr("Browser did not open? %1").arg(pp.loginUrl) }
                    Text { visible: pp.linked; color: "#ece8f8"; font.pointSize: 12; text: qsTr("Rank: %1").arg(pp.role !== "" ? pp.role : "...") + (pp.gamertag !== "" ? "  ·  " + pp.gamertag : "") }
                    Text { visible: pp.linked; text: qsTr("%1 tokens").arg(pp.balance); color: "#ece8f8"; font.pointSize: 16; font.bold: true }
                    Text {
                        visible: pp.linked
                        color: window.lumenMuted
                        text: pp.nextRefill !== "" ? qsTr("Next refill (+400): %1").arg(pp.nextRefill) : qsTr("Tokens are full.")
                    }
                    Text { visible: pp.linked; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: window.lumenMuted; text: qsTr("Drop a texture pack into the launcher and choose \"Port this pack\" (%1 tokens).").arg(pp.cost) }
                    ProgressBar { visible: pp.busy; Layout.fillWidth: true; indeterminate: true }
                    Text { visible: pp.status !== ""; color: window.lumenMuted; text: pp.status }
                    Text { visible: pp.error !== ""; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: "#ff6b6b"; text: pp.error }
                    Button { visible: pp.linked; text: qsTr("Unlink Discord"); onClicked: pp.logout() }
                }
            }
        }
    }
}
