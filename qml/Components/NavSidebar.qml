import QtQuick
import QtQuick.Layouts

// "Sun" design: glass sidebar with the gradient LUMEN wordmark
Item {
    id: nav
    property var navigation
    readonly property int reserveLeft: bar.width
    readonly property int reserveTop: 0
    readonly property int reserveBottom: 0

    Rectangle {
        id: bar
        height: parent.height
        width: sidebarLayout.width
        gradient: Gradient {
            GradientStop { position: 0.0; color: window.lumenAlpha(window.lumenNav, 0.72) }
            GradientStop { position: 1.0; color: window.lumenAlpha(Qt.darker(window.lumenNav, 1.9), 0.82) }
        }
        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00bb99ff" }
                GradientStop { position: 0.3; color: "#55bb99ff" }
                GradientStop { position: 1.0; color: "#14bb99ff" }
            }
        }
        Text {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            text: LAUNCHER_VERSION_NAME ? (nav.navigation.useWideLayout ? "Lumen " : "v") + LAUNCHER_VERSION_NAME : ""
            color: window.lumenNavTextDim
            font.pointSize: 8.5
            font.weight: Font.Medium
        }
        ColumnLayout {
            id: sidebarLayout
            anchors.top: parent.top
            anchors.topMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2
            RowLayout {
                Layout.leftMargin: 16
                Layout.bottomMargin: 20
                spacing: 10
                Item {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    RadialGlow {
                        anchors.centerIn: parent
                        width: 70
                        color: window.lumenGlow
                        strength: 0.35
                    }
                    Image {
                        anchors.fill: parent
                        source: "qrc:/Resources/lumen-icon.svg"
                        sourceSize.width: 68
                        sourceSize.height: 68
                        HoverHandler { id: brandHover }
                        rotation: brandHover.hovered ? 20 : 0
                        Behavior on rotation { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                    }
                }
                GradientText {
                    visible: nav.navigation.useWideLayout
                    text: "LUMEN"
                    font.family: "Sora"
                    font.weight: Font.ExtraBold
                    font.pointSize: 14
                    font.letterSpacing: 3
                    from: window.lumenGlow
                    to: Qt.lighter(window.lumenAccent, 1.15)
                    animated: window.lumenAnimate
                }
            }
            Repeater {
                model: nav.navigation.pages
                MSideBarItem {
                    required property var modelData
                    text: modelData.label
                    iconSource: modelData.icon
                    showText: nav.navigation.useWideLayout
                    checked: nav.navigation.currentIndex === modelData.index
                    onClicked: nav.navigation.updateIndex(modelData.index)
                }
            }
            MSideBarItem {
                visible: launcherSettings.showExitButton
                text: qsTr("Exit")
                iconSource: "qrc:/Resources/icon-exit.png"
                showText: nav.navigation.useWideLayout
                onClicked: Qt.quit()
                checked: false
            }
        }
    }
}
