import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Components"

// Beta page: shown in the navigation only for linked Owner/Developer/Beta Tester accounts.
// One download card for the Lumen client and one for the launcher itself.
ColumnLayout {
    id: page
    property var clientBeta   // LumenBeta, kind "client"
    property var launcherBeta // LumenBeta, kind "launcher"
    spacing: 0
    Component.onCompleted: { clientBeta.refresh(); launcherBeta.refresh() }

    BaseHeader { title: qsTr("Beta") }

    CenteredScrollView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        content: ColumnLayout {
            width: parent.width
            spacing: 10

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: window.lumenMuted
                font.pointSize: 10
                text: qsTr("Test builds, only for the Lumen team and Beta Testers. Each build is signed and checked before it is installed. Your worlds and settings are not touched.")
            }

            Repeater {
                model: [
                    { b: page.clientBeta, heading: qsTr("Client beta") },
                    { b: page.launcherBeta, heading: qsTr("Launcher beta") }
                ]
                delegate: Rectangle {
                    id: cardRoot
                    property var b: modelData.b
                    property string heading: modelData.heading
                    Layout.fillWidth: true
                    implicitHeight: card.implicitHeight + 32
                    radius: 12
                    color: window.lumenSurface
                    border.width: 1
                    border.color: b.updateAvailable ? "#ffd166" : window.lumenLine

                    ColumnLayout {
                        id: card
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: b.version !== "" ? cardRoot.heading + " " + b.version : qsTr("No %1 published right now").arg(cardRoot.heading)
                                color: "#ece8f8"
                                font.pointSize: 14
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                visible: b.updateAvailable
                                text: qsTr("NEW")
                                color: "#ffd166"
                                font.bold: true
                            }
                        }
                        Text {
                            visible: b.version !== ""
                            color: "#a39cbd"
                            text: qsTr("Built %1").arg(b.build)
                        }
                        Text {
                            visible: b.notes !== ""
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: "#ece8f8"
                            text: b.notes
                        }
                        Text {
                            visible: b.games !== ""
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            color: "#a39cbd"
                            text: qsTr("Game versions: %1").arg(b.games)
                        }
                        Text {
                            color: "#a39cbd"
                            text: qsTr("Installed: %1").arg(b.installed)
                        }

                        ProgressBar {
                            Layout.fillWidth: true
                            visible: b.busy
                            value: b.progress
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            wrapMode: Text.WordWrap
                            color: b.error !== "" ? "#ff8a80" : "#9b80ff"
                            text: b.error !== "" ? b.error : b.status
                        }

                        RowLayout {
                            spacing: 10
                            MButton {
                                enabled: b.updateAvailable && !b.busy
                                text: b.updateAvailable ? qsTr("Install %1").arg(b.version) : (b.canInstallAnyway ? qsTr("Local build installed") : qsTr("Up to date"))
                                onClicked: b.install()
                            }
                            MButton {
                                id: anywayButton
                                property bool sure: false
                                visible: b.canInstallAnyway
                                enabled: !b.busy
                                text: sure ? qsTr("Click again to replace your local build (it is backed up)") : qsTr("Install beta anyway")
                                onClicked: {
                                    if (!sure) { sure = true; sureTimer.restart(); return }
                                    sure = false
                                    b.installAnyway()
                                }
                                Timer { id: sureTimer; interval: 6000; onTriggered: anywayButton.sure = false }
                            }
                            MButton {
                                visible: b.restartNeeded
                                text: qsTr("Restart to finish update")
                                onClicked: b.applyAndRestart()
                            }
                            MButton {
                                enabled: (b.installed !== qsTr("Stable") && b.installed !== qsTr("Not installed")) && !b.busy
                                text: qsTr("Back to stable")
                                onClicked: b.restoreStable()
                            }
                        }
                    }
                }
            }
        }
    }
}
