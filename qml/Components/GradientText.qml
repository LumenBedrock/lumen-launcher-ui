import QtQuick
import QtQuick.Effects

// Text filled with the website's purple to gold gradient; the colours slowly drift
Item {
    id: root
    property alias text: label.text
    property alias font: label.font
    property color from: Qt.lighter(window.lumenAccent, 1.15)
    property color to: window.lumenGlow
    property bool animated: true

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        visible: false
        layer.enabled: true
        color: "white"
    }
    Rectangle {
        id: fill
        anchors.fill: label
        visible: false
        layer.enabled: true
        property real shift: 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.from }
            GradientStop { position: Math.max(0.05, Math.min(0.95, 0.5 + fill.shift)); color: Qt.tint(root.from, Qt.rgba(1, 0.82, 0.4, 0.5)) }
            GradientStop { position: 1.0; color: root.to }
        }
        SequentialAnimation on shift {
            running: root.animated
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 3500; easing.type: Easing.InOutSine }
            NumberAnimation { to: -0.3; duration: 3500; easing.type: Easing.InOutSine }
        }
    }
    MultiEffect {
        anchors.fill: label
        source: fill
        maskEnabled: true
        maskSource: label
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
