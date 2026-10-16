import QtQuick
import QtQuick.Shapes

// Soft round glow that fades to transparent at its edge (nebulae, halos)
Shape {
    id: glow
    property color color: "#7c5cff"
    property real strength: 0.35

    width: 400
    height: width
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: -1
        fillGradient: RadialGradient {
            centerX: glow.width / 2
            centerY: glow.height / 2
            centerRadius: glow.width / 2
            focalX: centerX
            focalY: centerY
            GradientStop { position: 0.0; color: Qt.rgba(glow.color.r, glow.color.g, glow.color.b, glow.strength) }
            GradientStop { position: 0.45; color: Qt.rgba(glow.color.r, glow.color.g, glow.color.b, glow.strength * 0.35) }
            GradientStop { position: 1.0; color: Qt.rgba(glow.color.r, glow.color.g, glow.color.b, 0) }
        }
        startX: 0; startY: 0
        PathLine { x: glow.width; y: 0 }
        PathLine { x: glow.width; y: glow.height }
        PathLine { x: 0; y: glow.height }
        PathLine { x: 0; y: 0 }
    }
}
