import QtQuick

// "Nebula" design: floating glass dock at the bottom
Item {
    id: nav
    property var navigation
    readonly property int reserveLeft: 0
    readonly property int reserveTop: 0
    readonly property int reserveBottom: 84

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        width: tabs.width + 12
        height: tabs.height + 12
        radius: 20
        color: window.lumenAlpha(window.lumenNav, 0.45)
        border.width: 1
        border.color: "#2effffff"
        Row {
            id: tabs
            anchors.centerIn: parent
            spacing: 6
            Repeater {
                model: nav.navigation.pages
                Rectangle {
                    id: tab
                    required property var modelData
                    readonly property bool active: nav.navigation.currentIndex === modelData.index
                    width: tabText.implicitWidth + 36
                    height: 44
                    radius: 14
                    color: active ? window.lumenAlpha(window.lumenNavText, 0.16) : (tabHover.hovered ? window.lumenAlpha(window.lumenNavText, 0.08) : "transparent")
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Text {
                        id: tabText
                        anchors.centerIn: parent
                        text: tab.modelData.label
                        color: tab.active ? window.lumenNavText : window.lumenNavTextDim
                        font.family: "Outfit"
                        font.pointSize: 10.5
                        font.weight: tab.active ? Font.DemiBold : Font.Medium
                    }
                    HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: nav.navigation.updateIndex(tab.modelData.index) }
                }
            }
        }
    }
}
