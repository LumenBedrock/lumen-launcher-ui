import QtQuick
import QtQuick.Controls

Item {
    id: control

    property string title: ""
    property string description: ""
    property string actionText: ""
    property bool dismissible: true
    property color color: "#145"   // accent of the banner (error red, update purple, ...)
    signal clicked

    width: parent.width
    height: textColumn.implicitHeight + 30

    // glass card tinted with the accent, a glowing stripe on the left
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Qt.rgba(0.08, 0.06, 0.17, 0.82)
        border.width: 1
        border.color: Qt.rgba(control.color.r, control.color.g, control.color.b, 0.55)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(control.color.r, control.color.g, control.color.b, 0.38) }
                GradientStop { position: 1.0; color: Qt.rgba(control.color.r, control.color.g, control.color.b, 0.06) }
            }
        }
        Rectangle {
            width: 4
            radius: 2
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height - 24
            color: Qt.lighter(control.color, 1.8)
        }
    }
    // slide in when shown
    onVisibleChanged: if (visible) appear.restart()
    NumberAnimation { id: appear; target: control; property: "opacity"; from: 0; to: 1; duration: 300; easing.type: Easing.OutCubic }

    Row {
        x: 20
        y: 15
        width: parent.width - 35

        Column {
            id: textColumn
            width: parent.width - actionRow.width
            spacing: 4
            MText {
                width: parent.width
                text: control.title
                font.pointSize: 11
                font.bold: true
                elide: Text.ElideRight
                wrapMode: Text.Wrap
            }
            MText {
                width: parent.width
                text: control.description
                elide: Text.ElideRight
                wrapMode: Text.Wrap
            }
        }

        Row {
            id: actionRow
            y: 3
            height: 36
            property color color: Qt.lighter(control.color, 3.0)
            TransparentButton {
                id: actionButton
                text: control.actionText
                textColor: (hovered && !pressed) ? "#fff" : parent.color
                background: FocusBorder {
                    anchors.fill: parent
                    visible: parent.visualFocus
                }
                font.bold: true
                font.pointSize: 10
                height: parent.height
                width: implicitContentWidth + 26
                onClicked: control.clicked()
                visible: text
                padding: 0
            }
            Rectangle {
                y: 8
                width: 2
                height: parent.height - 16
                visible: dismissButton.visible && actionButton.visible
                color: parent.color
                opacity: 0.15
                clip: false
            }
            TransparentButton {
                id: dismissButton
                text: "⨯"
                textColor: (hovered && !pressed) ? "#fff" : parent.color
                background: FocusBorder {
                    anchors.fill: parent
                    visible: parent.visualFocus
                }
                font.bold: true
                font.pointSize: 12
                visible: control.dismissible
                height: parent.height
                width: 36
                padding: 0
                onClicked: {
                    control.visible = false
                }
            }
        }
    }
}
