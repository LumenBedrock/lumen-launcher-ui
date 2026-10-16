import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Components"
import io.mrarm.mcpelauncher 1.0

ColumnLayout {
    id: page
    spacing: 0
    property bool locked: gameLauncher.running
    // Which dropdowns are open, kept here because every edit rebuilds the cards
    property var openState: ({})
    signal joinRequested(string uri)
    property string focusKey: "" // open this server's card on start
    property bool joinAllowed: true // false while no Google account is signed in
    Component.onCompleted: { // headless test hook: open the first server's dropdowns
        if (focusKey !== "") setOpen(focusKey + "#card", true)
        if (LUMEN_START_SET && store.profiles.length > 0) {
            var n = store.profiles[0].name
            setOpen(n + "#card", true)
            setOpen(n + "#packs", true)
        }
    }
    function isOpen(k) { return openState[k] === true }
    function setOpen(k, v) {
        var o = Object.assign({}, openState)
        o[k] = v
        openState = o
    }

    LumenProfiles {
        id: store
        dataDir: launcherSettings.gameDataDir
    }

    BaseHeader {
        title: qsTr("Servers")
    }

    CenteredScrollView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        content: ColumnLayout {
            width: parent.width
            spacing: 10

            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: window.lumenMuted
                font.pointSize: 10
                text: page.locked ? qsTr("The game is running: close it to edit servers here.")
                                  : qsTr("Per-server setups for the Lumen client. These are the same profiles you see in game, and changes apply the next time you join. Texture packs, module switches and values are all editable here too.")
            }

            // Add a server by hand
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: addCol.implicitHeight + 24
                radius: 12
                color: window.lumenSurface
                border.width: 1
                border.color: window.lumenLine
                enabled: !page.locked && store.available
                ColumnLayout {
                    id: addCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Text {
                        text: qsTr("NEW SERVER")
                        color: window.lumenGlow
                        font.pointSize: 9
                        font.bold: true
                        font.letterSpacing: 2
                    }
                    RowLayout {
                        spacing: 8
                        MTextField {
                            id: newName
                            Layout.preferredWidth: 150
                            placeholderText: qsTr("Name")
                        }
                        MTextField {
                            id: newHost
                            Layout.fillWidth: true
                            placeholderText: qsTr("Address (e.g. play.example.com:19132)")
                            onAccepted: addBtn.clicked()
                        }
                        MButton {
                            id: addBtn
                            text: qsTr("Add")
                            enabled: newName.text.trim().length > 0 && newHost.text.trim().length > 0
                            onClicked: {
                                if (store.addProfile(newName.text, newHost.text)) {
                                    newName.text = ""
                                    newHost.text = ""
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: !store.available
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: window.lumenMuted
                text: qsTr("No server profiles yet. Add one above, or join a server in game with Lumen and it creates one for you.")
            }

            Repeater {
                model: store.profiles
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    property bool cardOpen: page.isOpen(card.modelData.key + "#card")
                    property bool modulesOpen: page.isOpen(card.modelData.key + "#modules")
                    property bool packsOpen: page.isOpen(card.modelData.key + "#packs")
                    // lookups for the catalogue-driven module editor
                    property var valueMap: {
                        var m = {}
                        for (var i = 0; i < card.modelData.values.length; i++)
                            m[card.modelData.values[i].key] = card.modelData.values[i].value
                        return m
                    }
                    property var modMap: {
                        var m = {}
                        for (var i = 0; i < card.modelData.modules.length; i++)
                            m[card.modelData.modules[i].name] = card.modelData.modules[i].on
                        return m
                    }
                    property var setNames: card.modelData.modules.map(function (m) { return m.name })
                    Layout.fillWidth: true
                    implicitHeight: cardCol.implicitHeight + 24
                    radius: 12
                    color: window.lumenSurface
                    border.width: 1
                    border.color: window.lumenLine
                    enabled: !page.locked

                    ColumnLayout {
                        id: cardCol
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        // Server row: click to open its editor (like the in-game list)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 34
                            color: "transparent"
                            Text {
                                id: srvName
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.modelData.label
                                color: "#fff"
                                font.pointSize: 13
                                font.bold: true
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: srvName.right
                                anchors.leftMargin: 12
                                anchors.right: srvCaret.left
                                anchors.rightMargin: 8
                                text: card.modelData.hosts
                                color: window.lumenMuted
                                font.pointSize: 10
                                elide: Text.ElideRight
                            }
                            Text {
                                id: srvCaret
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                text: card.cardOpen ? "-" : "+"
                                color: window.lumenGlow
                                font.pointSize: 13
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.setOpen(card.modelData.key + "#card", !card.cardOpen)
                            }
                        }

                        ColumnLayout {
                            id: cardBody
                            visible: card.cardOpen
                            Layout.fillWidth: true
                            spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            MButton {
                                text: page.joinAllowed ? qsTr("Join") : qsTr("Sign in to join")
                                enabled: page.joinAllowed && !page.locked
                                onClicked: { var u = store.joinUri(card.modelData.key); if (u) page.joinRequested(u) }
                            }
                            Item { Layout.fillWidth: true }
                            MButton {
                                text: qsTr("Remove this server")
                                onClicked: store.removeProfile(card.modelData.key)
                            }
                        }

                        MTextField {
                            Layout.fillWidth: true
                            text: card.modelData.hosts
                            placeholderText: qsTr("Address(es), separated by commas")
                            onEditingFinished: if (text.trim() !== card.modelData.hosts) store.setHosts(card.modelData.key, text)
                        }

                        MCheckBox {
                            text: qsTr("Change texture packs here")
                            checked: card.modelData.setPacks
                            onClicked: store.setPacksEnabled(card.modelData.key, checked)
                        }

                        // Texture packs dropdown (folded by default, only when this server has its own stack)
                        Rectangle {
                            visible: card.modelData.setPacks
                            Layout.fillWidth: true
                            height: 34
                            radius: 8
                            color: packHead.containsMouse ? window.lumenSurfaceHigh : window.lumenSurfaceLow
                            border.width: 1
                            border.color: window.lumenLine
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                text: qsTr("Texture packs")
                                color: "#fff"
                                font.pointSize: 10
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                text: qsTr("%1 active").arg(card.modelData.packList.length) + "   " + (card.packsOpen ? "-" : "+")
                                color: window.lumenGlow
                                font.pointSize: 10
                            }
                            MouseArea {
                                id: packHead
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.setOpen(card.modelData.key + "#packs", !card.packsOpen)
                            }
                        }

                        Loader {
                            active: card.modelData.setPacks && card.packsOpen
                            visible: active
                            Layout.fillWidth: true
                            sourceComponent: Component {
                                ColumnLayout {
                                    spacing: 6

                                    PackEditor {
                                        Layout.fillWidth: true
                                        active: card.modelData.packList
                                        available: store.availablePacks.map(function (p) { return p.name })
                                        onStackChanged: list => store.setPacks(card.modelData.key, list)
                                    }
                                    MButton {
                                        text: qsTr("Copy current stack")
                                        implicitHeight: 30
                                        onClicked: store.setPacks(card.modelData.key, store.currentPackNames())
                                    }
                                }
                            }
                        }

                        // Modules dropdown (folded by default)
                        Rectangle {
                            Layout.fillWidth: true
                            height: 34
                            radius: 8
                            color: headMouse.containsMouse ? window.lumenSurfaceHigh : window.lumenSurfaceLow
                            border.width: 1
                            border.color: window.lumenLine
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                text: qsTr("Modules")
                                color: "#fff"
                                font.pointSize: 10
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                text: (card.modelData.modules.length > 0 ? qsTr("%1 set").arg(card.modelData.modules.length) + "   " : "") + (card.modulesOpen ? "-" : "+")
                                color: window.lumenGlow
                                font.pointSize: 10
                            }
                            MouseArea {
                                id: headMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.setOpen(card.modelData.key + "#modules", !card.modulesOpen)
                            }
                        }

                        // Catalogue-driven editor: every module the client can switch per server, with its settings
                        Loader {
                            active: card.modulesOpen && store.moduleCatalog.length > 0
                            visible: active
                            Layout.fillWidth: true
                            sourceComponent: Component {
                                ColumnLayout {
                                    spacing: 4

                                    Repeater {
                                        model: store.moduleCatalog
                                        delegate: Column {
                                            id: modBlock
                                            required property var modelData
                                            property bool open: page.isOpen(card.modelData.key + "#mod#" + modBlock.modelData.name)
                                            property string modName: modBlock.modelData.name
                                            property int setCount: {
                                                var n = card.modMap[modName] !== undefined ? 1 : 0
                                                for (var k in card.valueMap)
                                                    if (k.indexOf(modName + "|") === 0) n++
                                                return n
                                            }
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Rectangle {
                                                width: modBlock.width
                                                height: 34
                                                radius: 8
                                                color: modBlock.open ? window.lumenSurfaceHigh : (modMouse.containsMouse ? window.lumenSurfaceHigh : window.lumenSurfaceLow)
                                                border.width: 1
                                                border.color: modBlock.open ? window.lumenGlow : window.lumenLine
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 12
                                                    text: modBlock.modName + (modBlock.setCount > 0 ? "   (" + modBlock.setCount + " set)" : "")
                                                    color: modBlock.open ? window.lumenGlow : "#fff"
                                                    font.pointSize: 10
                                                }
                                                Text {
                                                    id: caret
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 12
                                                    text: modBlock.open ? "-" : "+"
                                                    color: window.lumenGlow
                                                }
                                                MouseArea {
                                                    id: modMouse
                                                    anchors.fill: parent
                                                    anchors.rightMargin: modBlock.modelData.hasSwitch ? 120 : 0
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: page.setOpen(card.modelData.key + "#mod#" + modBlock.modName, !modBlock.open)
                                                }
                                                Row {
                                                    visible: modBlock.modelData.hasSwitch
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.right: caret.left
                                                    anchors.rightMargin: 12
                                                    spacing: 4
                                                    MButton {
                                                        visible: card.modMap[modBlock.modName] !== undefined
                                                        implicitHeight: 26
                                                        text: qsTr("Use normal")
                                                        onClicked: store.clearModule(card.modelData.key, modBlock.modName)
                                                    }
                                                    MCheckBox {
                                                        text: qsTr("On")
                                                        checked: card.modMap[modBlock.modName] !== undefined ? card.modMap[modBlock.modName] : modBlock.modelData.enabled
                                                        onClicked: store.setModule(card.modelData.key, modBlock.modName, checked)
                                                    }
                                                }
                                            }

                                            Loader {
                                                active: modBlock.open
                                                visible: active
                                                x: 14
                                                width: modBlock.width - 14
                                                sourceComponent: Component {
                                                    ColumnLayout {
                                                        id: inner
                                                        spacing: 3
                                                        Repeater {
                                                            model: modBlock.modelData.settings
                                                            delegate: RowLayout {
                                                                id: setRow
                                                                required property var modelData
                                                                property string key: modBlock.modName + "|" + setRow.modelData.label
                                                                property bool has: card.valueMap[key] !== undefined
                                                                property real val: has ? card.valueMap[key] : setRow.modelData.current
                                                                Layout.fillWidth: true
                                                                spacing: 8

                                                                MCheckBox {
                                                                    visible: setRow.modelData.kind === "toggle"
                                                                    Layout.fillWidth: true
                                                                    text: setRow.modelData.label
                                                                    checked: setRow.val !== 0
                                                                    onClicked: store.setValue(card.modelData.key, setRow.key, checked ? 1 : 0)
                                                                }
                                                                Text {
                                                                    visible: setRow.modelData.kind !== "toggle"
                                                                    Layout.preferredWidth: 150
                                                                    text: setRow.modelData.label
                                                                    color: setRow.has ? "#fff" : window.lumenMuted
                                                                    font.pointSize: 10
                                                                    elide: Text.ElideRight
                                                                }
                                                                // slider
                                                                Slider {
                                                                    id: valSlider
                                                                    visible: setRow.modelData.kind === "slider"
                                                                    background: Rectangle {
                                                                        x: valSlider.leftPadding
                                                                        y: valSlider.topPadding + valSlider.availableHeight / 2 - height / 2
                                                                        width: valSlider.availableWidth
                                                                        height: 4
                                                                        radius: 2
                                                                        color: window.lumenLine
                                                                        Rectangle {
                                                                            width: valSlider.visualPosition * parent.width
                                                                            height: parent.height
                                                                            radius: 2
                                                                            color: window.lumenAccent
                                                                        }
                                                                    }
                                                                    handle: Rectangle {
                                                                        x: valSlider.leftPadding + valSlider.visualPosition * (valSlider.availableWidth - width)
                                                                        y: valSlider.topPadding + valSlider.availableHeight / 2 - height / 2
                                                                        width: 14
                                                                        height: 14
                                                                        radius: 7
                                                                        color: valSlider.pressed ? "#fff" : window.lumenGlow
                                                                    }
                                                                    Layout.fillWidth: true
                                                                    from: setRow.modelData.min
                                                                    to: setRow.modelData.max
                                                                    stepSize: setRow.modelData.step
                                                                    value: setRow.val
                                                                    onPressedChanged: if (!pressed) store.setValue(card.modelData.key, setRow.key, value)
                                                                }
                                                                Text {
                                                                    visible: setRow.modelData.kind === "slider"
                                                                    Layout.preferredWidth: 56
                                                                    horizontalAlignment: Text.AlignRight
                                                                    text: Number(setRow.val).toFixed(setRow.modelData.decimals)
                                                                    color: window.lumenGlow
                                                                    font.pointSize: 10
                                                                }
                                                                // cycle: one chip per option
                                                                Flow {
                                                                    visible: setRow.modelData.kind === "cycle"
                                                                    Layout.fillWidth: true
                                                                    spacing: 4
                                                                    Repeater {
                                                                        model: setRow.modelData.options || []
                                                                        delegate: MButton {
                                                                            required property string modelData
                                                                            required property int index
                                                                            implicitHeight: 26
                                                                            text: (index === Math.round(setRow.val) ? "● " : "") + modelData
                                                                            onClicked: store.setValue(card.modelData.key, setRow.key, index)
                                                                        }
                                                                    }
                                                                }
                                                                // key code / colour: typed value
                                                                MTextField {
                                                                    visible: setRow.modelData.kind === "key" || setRow.modelData.kind === "color"
                                                                    Layout.fillWidth: true
                                                                    implicitHeight: 28
                                                                    text: setRow.modelData.kind === "color" ? "#" + ("000000" + Math.round(setRow.val).toString(16)).slice(-6).toUpperCase() : Math.round(setRow.val).toString()
                                                                    placeholderText: setRow.modelData.kind === "color" ? "#RRGGBB" : qsTr("key code")
                                                                    onEditingFinished: {
                                                                        var v = setRow.modelData.kind === "color" ? parseInt(text.replace("#", ""), 16) : parseInt(text)
                                                                        if (!isNaN(v)) store.setValue(card.modelData.key, setRow.key, v)
                                                                    }
                                                                }
                                                                MButton {
                                                                    visible: setRow.has
                                                                    implicitHeight: 26
                                                                    text: qsTr("Use normal")
                                                                    onClicked: store.clearValue(card.modelData.key, setRow.key)
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
                        }

                        // Fallback when the client hasn't written its module catalogue yet (start the game once with
                        // the current Lumen): only the overrides already saved in the profile.
                        ColumnLayout {
                            visible: card.modulesOpen && store.moduleCatalog.length === 0
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                color: window.lumenMuted
                                font.pointSize: 9
                                text: qsTr("Start the game once with this version of Lumen to unlock every module setting here. Until then you can only edit what is already saved for this server.")
                            }
                            Repeater {
                                model: card.modelData.modules
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    MCheckBox {
                                        Layout.fillWidth: true
                                        text: parent.modelData.name
                                        checked: parent.modelData.on
                                        onClicked: store.setModule(card.modelData.key, parent.modelData.name, checked)
                                    }
                                    MButton {
                                        text: qsTr("Use normal")
                                        implicitHeight: 28
                                        onClicked: store.clearModule(card.modelData.key, parent.modelData.name)
                                    }
                                }
                            }
                            Repeater {
                                model: card.modelData.values
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: parent.modelData.module + "  ·  " + parent.modelData.label
                                        color: "#fff"
                                        font.pointSize: 10
                                        elide: Text.ElideRight
                                    }
                                    MTextField {
                                        Layout.preferredWidth: 90
                                        implicitHeight: 28
                                        text: Number(parent.modelData.value).toString()
                                        onEditingFinished: {
                                            var v = parseFloat(text)
                                            if (!isNaN(v) && v !== parent.modelData.value)
                                                store.setValue(card.modelData.key, parent.modelData.key, v)
                                        }
                                    }
                                    MButton {
                                        text: qsTr("Use normal")
                                        implicitHeight: 28
                                        onClicked: store.clearValue(card.modelData.key, parent.modelData.key)
                                    }
                                }
                            }
                        }
                        } // cardBody
                    }
                }
            }
        }
    }
}
