import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

T.Button {
    id: control
    property string subText: ""

    implicitHeight: contentItem.implicitHeight + 36
    implicitWidth: contentItem.implicitWidth + 30

    background: Rectangle {
        id: buttonBackground
        radius: 12
        border.width: 1
        border.color: control.enabled ? "#a98bff" : "#4a3d80"
        gradient: Gradient {
            GradientStop { position: 0.0; color: control.enabled ? "#8a63f2" : "#3a3066" }
            GradientStop { position: 1.0; color: control.enabled ? "#5b3fc4" : "#2a2250" }
        }
        Rectangle {
            id: backgroundOverlay
            anchors.fill: parent
            radius: parent.radius
            color: "#fff"
            opacity: 0
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
            spacing: control.text ? 0 : 5
            anchors.centerIn: parent
            opacity: enabled ? 1.0 : 0.3
            Text {
                text: control.text
                visible: control.text
                font.pointSize: 14
                font.bold: true
                color: "#fff"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            MBusyIndicator {
                visible: !control.text
                implicitHeight: 10
                implicitWidth: 80
                Layout.alignment: Qt.AlignHCenter
                primaryColor: "#fff"
            }
            Text {
                id: subTextItem
                visible: control.subText
                text: control.subText
                font.pointSize: 9
                color: "#fff"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }

    states: State {
        name: "hovered"
        when: control.hovered && !control.down && control.enabled
    }

    transitions: [
        Transition {
            to: "hovered"
            NumberAnimation {
                target: buttonBackground
                property: "scale"
                to: 1.05
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: backgroundOverlay
                property: "opacity"
                to: 0.2
                duration: 100
                easing.type: Easing.OutCubic
            }
        },
        Transition {
            to: "*"
            NumberAnimation {
                target: buttonBackground
                property: "scale"
                to: 1
                duration: 100
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: backgroundOverlay
                property: "opacity"
                to: 0
                duration: 100
                easing.type: Easing.OutCubic
            }
        }
    ]
}
