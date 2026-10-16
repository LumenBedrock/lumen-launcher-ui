import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Templates as T

T.Button {
    id: control
    property alias iconSource: icon.source
    property alias showText: text.visible

    implicitHeight: 48
    implicitWidth: implicitContentWidth

    background: Item {
        // glowing pill behind the active item, a faint one on hover
        Rectangle {
            id: pill
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            radius: 12
            opacity: control.checked ? 1 : (control.hovered ? 0.55 : 0)
            Behavior on opacity { NumberAnimation { duration: 180 } }
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: window.lumenAlpha(window.lumenAccent, control.checked ? 0.32 : 0.16) }
                GradientStop { position: 1.0; color: window.lumenAlpha(window.lumenAccent, control.checked ? 0.09 : 0.05) }
            }
            border.width: 1
            border.color: window.lumenAlpha(Qt.lighter(window.lumenAccent, 1.15), control.checked ? 0.38 : 0.16)
        }
        Rectangle {
            id: indicatorBar
            width: 3
            height: control.checked ? 24 : 0
            radius: 2
            color: window.lumenGlow
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 2
            Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            layer.enabled: control.checked
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: window.lumenGlow
                shadowBlur: 0.8
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }
        FocusBorder {
            visible: control.visualFocus
        }
    }

    contentItem: RowLayout {
        height: control.height
        // the row slides a little to the right on hover
        transform: Translate {
            x: control.hovered && !control.checked ? 3 : 0
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        Image {
            id: icon
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            source: iconSource
            smooth: true
            sourceSize.width: 60
            sourceSize.height: 60
            fillMode: Image.PreserveAspectFit
            Layout.leftMargin: 20
            Layout.rightMargin: 16
            opacity: control.checked || control.hovered ? 1 : 0.75
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }

        Text {
            id: text
            color: control.checked || control.hovered ? window.lumenNavText : window.lumenNavTextDim
            Behavior on color { ColorAnimation { duration: 180 } }
            text: control.text
            font.pointSize: 10.5
            font.weight: control.checked ? Font.DemiBold : Font.Medium
            verticalAlignment: Text.AlignVCenter
            Layout.fillHeight: true
            Layout.rightMargin: 40
        }
    }
}
