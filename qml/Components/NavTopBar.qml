import QtQuick
import QtQuick.Layouts

// "Classic" design: top bar like lumenclient.net (brand left, links and Discord right)
Item {
    id: nav
    property var navigation
    readonly property int reserveLeft: 0
    readonly property int reserveTop: bar.height
    readonly property int reserveBottom: 0

    Rectangle {
        id: bar
        width: parent.width
        height: 60
        color: window.lumenAlpha(window.lumenNav, 0.75)
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: "#2ebb99ff"
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 64 // room for the design picker
            spacing: 10
            Image {
                source: "qrc:/Resources/lumen-star.svg"
                sourceSize.width: 56
                sourceSize.height: 56
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
            }
            Text {
                text: "Lumen"
                color: window.lumenNavText
                font.family: "Sora"
                font.weight: Font.Bold
                font.pointSize: 14
            }
            Item { Layout.fillWidth: true }
            Repeater {
                model: nav.navigation.pages
                Text {
                    required property var modelData
                    readonly property bool active: nav.navigation.currentIndex === modelData.index
                    text: modelData.label
                    color: active || linkHover.hovered ? window.lumenNavText : window.lumenNavTextDim
                    font.pointSize: 10.5
                    font.weight: active ? Font.DemiBold : Font.Medium
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Behavior on color { ColorAnimation { duration: 150 } }
                    HoverHandler { id: linkHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: nav.navigation.updateIndex(modelData.index) }
                    Rectangle { // gold underline on the active link
                        anchors.top: parent.bottom
                        anchors.topMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.active ? parent.width : 0
                        height: 2
                        radius: 1
                        color: window.lumenGlow
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }
                }
            }
            Rectangle {
                Layout.leftMargin: 8
                Layout.preferredHeight: 34
                Layout.preferredWidth: discordText.implicitWidth + 32
                radius: height / 2
                color: discordHover.hovered ? "#6b77ff" : "#5865f2"
                Behavior on color { ColorAnimation { duration: 150 } }
                Text {
                    id: discordText
                    anchors.centerIn: parent
                    text: "Discord"
                    color: "#ffffff"
                    font.pointSize: 10
                    font.weight: Font.DemiBold
                }
                HoverHandler { id: discordHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Qt.openUrlExternally("https://discord.gg/PynnPrJ8H3") }
            }
        }
    }
}
