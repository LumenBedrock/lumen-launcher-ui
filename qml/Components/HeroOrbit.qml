import QtQuick

// "Orbit" design home: big headline on the left; the pages orbit below (NavArc)
Item {
    id: hero
    property string playText
    property string playSubText
    property bool playEnabled
    property var modules: []
    property var servers: []
    property string versionName
    signal playClicked()

    readonly property real titleSize: Math.max(22, Math.min(width / 21, 36))

    Column {
        x: 36
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -10
        width: Math.min(hero.width - 72, 520)
        spacing: 14

        Text {
            text: qsTr("Minecraft Bedrock,")
            color: "#ece8f8"
            font.family: "Sora"
            font.weight: Font.ExtraBold
            font.pointSize: hero.titleSize
        }
        GradientText {
            text: qsTr("in orbit.")
            font.family: "Sora"
            font.weight: Font.ExtraBold
            font.pointSize: hero.titleSize
            animated: window.lumenAnimate
        }
        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: [hero.versionName,
                   hero.modules.length > 0 ? qsTr("%1 of %2 modules on").arg(hero.modules.filter(m => m.enabled).length).arg(hero.modules.length) : ""]
                  .filter(s => s).join(" · ")
            color: "#a39cbd"
            font.pointSize: 11
        }
        Row {
            spacing: 12
            topPadding: 6
            PlayButton {
                width: Math.max(implicitWidth, 200)
                text: hero.playText
                subText: hero.playSubText
                enabled: hero.playEnabled
                onClicked: hero.playClicked()
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 3
                height: 50
                width: discordText.implicitWidth + 40
                radius: height / 2
                color: discordHover.hovered ? "#14bb99ff" : "transparent"
                border.width: 1
                border.color: "#40bb99ff"
                Text {
                    id: discordText
                    anchors.centerIn: parent
                    text: "Discord"
                    color: "#ece8f8"
                    font.pointSize: 10.5
                    font.weight: Font.DemiBold
                }
                HoverHandler { id: discordHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Qt.openUrlExternally("https://discord.gg/PynnPrJ8H3") }
            }
        }
    }
}
