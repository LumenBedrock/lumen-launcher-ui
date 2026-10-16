import QtQuick
import QtQuick.Controls

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
    signal renameServer(string key, string newName)
    signal editServer(string key)
    signal removeServers(var keys)
    property var similarOf: null // function(key) -> [{key, label, host, relation}]
    property var menuSimilar: []
    property bool confirmRemove: false
    property bool editLocked: false // the game is running: profiles are read-only
    property var menuServer: null
    property var angleStore: ({}) // orbit index -> last angle (not reactive on purpose)

    readonly property real sunSize: Math.max(56, Math.min(height * 0.15, 90))
    readonly property real cxPos: width / 2
    // the solar system lives above the play button area at the bottom
    readonly property real cyPos: (height - 160) / 2 + 4
    readonly property real maxOrbit: Math.max(sunSize * 1.4, Math.min(cyPos - 14, width / 2 - 220)) // stays inside the window incl. the planet label

    HeroStar {
        x: hero.cxPos - width / 2
        y: hero.cyPos - height / 2
        size: hero.sunSize
        animated: window.lumenAnimate
    }

    Repeater {
        model: hero.servers.slice(0, 8)
        Item {
            id: orbit
            required property var modelData
            required property int index
            readonly property int count: Math.min(hero.servers.length, 8)
            // up to 4 servers keep the classic spacing; more are spread evenly from 50% to 100% of the outer orbit
            readonly property real r: Math.max(hero.sunSize * 1.2, hero.maxOrbit * (count <= 4 ? 0.55 + index * 0.15 : 0.5 + 0.5 * index / (count - 1)))
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
                border.color: Qt.rgba(0.71, 0.61, 1, Math.max(0.06, 0.26 - orbit.index * 0.05))
            }

            // the model is rebuilt on every profile change (rename, join...): carry each planet's angle over
            readonly property real startAngle: hero.angleStore[orbit.index] !== undefined ? hero.angleStore[orbit.index] : (orbit.index < 4 ? [-35, 150, 60, 250][orbit.index] : (orbit.index * 137.5 - 35) % 360)
            property real angle: startAngle
            Component.onDestruction: hero.angleStore[orbit.index] = orbit.angle
            NumberAnimation on angle {
                running: window.lumenAnimate
                paused: planetHover.hovered
                loops: Animation.Infinite
                from: orbit.startAngle
                to: orbit.startAngle + 360
                duration: 60000 + orbit.index * 30000
            }
            readonly property real rad: angle * Math.PI / 180

            // planet with its name, kept upright while it travels round
            Item {
                id: body
                readonly property real size: Math.max(12, 22 - orbit.index * 2)
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
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: hero.joinEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    readonly property bool hovered: containsMouse
                    onClicked: function (mouse) {
                        if (mouse.button === Qt.RightButton) {
                            hero.menuServer = orbit.modelData
                            const pt = mapToItem(hero, mouse.x, mouse.y)
                            planetMenu.x = Math.max(8, Math.min(hero.width - planetMenu.width - 8, pt.x))
                            planetMenu.y = Math.max(8, Math.min(hero.height - planetMenu.height - 8, pt.y))
                            nameField.text = orbit.modelData.name
                            hero.confirmRemove = false
                            hero.menuSimilar = hero.similarOf ? hero.similarOf(orbit.modelData.key) : []
                            planetMenu.open()
                        } else if (hero.joinEnabled) {
                            hero.joinServer(orbit.modelData)
                        }
                    }
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

    // right-click on a planet: rename it, or jump to its modules / texture packs on the Servers page
    Popup {
        id: planetMenu
        width: 260
        padding: 12
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle {
            color: window.lumenSurface
            border.color: window.lumenLine
            radius: 12
        }
        contentItem: Column {
            spacing: 8
            Text {
                width: parent.width
                text: hero.menuServer ? hero.menuServer.host : ""
                color: window.lumenMuted
                font.pointSize: 9
                elide: Text.ElideRight
            }
            MTextField {
                id: nameField
                width: parent.width
                placeholderText: qsTr("Server name")
                enabled: !hero.editLocked
                onAccepted: renameBtn.clicked()
            }
            MButton {
                id: renameBtn
                width: parent.width
                text: hero.editLocked ? qsTr("Close the game to rename") : qsTr("Rename")
                enabled: !hero.editLocked && nameField.text.trim() !== "" && hero.menuServer !== null
                onClicked: {
                    hero.renameServer(hero.menuServer.key, nameField.text)
                    planetMenu.close()
                }
            }
            Text {
                visible: hero.menuSimilar.length > 0
                width: parent.width
                wrapMode: Text.WordWrap
                color: window.lumenMuted
                font.pointSize: 9
                text: {
                    var lines = []
                    for (var i = 0; i < hero.menuSimilar.length && i < 6; i++)
                        lines.push(hero.menuSimilar[i].label + " (" + hero.menuSimilar[i].relation + ")")
                    return qsTr("Similar: ") + lines.join(", ")
                }
            }
            MButton {
                id: dupBtn
                readonly property var dupKeys: hero.menuSimilar.filter(function (s) { return s.relation === "same address" }).map(function (s) { return s.key })
                visible: dupKeys.length > 0
                width: parent.width
                text: qsTr("Remove %n duplicate(s) of this address", "", dupKeys.length)
                enabled: !hero.editLocked
                onClicked: {
                    hero.removeServers(dupKeys)
                    planetMenu.close()
                }
            }
            MButton {
                width: parent.width
                text: hero.confirmRemove ? qsTr("Click again to remove this server") : qsTr("Remove this server")
                enabled: !hero.editLocked && hero.menuServer !== null
                onClicked: {
                    if (!hero.confirmRemove) {
                        hero.confirmRemove = true
                        return
                    }
                    hero.removeServers([hero.menuServer.key])
                    planetMenu.close()
                }
            }
            MButton {
                width: parent.width
                text: qsTr("Modules and texture packs")
                enabled: hero.menuServer !== null
                onClicked: {
                    hero.editServer(hero.menuServer.key)
                    planetMenu.close()
                }
            }
        }
    }
}
