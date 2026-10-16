import QtQuick
import QtQuick.Layouts

Rectangle {
    property string title
    property string subtitle: ""
    property alias content: container.data

    // glass bar over the space background
    color: window.lumenAlpha(window.lumenSurface, 0.65)
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: window.lumenAlpha(window.lumenAccent, 0.35) }
            GradientStop { position: 1.0; color: window.lumenAlpha(window.lumenAccent, 0) }
        }
    }
    Layout.fillWidth: true
    Layout.minimumHeight: contents.height
    z: 2

    ColumnLayout {
        id: contents
        spacing: 15

        Text {
            Layout.topMargin: 20
            Layout.leftMargin: 20
            Layout.bottomMargin: subtitle.length > 0 ? 5 : 0
            text: title
            color: "#fff"
            font {
                family: "Sora"
                weight: Font.Bold
                pointSize: 13
                letterSpacing: 1
                capitalization: Font.AllUppercase
            }
            Text {
                anchors.top: parent.bottom
                anchors.left: parent.left
                text: subtitle
                font.pointSize: 8.5
                color: "#a39cbd"
            }
        }

        ColumnLayout {
            id: container
            Layout.fillWidth: true
        }
    }
}
