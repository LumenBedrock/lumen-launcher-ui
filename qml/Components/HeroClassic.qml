import QtQuick
import QtQuick.Layouts

// "Classic" design home: centred hero like the lumenclient.net front page
Item {
    id: hero
    property string playText
    property string playSubText
    property bool playEnabled
    property var modules: []
    property var servers: []
    property string versionName
    signal playClicked()
    signal openVersions()

    readonly property real titleSize: Math.max(20, Math.min(width / 22, 34))

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -10
        spacing: 14

        Item { // star tile with a golden halo
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 84
            Layout.preferredHeight: 84
            RadialGlow { anchors.centerIn: parent; width: 190; color: window.lumenGlow; strength: 0.4 }
            Rectangle {
                anchors.fill: parent
                radius: 20
                color: "#1d1640"
                border.width: 1
                border.color: "#40bb99ff"
            }
            Image {
                anchors.centerIn: parent
                source: "qrc:/Resources/lumen-star.svg"
                sourceSize.width: 120
                sourceSize.height: 120
                width: 50
                height: 50
                SequentialAnimation on rotation {
                    running: window.lumenAnimate
                    loops: Animation.Infinite
                    NumberAnimation { to: 8; duration: 3500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -8; duration: 3500; easing.type: Easing.InOutSine }
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            height: 28
            width: pill.implicitWidth + 28
            radius: height / 2
            color: "transparent"
            border.width: 1
            border.color: "#40bb99ff"
            Text {
                id: pill
                anchors.centerIn: parent
                text: LAUNCHER_VERSION_NAME ? qsTr("Lumen %1").arg(LAUNCHER_VERSION_NAME) : "Lumen"
                color: Qt.lighter(window.lumenAccent, 1.15)
                font.pointSize: 9.5
            }
        }

        Column {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Minecraft Bedrock,")
                color: "#ece8f8"
                font.family: "Sora"
                font.weight: Font.ExtraBold
                font.pointSize: hero.titleSize
            }
            GradientText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("ready on Linux.")
                font.family: "Sora"
                font.weight: Font.ExtraBold
                font.pointSize: hero.titleSize
                animated: window.lumenAnimate
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            spacing: 14
            PlayButton {
                width: Math.max(implicitWidth, 200)
                text: hero.playText
                subText: hero.playSubText
                enabled: hero.playEnabled
                onClicked: hero.playClicked()
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                height: 50
                width: profileText.implicitWidth + 40
                radius: height / 2
                color: profileHover.hovered ? "#14bb99ff" : "transparent"
                border.width: 1
                border.color: "#40bb99ff"
                Text {
                    id: profileText
                    anchors.centerIn: parent
                    text: qsTr("Versions & profiles")
                    color: "#ece8f8"
                    font.pointSize: 10.5
                    font.weight: Font.DemiBold
                }
                HoverHandler { id: profileHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: hero.openVersions() }
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            spacing: 30
            visible: hero.modules.length > 0
            Repeater {
                model: [
                    [hero.modules.length, qsTr("modules")],
                    [hero.modules.filter(m => m.enabled).length, qsTr("switched on")],
                    [hero.servers.length, qsTr("server profiles")]
                ]
                Text {
                    required property var modelData
                    textFormat: Text.StyledText
                    text: "<b><font color=\"#ece8f8\">" + modelData[0] + "</font></b> " + modelData[1]
                    color: "#a39cbd"
                    font.pointSize: 10
                }
            }
        }
    }
}
