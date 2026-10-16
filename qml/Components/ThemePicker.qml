import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs

// Design picker in the top right corner: switches the whole launcher look; the choice is saved
Item {
    id: picker
    property string theme
    signal picked(string theme)

    width: 38
    height: 38

    readonly property var themes: [
        { id: "sun", name: qsTr("Sun"), hint: qsTr("Sidebar, your servers orbit the Lumen sun"), a: "#ffd166", b: "#7c5cff" },
        { id: "classic", name: qsTr("Classic"), hint: qsTr("Like the website, menu at the top"), a: "#b59cff", b: "#5865f2" },
        { id: "orbit", name: qsTr("Orbit"), hint: qsTr("Pages are planets on an orbit"), a: "#9b80ff", b: "#e07a9e" },
        { id: "nebula", name: qsTr("Nebula"), hint: qsTr("Colourful clouds and a glass card"), a: "#ff78be", b: "#46c8e6" },
        { id: "pixel", name: qsTr("Pixel"), hint: qsTr("Minecraft style with a hotbar"), a: "#7c5cff", b: "#3fa34d" }
    ]

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: menu.visible || hover.hovered ? "#4d7c5cff" : "#a6140f2e"
        border.width: 1
        border.color: menu.visible || hover.hovered ? "#b59cff" : "#40bb99ff"
        Behavior on color { ColorAnimation { duration: 150 } }
        // palette: three colour dots
        Repeater {
            model: ["#ffd166", "#b59cff", "#ff78be"]
            Rectangle {
                required property string modelData
                required property int index
                width: 7; height: 7; radius: 3.5
                color: modelData
                x: picker.width / 2 - 3.5 + Math.cos((index * 120 - 90) * Math.PI / 180) * 6
                y: picker.height / 2 - 3.5 + Math.sin((index * 120 - 90) * Math.PI / 180) * 6
            }
        }
        rotation: hover.hovered ? 60 : 0
        Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        readonly property bool hovered: containsMouse
        onClicked: menu.visible ? menu.close() : menu.open()
    }
    ToolTip.visible: hover.hovered && !menu.visible
    ToolTip.text: qsTr("Launcher design")
    ToolTip.delay: 500

    ColorDialog {
        id: colourDialog
        property string key
        title: qsTr("Pick a colour")
        function pick(k, c) {
            key = k
            selectedColor = c
            open()
        }
        onAccepted: window.setLumenColor(key, selectedColor.toString())
    }

    Popup {
        id: menu
        x: picker.width - width
        y: picker.height + 8
        width: 600
        padding: 8
        background: Rectangle {
            radius: 16
            color: "#f2140f2e"
            border.width: 1
            border.color: "#59b59cff"
        }
        enter: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 160 }
                NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 200; easing.type: Easing.OutCubic }
            }
        }
        contentItem: Row {
          spacing: 10
          Column {
            spacing: 2
            Text {
                text: qsTr("LAUNCHER DESIGN")
                color: "#ffd166"
                font.pointSize: 8.5
                font.weight: Font.Bold
                font.letterSpacing: 2
                leftPadding: 10
                topPadding: 4
                bottomPadding: 6
            }
            Repeater {
                model: picker.themes
                Rectangle {
                    id: row
                    required property var modelData
                    readonly property bool current: picker.theme === modelData.id
                    width: 280
                    height: 50
                    radius: 10
                    color: current ? "#407c5cff" : (rowHover.hovered ? "#1fffffff" : "transparent")
                    border.width: current ? 1 : 0
                    border.color: "#66b59cff"
                    Rectangle { // two-colour swatch
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30; height: 30; radius: 9
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: row.modelData.a }
                            GradientStop { position: 1.0; color: row.modelData.b }
                        }
                    }
                    Column {
                        x: 52
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 80
                        Text {
                            text: row.modelData.name
                            color: "#ffffff"
                            font.pointSize: 10.5
                            font.weight: Font.DemiBold
                        }
                        Text {
                            width: parent.width
                            text: row.modelData.hint
                            color: "#a39cbd"
                            font.pointSize: 8.5
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        visible: row.current
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✓"
                        color: "#ffd166"
                        font.pointSize: 12
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        readonly property bool hovered: containsMouse
                        onClicked: {
                            picker.picked(row.modelData.id)
                        }
                    }
                }
            }

          }
          Rectangle { width: 1; height: parent.height; color: "#26bb99ff" }
          // ---- colours of the current design ----
          Column {
            spacing: 2
            Item {
                width: 286
                height: 30
                Text {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("COLOURS")
                    color: window.lumenGlow
                    font.pointSize: 8.5
                    font.weight: Font.Bold
                    font.letterSpacing: 2
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Reset")
                    color: resetArea.containsMouse ? "#ffffff" : "#a39cbd"
                    font.pointSize: 9
                    font.underline: resetArea.containsMouse
                    MouseArea {
                        id: resetArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.resetLumenColors()
                    }
                }
            }
            Repeater {
                model: [
                    { key: "accent", name: qsTr("Accent"), presets: ["#9b80ff", "#7c5cff", "#b59cff", "#ff9ecf", "#ff78be", "#e05a6a", "#ff8a5c", "#ffb347", "#ffd166", "#c4e05a", "#4fbf8f", "#3fd0c0", "#5fa8d3", "#4a7dff", "#c9c3e3", "#f2efe9"] },
                    { key: "glow", name: qsTr("Glow"), presets: ["#ffd166", "#ffe2a0", "#ffb347", "#ff9d4d", "#ff6b6b", "#ff78be", "#ff9ecf", "#d6a8ff", "#b59cff", "#8fa8ff", "#7ff0ff", "#7ee0b5", "#b8f06a", "#fff3c4", "#ffffff", "#c0c0d0"] },
                    { key: "sky", name: qsTr("Sky"), presets: ["#5a3fb0", "#8c64ff", "#3b2a73", "#2a1a5e", "#2a5fb0", "#1e3a7a", "#1f6f6a", "#14463f", "#2f5a2a", "#7a2f5f", "#5e1f3a", "#6b3f1f", "#4a3020", "#3a3a4a", "#1a1428", "#0a0a0f"] },
                    { key: "nav", name: qsTr("Tab bar"), presets: ["#1a1338", "#0d0a1c", "#140e28", "#120d1f", "#241a4d", "#3b2a73", "#1b2440", "#0f2a2a", "#2a1020", "#2a2a2a", "#000000", "#ffffff", "#ece8f8", "#b59cff", "#ffd9f0", "#7ff0ff"] }
                ]
                Column {
                    id: colourRow
                    required property var modelData
                    readonly property color current: window.lumenColor(modelData.key)
                    width: 286
                    leftPadding: 10
                    bottomPadding: 10
                    spacing: 6
                    Item {
                        width: 266
                        height: 28
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: colourRow.modelData.name
                            color: "#ece8f8"
                            font.pointSize: 9.5
                            font.weight: Font.DemiBold
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            // any colour: opens the colour picker
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 28
                                height: 28
                                radius: 14
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: "#ff6b6b" }
                                    GradientStop { position: 0.25; color: "#ffd166" }
                                    GradientStop { position: 0.5; color: "#7ee0b5" }
                                    GradientStop { position: 0.75; color: "#5fa8d3" }
                                    GradientStop { position: 1.0; color: "#b59cff" }
                                }
                                border.width: 1
                                border.color: "#66ffffff"
                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    color: "#120c26"
                                    font.pointSize: 13
                                    font.weight: Font.Bold
                                }
                                scale: pickArea.containsMouse ? 1.12 : 1
                                Behavior on scale { NumberAnimation { duration: 120 } }
                                MouseArea {
                                    id: pickArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: colourDialog.pick(colourRow.modelData.key, colourRow.current)
                                }
                                ToolTip.visible: pickArea.containsMouse
                                ToolTip.text: qsTr("Pick any colour")
                                ToolTip.delay: 400
                            }
                            // own colour as a hex code
                            MTextField {
                                width: 88
                                implicitHeight: 28
                                leftPadding: 22
                                font.pointSize: 9
                                text: colourRow.current.toString().toUpperCase()
                                validator: RegularExpressionValidator { regularExpression: /#?[0-9a-fA-F]{0,6}/ }
                                onEditingFinished: {
                                    const v = text.replace("#", "")
                                    if (v.length === 6)
                                        window.setLumenColor(colourRow.modelData.key, "#" + v.toLowerCase())
                                    else
                                        text = colourRow.current.toString().toUpperCase()
                                }
                                Rectangle {
                                    x: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 10; height: 10; radius: 5
                                    color: colourRow.current
                                }
                            }
                        }
                    }
                    Grid {
                        columns: 8
                        spacing: 5
                        Repeater {
                            model: colourRow.modelData.presets
                            Rectangle {
                                required property string modelData
                                readonly property bool chosen: Qt.colorEqual(colourRow.current, modelData)
                                width: 27
                                height: 22
                                radius: 7
                                color: modelData
                                border.width: chosen ? 2 : 1
                                border.color: chosen ? window.lumenGlow : "#33ffffff"
                                scale: swatchArea.containsMouse ? 1.12 : 1
                                Behavior on scale { NumberAnimation { duration: 120 } }
                                MouseArea {
                                    id: swatchArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: window.setLumenColor(colourRow.modelData.key, parent.modelData)
                                }
                            }
                        }
                    }
                }
            }
          }
        }
    }
}
