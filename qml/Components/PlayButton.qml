import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Templates as T

// The big play button. variant:
//  "site"  - website primary style: purple gradient pill, breathing glow, light sweep
//  "pixel" - Minecraft style block button with bevels
//  "glass" - soft pastel pill for the Nebula design
T.Button {
    id: control
    property string subText: ""
    property string variant: "site"
    readonly property bool pixel: variant === "pixel"
    readonly property bool glass: variant === "glass"

    implicitHeight: contentItem.implicitHeight + (pixel ? 22 : 30)
    implicitWidth: contentItem.implicitWidth + 40

    scale: !enabled || pixel ? 1 : (down ? 0.97 : (hovered ? 1.04 : 1))
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

    background: Item {
        // ---- site: glowing gradient pill ------------------------------------
        Item {
            anchors.fill: parent
            visible: !control.pixel
            RadialGlow {
                id: glow
                anchors.centerIn: parent
                width: parent.width * 1.45
                // squashed into an oval that hugs the pill
                transform: Scale { origin.x: glow.width / 2; origin.y: glow.height / 2; yScale: 0.42 }
                color: window.lumenAccent
                strength: control.enabled ? glowStrength : 0
                property real glowStrength: 0.45
                SequentialAnimation on glowStrength {
                    running: control.enabled && control.visible
                    loops: Animation.Infinite
                    NumberAnimation { to: control.hovered ? 0.8 : 0.6; duration: 1600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.38; duration: 1600; easing.type: Easing.InOutSine }
                }
            }

            Item {
                id: face
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: !control.enabled ? "#3a3066" : Qt.lighter(window.lumenAccent, control.glass ? 1.12 : 1.25) }
                        GradientStop { position: 1.0; color: !control.enabled ? window.lumenSurfaceHigh : Qt.darker(window.lumenAccent, control.glass ? 1.0 : 1.08) }
                    }
                }
                // light sweep
                Rectangle {
                    visible: control.enabled
                    width: parent.height * 1.2
                    height: parent.height * 3
                    anchors.verticalCenter: parent.verticalCenter
                    rotation: 20
                    opacity: 0.55
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#00ffffff" }
                        GradientStop { position: 0.5; color: "#aaffffff" }
                        GradientStop { position: 1.0; color: "#00ffffff" }
                    }
                    SequentialAnimation on x {
                        running: control.enabled && control.visible && !control.pixel
                        loops: Animation.Infinite
                        PauseAnimation { duration: 2200 }
                        NumberAnimation { from: -face.height * 2; to: face.width + face.height; duration: 1100; easing.type: Easing.InOutQuad }
                    }
                }
            }
            Rectangle {
                id: faceMask
                anchors.fill: parent
                radius: height / 2
                visible: false
                layer.enabled: true
                layer.smooth: true
            }
            MultiEffect {
                anchors.fill: parent
                source: face
                maskEnabled: true
                maskSource: faceMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "transparent"
                border.width: 1
                border.color: control.enabled ? "#66ffffff" : window.lumenLine
            }
        }

        // ---- pixel: block button with light top and dark bottom bevel -------
        Rectangle {
            anchors.fill: parent
            visible: control.pixel
            color: "#0a0713"
            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                color: !control.enabled ? "#3a3066" : control.down ? Qt.darker(window.lumenAccent, 1.15) : (control.hovered ? Qt.lighter(window.lumenAccent, 1.15) : window.lumenAccent)
                Rectangle { width: parent.width; height: 4; color: "#59ffffff" }
                Rectangle { width: parent.width; height: 6; anchors.bottom: parent.bottom; color: "#59000000" }
            }
        }

        FocusBorder {
            visible: control.visualFocus
        }
    }

    contentItem: Item {
        implicitWidth: content.implicitWidth
        implicitHeight: Math.max(content.implicitHeight, 40)

        ColumnLayout {
            id: content
            spacing: control.text ? 1 : 5
            anchors.centerIn: parent
            anchors.verticalCenterOffset: control.pixel ? -1 : 0
            opacity: enabled ? 1.0 : 0.45
            Item {
                visible: control.text
                Layout.fillWidth: true
                implicitWidth: label.implicitWidth
                implicitHeight: label.implicitHeight
                Text { // hard pixel shadow
                    visible: control.pixel
                    x: 2; y: 2
                    text: label.text
                    font: label.font
                    color: "#73000000"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    id: label
                    width: parent.width
                    text: control.text
                    font.family: control.pixel ? "Silkscreen" : control.glass ? "Outfit" : "Sora"
                    font.pointSize: control.pixel ? 16 : 15
                    font.weight: control.pixel ? Font.Bold : Font.ExtraBold
                    font.letterSpacing: control.glass ? 0.5 : 1.5
                    color: !control.enabled ? "#ffffff" : window.lumenOn(control.pixel ? window.lumenAccent : Qt.lighter(window.lumenAccent, 1.15))
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
            MBusyIndicator {
                visible: !control.text
                implicitHeight: 10
                implicitWidth: 80
                Layout.alignment: Qt.AlignHCenter
                primaryColor: "#ffffff"
            }
            Text {
                visible: control.subText
                text: control.subText
                font.family: control.pixel ? "Pixelify Sans" : control.glass ? "Outfit" : "Inter"
                font.pointSize: 9
                font.weight: Font.DemiBold
                color: !control.enabled ? "#a39cbd" : window.lumenAlpha(window.lumenOn(Qt.lighter(window.lumenAccent, 1.15)), 0.75)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }
}
