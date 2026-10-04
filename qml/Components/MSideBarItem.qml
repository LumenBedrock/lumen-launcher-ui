import QtQuick
import QtQuick.Layouts
import QtQuick.Templates as T

T.Button {
    id: control
    property alias iconSource: icon.source
    property alias showText: text.visible

    implicitHeight: 50
    implicitWidth: implicitContentWidth

    background: Item {
        Rectangle { // soft pill behind the active / hovered item
            anchors.fill: parent
            anchors.margins: 4
            radius: 8
            color: control.checked ? "#2d2459" : (control.hovered ? "#211a47" : "transparent")
        }
        Rectangle {
            id: indicatorBar
            color: "#e8b84a"
            width: 3
            height: 0
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
        }
        FocusBorder {
            visible: control.visualFocus
        }
    }

    contentItem: RowLayout {
        opacity: (control.hovered && !control.checked) ? 0.85 : 1
        height: control.height

        Image {
            id: icon
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            source: iconSource
            smooth: true
            sourceSize.width: 60
            sourceSize.height: 60
            fillMode: Image.PreserveAspectFit
            Layout.leftMargin: 18
            Layout.rightMargin: 18
        }

        Text {
            id: text
            color: "#fff"
            text: control.text
            font.pointSize: 11
            font.bold: checked
            verticalAlignment: Text.AlignVCenter
            Layout.fillHeight: true
            Layout.rightMargin: 40
        }
    }

    states: State {
        name: "checked"
        when: control.checked
    }

    transitions: [
        Transition {
            to: "checked"
            NumberAnimation {
                target: indicatorBar
                property: "height"
                to: 25
                duration: 200
                easing.type: Easing.OutCubic
            }
        },
        Transition {
            to: "*"
            NumberAnimation {
                target: indicatorBar
                property: "height"
                to: 0
                duration: 180
                easing.type: Easing.OutQuad
            }
        }
    ]
}
