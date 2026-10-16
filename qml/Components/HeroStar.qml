import QtQuick
import QtQuick.Effects

// The Lumen star as on the website: floating, golden glow, orbit rings with
// small moons. Hovering it speeds the rings up.
Item {
    id: hero
    property bool animated: true
    property real size: 160
    width: size * 1.9
    height: size * 1.9

    HoverHandler { id: hover }
    readonly property real speed: hover.hovered ? 2.5 : 1

    property real floatY: 0
    SequentialAnimation on floatY {
        running: hero.animated
        loops: Animation.Infinite
        NumberAnimation { to: -10; duration: 3000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 3000; easing.type: Easing.InOutSine }
    }

    Item {
        anchors.fill: parent
        transform: Translate { y: hero.floatY }

        RadialGlow {
            id: halo
            anchors.centerIn: parent
            width: hero.size * 2.1
            color: window.lumenGlow
            strength: 0.38
            SequentialAnimation on strength {
                running: hero.animated
                loops: Animation.Infinite
                NumberAnimation { to: 0.55; duration: 2400; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.34; duration: 2400; easing.type: Easing.InOutSine }
            }
        }

        Repeater {
            model: [
                { r: 0.62, c: window.lumenGlow, a: 0.55, d: 14000, moon: 5 },
                { r: 0.78, c: Qt.lighter(window.lumenAccent, 1.15), a: 0.35, d: 22000, moon: 4 },
                { r: 0.94, c: Qt.lighter(window.lumenAccent, 1.15), a: 0.18, d: 34000, moon: 3 }
            ]
            Item {
                id: orbit
                required property var modelData
                required property int index
                anchors.centerIn: parent
                width: hero.size * 2 * modelData.r
                height: width
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: orbit.modelData.c
                    opacity: orbit.modelData.a
                }
                Rectangle {
                    // moon on the ring
                    width: orbit.modelData.moon
                    height: width
                    radius: width / 2
                    color: orbit.modelData.c
                    x: orbit.width / 2 - width / 2
                    y: -height / 2
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: orbit.modelData.c
                        shadowBlur: 1.0
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }
                }
                property real angle: index * 120
                rotation: angle
                NumberAnimation on angle {
                    running: hero.animated
                    loops: Animation.Infinite
                    from: orbit.index * 120
                    to: orbit.index * 120 + (orbit.index % 2 ? -360 : 360)
                    duration: orbit.modelData.d / hero.speed
                }
            }
        }

        Image {
            id: star
            anchors.centerIn: parent
            source: "qrc:/Resources/lumen-star.svg"
            sourceSize.width: 512
            sourceSize.height: 512
            width: hero.size
            height: hero.size
            smooth: true
            mipmap: true
            scale: hover.hovered ? 1.06 : 1
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
            SequentialAnimation on rotation {
                running: hero.animated
                loops: Animation.Infinite
                NumberAnimation { to: 6; duration: 4000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -6; duration: 4000; easing.type: Easing.InOutSine }
            }
        }
    }
}
