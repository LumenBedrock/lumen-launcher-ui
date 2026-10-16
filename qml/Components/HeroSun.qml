import QtQuick

// "Sun" design home: the Lumen star as a sun, your servers as planets on its orbits
Item {
    id: hero
    property string playText
    property string playSubText
    property bool playEnabled
    property bool joinEnabled: playEnabled // quick join also needs a Google login
    property var modules: []
    property var servers: []   // [{name, host, port}]
    property string versionName
    signal playClicked()
    signal joinServer(var server)

    readonly property real sunSize: Math.max(56, Math.min(height * 0.15, 90))
    readonly property real cxPos: width / 2
    // the solar system lives above the play button area at the bottom
    readonly property real cyPos: (height - 130) / 2 + 6
    readonly property real maxOrbit: Math.min(cyPos - 8, width / 2 - 150)

    HeroStar {
        x: hero.cxPos - width / 2
        y: hero.cyPos - height / 2
        size: hero.sunSize
        animated: window.lumenAnimate
    }

    Repeater {
        model: hero.servers.slice(0, 4)
        Item {
            id: orbit
            required property var modelData
            required property int index
            readonly property real r: Math.max(hero.sunSize * 1.2, hero.maxOrbit * (0.55 + index * 0.15))
            readonly property var tints: [["#ffe6a0", "#e0a83a"], ["#c9e7ff", "#5fa8d3"], ["#ffd0e0", "#e07a9e"], ["#d0ffe9", "#4fbf8f"]]
            x: hero.cxPos - r
            y: hero.cyPos - r
            width: r * 2
            height: r * 2

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0.71, 0.61, 1, 0.26 - orbit.index * 0.05)
            }

            property real angle: [-35, 150, 60, 250][orbit.index % 4]
            NumberAnimation on angle {
                running: window.lumenAnimate
                paused: planetHover.hovered
                loops: Animation.Infinite
                from: [-35, 150, 60, 250][orbit.index % 4]
                to: [-35, 150, 60, 250][orbit.index % 4] + 360
                duration: 60000 + orbit.index * 30000
            }
            readonly property real rad: angle * Math.PI / 180

            // planet with its name, kept upright while it travels round
            Item {
                id: body
                readonly property real size: 22 - orbit.index * 2
                x: orbit.r + Math.cos(orbit.rad) * orbit.r - size / 2
                y: orbit.r + Math.sin(orbit.rad) * orbit.r - size / 2
                width: size
                height: size
                RadialGlow {
                    anchors.centerIn: parent
                    width: body.size * 3.2
                    color: orbit.tints[orbit.index % 4][1]
                    strength: planetHover.hovered ? 0.8 : 0.45
                }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: orbit.tints[orbit.index % 4][0] }
                        GradientStop { position: 1.0; color: orbit.tints[orbit.index % 4][1] }
                    }
                    scale: planetHover.hovered ? 1.25 : 1
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                }
                Row {
                    x: body.size + 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: orbit.modelData.name
                        color: planetHover.hovered ? "#ffffff" : "#c9c3e3"
                        font.pointSize: 9.5
                        font.weight: Font.DemiBold
                        style: Text.Outline
                        styleColor: "#990d0a1c"
                    }
                    // quick join hint on hover
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: planetHover.hovered
                        width: joinText.implicitWidth + 18
                        height: 22
                        radius: 11
                        color: hero.joinEnabled ? window.lumenAccent : "#3a3066"
                        Text {
                            id: joinText
                            anchors.centerIn: parent
                            text: hero.joinEnabled ? qsTr("Join ▸") : (hero.playEnabled ? qsTr("Sign in first") : qsTr("Not ready"))
                            color: hero.joinEnabled ? window.lumenOn(window.lumenAccent) : "#a39cbd"
                            font.pointSize: 8.5
                            font.weight: Font.Bold
                        }
                    }
                }
                MouseArea {
                    id: planetHover
                    // the planet plus its label
                    x: -6
                    y: -6
                    width: body.size + 12 + 8 + 200
                    height: body.size + 12
                    hoverEnabled: true
                    cursorShape: hero.joinEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    readonly property bool hovered: containsMouse
                    onClicked: if (hero.joinEnabled) hero.joinServer(orbit.modelData)
                }
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        spacing: 10
        PlayButton {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(implicitWidth, 240)
            text: hero.playText
            subText: hero.playSubText
            enabled: hero.playEnabled
            onClicked: hero.playClicked()
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: hero.servers.length > 0 ? qsTr("Click a planet to join that server right away") : qsTr("Join a server in game and it appears here as a planet")
            color: "#a39cbd"
            font.pointSize: 9
        }
    }
}
