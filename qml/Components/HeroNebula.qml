import QtQuick

// "Nebula" design home: one floating glass card in the middle of the clouds
Item {
    id: hero
    property string playText
    property string playSubText
    property bool playEnabled
    property var modules: []
    property var servers: []
    property string versionName
    signal playClicked()

    property real floatY: 0
    SequentialAnimation on floatY {
        running: window.lumenAnimate
        loops: Animation.Infinite
        NumberAnimation { to: -6; duration: 3200; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 3200; easing.type: Easing.InOutSine }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        anchors.verticalCenterOffset: hero.floatY
        width: Math.min(420, hero.width - 40)
        height: cardColumn.implicitHeight + 60
        radius: 28
        color: "#61140e28"
        border.width: 1
        border.color: "#38ffffff"
        // soft highlight along the top edge of the glass
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#1fffffff" }
                GradientStop { position: 0.4; color: "#00ffffff" }
            }
        }

        Column {
            id: cardColumn
            anchors.centerIn: parent
            width: parent.width - 64
            spacing: 14
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 46
                height: 46
                RadialGlow { anchors.centerIn: parent; width: 110; color: window.lumenGlow; strength: 0.5 }
                Image {
                    anchors.fill: parent
                    source: "qrc:/Resources/lumen-star.svg"
                    sourceSize.width: 92
                    sourceSize.height: 92
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Lumen"
                color: "#ffffff"
                font.family: "Outfit"
                font.weight: Font.ExtraBold
                font.pointSize: 26
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: (hero.versionName ? qsTr("Minecraft Bedrock %1").arg(hero.versionName) : qsTr("Minecraft Bedrock"))
                      + (hero.modules.length > 0 ? " · " + qsTr("%1 modules on").arg(hero.modules.filter(m => m.enabled).length) : "")
                color: "#b8ffffff"
                font.family: "Outfit"
                font.pointSize: 10.5
            }
            PlayButton {
                width: parent.width
                variant: "glass"
                text: hero.playText
                subText: ""
                enabled: hero.playEnabled
                onClicked: hero.playClicked()
            }
        }
    }
}
