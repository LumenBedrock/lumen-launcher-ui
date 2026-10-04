import QtQuick
import QtQuick.Layouts
import "Components"

// Two-zone texture pack editor, like the in-game one: drag packs between "Active" (ordered, top = highest
// priority) and "Available", or drag inside Active to reorder. A plain click on an available pack adds it to
// the end. Emits stackChanged(list) once per finished edit.
Item {
    id: root
    property var active: []     // pack names, in order
    property var available: []  // every installed pack name
    signal stackChanged(var list)

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    readonly property int rowH: 30
    readonly property int gap: 2
    readonly property int pad: 4

    // drag state
    property bool dragging: false
    property string dragName: ""
    property bool dragFromActive: false
    property int dragIndex: -1
    property int dropIndex: -1 // insertion slot in Active, -1 = not over Active
    property real pressX: 0
    property real pressY: 0
    property real ghostX: 0
    property real ghostY: 0

    function beginPress(name, fromActive, idx, gx, gy) {
        dragName = name
        dragFromActive = fromActive
        dragIndex = idx
        pressX = gx
        pressY = gy
        dragging = false
        dropIndex = -1
    }
    function moveDrag(gx, gy) {
        if (!dragging) {
            if (Math.abs(gx - pressX) + Math.abs(gy - pressY) < 8)
                return
            dragging = true
        }
        ghostX = gx
        ghostY = gy
        var p = root.mapToItem(rowsCol, gx, gy)
        var inside = p.x >= -6 && p.x <= rowsCol.width + 6 && p.y >= -10 && p.y <= activeZone.height + 10
        if (inside) {
            var slot = Math.floor((p.y + (rowH + gap) / 2) / (rowH + gap))
            dropIndex = Math.max(0, Math.min(active.length, slot))
        } else {
            dropIndex = -1
        }
    }
    function endDrag() {
        var wasDragging = dragging
        var name = dragName
        var list = active.slice()
        if (wasDragging) {
            if (dragFromActive) {
                list.splice(dragIndex, 1)
                if (dropIndex >= 0)
                    list.splice(dropIndex > dragIndex ? dropIndex - 1 : dropIndex, 0, name)
                // dropIndex === -1: dropped outside Active, so the pack leaves the stack
            } else if (dropIndex >= 0) {
                list.splice(dropIndex, 0, name)
            }
        } else if (!dragFromActive) {
            list.push(name) // plain click on an available pack
        }
        dragging = false
        dropIndex = -1
        dragName = ""
        if (JSON.stringify(list) !== JSON.stringify(active))
            stackChanged(list)
    }

    ColumnLayout {
        id: col
        width: root.width
        spacing: 6

        Text {
            text: qsTr("Active  (top = highest priority)")
            color: "#9a8fd0"
            font.pointSize: 9
            font.letterSpacing: 1
        }

        Rectangle {
            id: activeZone
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(rowH + 2 * pad, root.active.length * (rowH + gap) - gap + 2 * pad)
            radius: 8
            color: "#16112e"
            border.width: 1
            border.color: root.dragging && root.dropIndex >= 0 ? "#e8b84a" : "#3b3068"

            Text {
                visible: root.active.length === 0
                anchors.centerIn: parent
                text: qsTr("Drop packs here. Empty = vanilla textures.")
                color: "#7d73ad"
                font.pointSize: 9
            }

            Column {
                id: rowsCol
                x: root.pad
                y: root.pad
                width: parent.width - 2 * root.pad
                spacing: root.gap
                Repeater {
                    model: root.active
                    delegate: Rectangle {
                        id: row
                        required property string modelData
                        required property int index
                        width: rowsCol.width
                        height: root.rowH
                        radius: 6
                        color: rowMouse.containsMouse ? "#2d2459" : "#241c4a"
                        opacity: root.dragging && root.dragFromActive && root.dragIndex === row.index ? 0.35 : 1
                        Rectangle { // accent edge, like the in-game rows
                            width: 2
                            height: parent.height
                            color: "#7a5af0"
                        }
                        Text {
                            id: grip
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            text: "⋮⋮"
                            color: "#7d73ad"
                            font.pointSize: 9
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: grip.right
                            anchors.leftMargin: 10
                            anchors.right: numText.left
                            anchors.rightMargin: 8
                            text: row.modelData
                            color: "#fff"
                            font.pointSize: 10
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            id: numText
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            text: "#" + (row.index + 1)
                            color: "#e8b84a"
                            font.pointSize: 10
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true // keep the scroll view from taking over a vertical drag
                            cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            onPressed: mouse => {
                                var g = mapToItem(root, mouse.x, mouse.y)
                                root.beginPress(row.modelData, true, row.index, g.x, g.y)
                            }
                            onPositionChanged: mouse => {
                                if (pressed) {
                                    var g = mapToItem(root, mouse.x, mouse.y)
                                    root.moveDrag(g.x, g.y)
                                }
                            }
                            onReleased: root.endDrag()
                            onCanceled: { root.dragging = false; root.dropIndex = -1 }
                        }
                    }
                }
            }

            // insertion marker
            Rectangle {
                visible: root.dragging && root.dropIndex >= 0
                x: root.pad
                width: parent.width - 2 * root.pad
                height: 3
                radius: 1
                color: "#e8b84a"
                y: root.pad + root.dropIndex * (root.rowH + root.gap) - root.gap / 2 - 1
            }
        }

        Text {
            Layout.topMargin: 4
            text: qsTr("Available")
            color: "#9a8fd0"
            font.pointSize: 9
            font.letterSpacing: 1
        }

        Rectangle {
            id: availZone
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(root.rowH + 2 * root.pad, availFlow.height + 2 * root.pad)
            radius: 8
            color: "#16112e"
            border.width: 1
            border.color: root.dragging && root.dragFromActive && root.dropIndex < 0 ? "#e8b84a" : "#3b3068"

            Column {
                id: availFlow
                x: root.pad
                y: root.pad
                width: parent.width - 2 * root.pad
                spacing: root.gap
                Repeater {
                    model: root.available
                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        property bool used: root.active.indexOf(chip.modelData) >= 0
                        visible: !used
                        width: availFlow.width
                        height: visible ? root.rowH : 0
                        radius: 6
                        color: chipMouse.containsMouse ? "#2d2459" : "#201a42"
                        opacity: root.dragging && !root.dragFromActive && root.dragName === chip.modelData ? 0.35 : 1
                        Text {
                            id: chipGrip
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            text: "⋮⋮"
                            color: "#7d73ad"
                            font.pointSize: 9
                        }
                        Text {
                            id: chipText
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: chipGrip.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            text: chip.modelData
                            color: "#fff"
                            font.pointSize: 10
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            onPressed: mouse => {
                                var g = mapToItem(root, mouse.x, mouse.y)
                                root.beginPress(chip.modelData, false, -1, g.x, g.y)
                            }
                            onPositionChanged: mouse => {
                                if (pressed) {
                                    var g = mapToItem(root, mouse.x, mouse.y)
                                    root.moveDrag(g.x, g.y)
                                }
                            }
                            onReleased: root.endDrag()
                            onCanceled: { root.dragging = false; root.dropIndex = -1 }
                        }
                    }
                }
            }
        }
    }

    // the pack following the pointer while dragging
    Rectangle {
        visible: root.dragging
        z: 100
        x: root.ghostX - width / 2
        y: root.ghostY - height / 2
        width: ghostText.implicitWidth + 24
        height: 28
        radius: 6
        color: "#7a5af0"
        border.width: 1
        border.color: "#e8b84a"
        opacity: 0.92
        Text {
            id: ghostText
            anchors.centerIn: parent
            text: root.dragName
            color: "#fff"
            font.pointSize: 10
            font.bold: true
        }
    }
}
