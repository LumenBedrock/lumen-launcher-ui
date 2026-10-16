import QtQuick

// "Pixel" design: dark header with the pixel star, pages as a Minecraft hotbar at the bottom
Item {
    id: nav
    property var navigation
    readonly property int reserveLeft: 0
    readonly property int reserveTop: header.height
    readonly property int reserveBottom: 104

    Rectangle {
        id: header
        width: parent.width
        height: 52
        color: window.lumenNav
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 4; color: "#0a0713" }
        Row {
            x: 22
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            spacing: 10
            PixelStar { pixelSize: 2; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: "LUMEN"
                color: window.lumenGlow
                font.family: "Silkscreen"
                font.weight: Font.Bold
                font.pointSize: 14
                font.letterSpacing: 1
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 66 // room for the design picker
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -2
            text: LAUNCHER_VERSION_NAME ? "LAUNCHER " + LAUNCHER_VERSION_NAME : ""
            color: Qt.lighter(window.lumenSky, 4.5)
            font.family: "Silkscreen"
            font.pointSize: 8.5
        }
    }

    // hotbar
    Rectangle {
        id: hotbar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: slots.width + 16
        height: slots.height + 16
        color: Qt.darker(window.lumenNav, 1.7)
        Row {
            id: slots
            anchors.centerIn: parent
            Repeater {
                model: nav.navigation.pages
                Rectangle {
                    id: slot
                    required property var modelData
                    readonly property bool active: nav.navigation.currentIndex === modelData.index
                    width: 60
                    height: 60
                    color: active ? Qt.lighter(window.lumenSky, 1.6) : (slotHover.hovered ? Qt.lighter(window.lumenSky, 1.4) : Qt.lighter(window.lumenSky, 1.25))
                    border.width: 4
                    border.color: active ? "#ffffff" : Qt.lighter(window.lumenSky, 2.0)
                    Image {
                        anchors.centerIn: parent
                        source: slot.modelData.icon
                        sourceSize.width: 56
                        sourceSize.height: 56
                        width: 28
                        height: 28
                        smooth: false
                    }
                    HoverHandler { id: slotHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: nav.navigation.updateIndex(slot.modelData.index) }
                    // item tooltip above the selected (or hovered) slot, like in game
                    Rectangle {
                        visible: slot.active || slotHover.hovered
                        anchors.bottom: parent.top
                        anchors.bottomMargin: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: tip.implicitWidth + 16
                        height: tip.implicitHeight + 6
                        color: Qt.darker(window.lumenSky, 1.2)
                        border.width: 2
                        border.color: Qt.darker(window.lumenAccent, 1.8)
                        z: 2
                        Text {
                            id: tip
                            anchors.centerIn: parent
                            text: slot.modelData.label
                            color: "#ffffff"
                            font.family: "Silkscreen"
                            font.pointSize: 9
                        }
                    }
                }
            }
        }
    }
}
