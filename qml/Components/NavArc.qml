import QtQuick

// "Orbit" design: pages are planets on a wide orbit along the bottom, the Lumen sun at its left end
Item {
    id: nav
    property var navigation
    readonly property int reserveLeft: 0
    readonly property int reserveTop: 0
    readonly property int reserveBottom: 136

    // the orbit: a huge circle whose top just shows above the bottom edge
    readonly property real radius: Math.max(width * 1.1, 700)
    readonly property real cx: width * 0.5
    readonly property real cy: height + radius - 118
    function arcY(x) {
        const dx = x - cx
        return cy - Math.sqrt(Math.max(0, radius * radius - dx * dx))
    }

    Rectangle {
        x: nav.cx - nav.radius
        y: nav.cy - nav.radius
        width: nav.radius * 2
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: window.lumenAlpha(window.lumenNav, 0.35)
    }
    Rectangle {
        x: nav.cx - nav.radius + 60
        y: nav.cy - nav.radius + 60
        width: nav.radius * 2 - 120
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: window.lumenAlpha(window.lumenNav, 0.12)
    }

    // the sun
    Item {
        x: 46 - width / 2
        y: nav.arcY(46) - height / 2
        width: 40
        height: 40
        RadialGlow { anchors.centerIn: parent; width: 130; color: window.lumenGlow; strength: 0.55 }
        Image {
            anchors.fill: parent
            source: "qrc:/Resources/lumen-star.svg"
            sourceSize.width: 80
            sourceSize.height: 80
            RotationAnimation on rotation {
                running: window.lumenAnimate
                loops: Animation.Infinite
                from: 0; to: 360
                duration: 40000
            }
        }
    }

    Repeater {
        model: nav.navigation.pages
        Item {
            id: planet
            required property var modelData
            required property int index
            readonly property bool active: nav.navigation.currentIndex === modelData.index
            readonly property var tints: [["#e3d6ff", "#8f6dff"], ["#c9e7ff", "#5fa8d3"], ["#ffd0e0", "#e07a9e"], ["#d0ffe9", "#4fbf8f"], ["#fff1c9", "#c49a2c"]]
            readonly property real px: nav.width * (0.22 + index * 0.15)
            readonly property real size: active ? 30 : 22 - index
            // planets bob gently along the orbit
            property real bob: 0
            SequentialAnimation on bob {
                running: window.lumenAnimate
                loops: Animation.Infinite
                PauseAnimation { duration: planet.index * 400 }
                NumberAnimation { to: 3; duration: 2200; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 2200; easing.type: Easing.InOutSine }
            }
            x: px - width / 2
            y: nav.arcY(px) - size / 2 - bob
            width: Math.max(label.implicitWidth, size) + 10
            height: size + 26

            RadialGlow {
                visible: planet.active
                anchors.horizontalCenter: parent.horizontalCenter
                y: planet.size / 2 - height / 2
                width: 90
                color: planet.tints[planet.index % 5][1]
                strength: 0.7
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: planet.size
                height: width
                radius: width / 2
                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: planet.tints[planet.index % 5][0] }
                    GradientStop { position: 1.0; color: planet.tints[planet.index % 5][1] }
                }
                scale: hover.hovered && !planet.active ? 1.18 : 1
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            }
            Text {
                id: label
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                text: planet.modelData.label
                color: planet.active ? "#ffffff" : "#a39cbd"
                font.pointSize: 10
                font.weight: planet.active ? Font.DemiBold : Font.Medium
            }
            HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: nav.navigation.updateIndex(planet.modelData.index) }
        }
    }
}
