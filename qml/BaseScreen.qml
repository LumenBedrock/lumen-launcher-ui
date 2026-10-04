import QtQuick
import QtQuick.Window
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.platform
import "Components"
import io.mrarm.mcpelauncher 1.0

ColumnLayout {
    id: rowLayout
    spacing: 0

    property alias headerContent: baseHeader.content
    property bool showHeader: true

    BaseHeader {
        id: baseHeader
        visible: rowLayout.showHeader
        Layout.fillWidth: true
        title: qsTr("Lumen Launcher")
        subtitle: LAUNCHER_VERSION_NAME ? qsTr("Version %1").arg(LAUNCHER_VERSION_NAME) : ""
    }
}
