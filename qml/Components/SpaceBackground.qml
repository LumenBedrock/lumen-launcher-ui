import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

// Animated space backdrop like lumenclient.net: nebulae, twinkling stars,
// shooting stars and a ringed planet. mx/my (-0.5..0.5) shift the layers
// for a little parallax; everything sits behind the UI and takes no input.
Item {
    id: space
    property real mx: 0
    property real my: 0
    property bool animated: true
    property bool calm: false   // sub pages: dim the planet so it doesn't compete with the content
    property bool showPlanet: true
    property bool nebula: false   // "Nebula" design: colourful clouds instead of the purple glow
    // design colours
    property color sky: "#5a3fb0"
    property color accent: "#9b80ff"
    property color glow: "#ffd166"
    clip: true

    Behavior on mx { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
    Behavior on my { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }

    // Same deep purple sky as the website: a glow up right, near black below
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.darker(space.sky, space.nebula ? 6 : 3.6) }
            GradientStop { position: 1.0; color: Qt.darker(space.sky, space.nebula ? 8 : 6.5) }
        }
    }
    RadialGlow {
        visible: !space.nebula
        width: Math.max(space.width, space.height) * 1.5
        x: space.width * 0.72 - width / 2
        y: -height * 0.55
        color: space.sky
        strength: 0.55
    }

    // ---- Nebulae -----------------------------------------------------------
    Item {
        id: nebulae
        anchors.fill: parent
        transform: Translate { x: -space.mx * 18; y: -space.my * 12 }
        Repeater {
            model: space.nebula ? [
                { c: space.accent, x: 0.22, y: 0.30, s: 0.95, a: 0.55, d: 24000 },
                { c: "#46c8e6", x: 0.78, y: 0.62, s: 1.10, a: 0.45, d: 30000 },
                { c: space.sky, x: 0.60, y: 0.18, s: 0.85, a: 0.55, d: 27000 },
                { c: space.glow, x: 0.35, y: 0.85, s: 0.70, a: 0.30, d: 33000 }
            ] : [
                { c: space.accent, x: 0.12, y: 0.22, s: 0.75, a: 0.30, d: 26000 },
                { c: "#ff9ecf", x: 0.78, y: 0.12, s: 0.55, a: 0.16, d: 31000 },
                { c: space.glow, x: 0.86, y: 0.78, s: 0.50, a: 0.10, d: 23000 },
                { c: "#5a8cff", x: 0.35, y: 0.92, s: 0.70, a: 0.16, d: 35000 }
            ]
            RadialGlow {
                required property var modelData
                width: Math.max(space.width, space.height) * modelData.s
                x: space.width * modelData.x - width / 2 + drift
                y: space.height * modelData.y - height / 2
                color: modelData.c
                strength: modelData.a
                property real drift: 0
                SequentialAnimation on drift {
                    running: space.animated
                    loops: Animation.Infinite
                    NumberAnimation { to: 40; duration: modelData.d; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -40; duration: modelData.d; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // ---- Stars -------------------------------------------------------------
    // Positions come from a fixed pseudo-random sequence so they stay put on resize
    function rnd(i, k) {
        const v = Math.sin(i * 12.9898 + k * 78.233) * 43758.5453
        return v - Math.floor(v)
    }
    readonly property var starColors: ["#ffffff", "#ffe9a8", "#bb99ff", "#9ecfff"]

    Item {
        id: farStars
        anchors.fill: parent
        transform: Translate { x: -space.mx * 8; y: -space.my * 6 }
        Repeater {
            model: 150
            Rectangle {
                required property int index
                readonly property real size: 0.8 + space.rnd(index, 3) * 1.6
                x: space.rnd(index, 1) * space.width
                y: space.rnd(index, 2) * space.height
                width: size
                height: size
                radius: size / 2
                color: space.starColors[Math.floor(space.rnd(index, 4) * 4)]
                opacity: 0.25 + space.rnd(index, 5) * 0.55
                SequentialAnimation on opacity {
                    running: space.animated
                    loops: Animation.Infinite
                    PauseAnimation { duration: space.rnd(index, 6) * 4000 }
                    NumberAnimation { to: 0.1; duration: 1200 + space.rnd(index, 7) * 2600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.35 + space.rnd(index, 5) * 0.6; duration: 1200 + space.rnd(index, 8) * 2600; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // A few bright stars with a cross glint and a halo
    Item {
        anchors.fill: parent
        transform: Translate { x: -space.mx * 22; y: -space.my * 16 }
        Repeater {
            model: 14
            Item {
                id: glint
                required property int index
                readonly property real size: 10 + space.rnd(index, 13) * 14
                readonly property color tint: space.starColors[Math.floor(space.rnd(index, 14) * 4)]
                x: space.rnd(index, 11) * space.width - size / 2
                y: space.rnd(index, 12) * space.height - size / 2
                width: size
                height: size
                RadialGlow {
                    anchors.centerIn: parent
                    width: glint.size * 2.2
                    color: glint.tint
                    strength: 0.45
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: glint.size; height: 1.2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: glint.tint }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 1.2; height: glint.size
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: glint.tint }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 2.6; height: 2.6; radius: 1.3
                    color: "#ffffff"
                }
                SequentialAnimation on scale {
                    running: space.animated
                    loops: Animation.Infinite
                    PauseAnimation { duration: space.rnd(glint.index, 15) * 3000 }
                    NumberAnimation { to: 0.55; duration: 1600 + space.rnd(glint.index, 16) * 1800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 1600 + space.rnd(glint.index, 17) * 1800; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    // ---- Planet ------------------------------------------------------------
    Item {
        id: planet
        visible: space.showPlanet
        readonly property real size: Math.min(space.width, space.height) * 0.62
        width: size
        height: size
        x: space.width - size * 0.6 - space.mx * 30
        y: space.height - size * 0.58 - space.my * 20
        opacity: space.calm ? 0.35 : 1
        Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.InOutQuad } }

        RadialGlow {
            anchors.centerIn: parent
            width: planet.size * 1.9
            color: space.accent
            strength: 0.28
        }
        // ring, back half (behind the planet)
        Shape {
            id: ringBack
            anchors.centerIn: parent
            width: planet.size * 1.7
            height: planet.size * 0.42
            rotation: -18
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "#55c9b6ff"
                strokeWidth: planet.size * 0.03
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ringBack.width / 2; centerY: ringBack.height / 2
                    radiusX: ringBack.width / 2 - 4; radiusY: ringBack.height / 2 - 4
                    startAngle: 180; sweepAngle: 180
                }
            }
        }
        // body: banded gradient clipped to a circle
        Item {
            id: body
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.darker(space.accent, 1.35) }
                    GradientStop { position: 0.55; color: Qt.darker(space.accent, 2.4) }
                    GradientStop { position: 1.0; color: Qt.darker(space.sky, 4) }
                }
            }
            Repeater {
                model: 7
                Rectangle {
                    required property int index
                    width: body.width * 1.4
                    height: body.height * (0.05 + space.rnd(index, 21) * 0.08)
                    y: body.height * (0.12 + index * 0.12)
                    x: -body.width * 0.2 + body.bandShift * (index % 2 ? 1 : -1)
                    color: index % 3 === 0 ? space.glow : Qt.lighter(space.accent, 1.3)
                    opacity: 0.035 + space.rnd(index, 22) * 0.05
                    radius: height / 2
                }
            }
            property real bandShift: 0
            SequentialAnimation on bandShift {
                running: space.animated
                loops: Animation.Infinite
                NumberAnimation { to: 30; duration: 18000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -30; duration: 18000; easing.type: Easing.InOutSine }
            }
            // light from the upper left, shadow to the lower right
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#40ffffff" }
                    GradientStop { position: 0.45; color: "transparent" }
                    GradientStop { position: 1.0; color: "#a00d0a1c" }
                }
            }
        }
        Rectangle {
            id: bodyMask
            anchors.fill: parent
            radius: width / 2
            visible: false
            layer.enabled: true
            layer.smooth: true
        }
        MultiEffect {
            anchors.fill: parent
            source: body
            maskEnabled: true
            maskSource: bodyMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
        // golden rim light
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 1.5
            border.color: Qt.rgba(space.glow.r, space.glow.g, space.glow.b, 0.4)
        }
        // ring, front half
        Shape {
            id: ringFront
            anchors.centerIn: parent
            width: ringBack.width
            height: ringBack.height
            rotation: -18
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "#88c9b6ff"
                strokeWidth: planet.size * 0.03
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ringFront.width / 2; centerY: ringFront.height / 2
                    radiusX: ringFront.width / 2 - 4; radiusY: ringFront.height / 2 - 4
                    startAngle: 0; sweepAngle: 180
                }
            }
        }
    }

    // ---- Shooting stars ----------------------------------------------------
    Item {
        id: meteor
        width: 140
        height: 2
        opacity: 0
        rotation: 32
        transformOrigin: Item.Right
        Rectangle {
            anchors.fill: parent
            radius: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.85; color: "#c9b6ff" }
                GradientStop { position: 1.0; color: "#ffffff" }
            }
        }
        ParallelAnimation {
            id: meteorAnim
            property real sx: 0
            property real sy: 0
            NumberAnimation { target: meteor; property: "x"; from: meteorAnim.sx; to: meteorAnim.sx + 360; duration: 900; easing.type: Easing.InQuad }
            NumberAnimation { target: meteor; property: "y"; from: meteorAnim.sy; to: meteorAnim.sy + 225; duration: 900; easing.type: Easing.InQuad }
            SequentialAnimation {
                NumberAnimation { target: meteor; property: "opacity"; from: 0; to: 0.9; duration: 150 }
                PauseAnimation { duration: 450 }
                NumberAnimation { target: meteor; property: "opacity"; to: 0; duration: 300 }
            }
        }
        Timer {
            running: space.animated
            repeat: true
            interval: 5200
            onTriggered: {
                interval = 4000 + Math.random() * 7000
                meteorAnim.sx = Math.random() * space.width * 0.8 - 100
                meteorAnim.sy = Math.random() * space.height * 0.4 - 60
                meteorAnim.restart()
            }
        }
    }
}
