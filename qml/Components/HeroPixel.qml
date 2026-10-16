import QtQuick

// "Pixel" design home: pixel star, blocky title, an item-tooltip info box and a block button
Item {
    id: hero
    property string playText
    property string playSubText
    property bool playEnabled
    property var modules: []
    property var servers: []
    property string versionName
    signal playClicked()

    Column {
        anchors.centerIn: parent
        spacing: 18

        PixelStar {
            id: pixelStar
            anchors.horizontalCenter: parent.horizontalCenter
            pixelSize: Math.max(5, Math.min(Math.round(hero.height / 60), 8))
            // hops like a dropped item
            property real hop: 0
            transform: Translate { y: -pixelStar.hop }
            SequentialAnimation on hop {
                running: window.lumenAnimate
                loops: Animation.Infinite
                NumberAnimation { to: 8; duration: 900; easing.type: Easing.OutQuad }
                NumberAnimation { to: 0; duration: 900; easing.type: Easing.InQuad }
            }
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: title.implicitWidth
            height: title.implicitHeight
            Text {
                x: 4; y: 4
                text: title.text
                font: title.font
                color: Qt.darker(window.lumenAccent, 2.2)
            }
            Text {
                id: title
                text: "MINECRAFT BEDROCK"
                color: "#ffffff"
                font.family: "Silkscreen"
                font.weight: Font.Bold
                font.pointSize: Math.max(18, Math.min(hero.width / 30, 26))
            }
        }

        // item tooltip look: dark purple box with a purple frame and a black outline
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(info.implicitWidth + 32, 300)
            height: info.implicitHeight + 22
            color: "#0a0713"
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                color: Qt.darker(window.lumenSky, 1.2)
                border.width: 3
                border.color: Qt.darker(window.lumenAccent, 1.8)
            }
            Column {
                id: info
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    text: hero.versionName ? "Version " + hero.versionName : "Minecraft Bedrock"
                    color: window.lumenGlow
                    font.family: "Pixelify Sans"
                    font.pointSize: 12
                    font.weight: Font.DemiBold
                }
                Text {
                    visible: hero.modules.length > 0
                    text: qsTr("%1 of %2 modules on").arg(hero.modules.filter(m => m.enabled).length).arg(hero.modules.length)
                    color: Qt.lighter(window.lumenSky, 5)
                    font.family: "Pixelify Sans"
                    font.pointSize: 10.5
                }
            }
        }

        PlayButton {
            anchors.horizontalCenter: parent.horizontalCenter
            variant: "pixel"
            width: 300
            text: hero.playText
            subText: ""
            enabled: hero.playEnabled
            onClicked: hero.playClicked()
        }
    }
}
