import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "../../config"
import "../../services"

PanelWindow {
    id: overview

    readonly property bool open: Visibilities.overview
    property bool render: false
    property bool shown: false

    property var rawWorkspaces: []
    property var workspaceData: []

    property string selAddr: ""
    property string selClass: ""
    property var wsCardMap: ({})

    property bool noWarpOrig: false

    property bool dragging: false
    property string dragAddr: ""
    property string dragClass: ""
    property real dragX: 0
    property real dragY: 0
    property int dropTarget: -1

    property bool dragFloating: false
    property int dragWsId: -1
    property real dragMonX: 0
    property real dragMonY: 0
    property real dragMonW: 1
    property real dragMonH: 1
    property real dragCx: 0
    property real dragCy: 0
    property real dragW: 0
    property real dragH: 0

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    visible: render

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    GlobalShortcut {
        name: "overview"
        description: "Toggle workspace overview"
        onPressed: Visibilities.overview = !Visibilities.overview
    }

    // Remember the user's cursor:no_warps so we can restore it on close
    Component.onCompleted: warpQuery.running = true

    Process {
        id: warpQuery
        command: ["hyprctl", "getoption", "cursor:no_warps", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    overview.noWarpOrig = JSON.parse(text.trim()).int === 1
                } catch (e) {}
            }
        }
    }

    onOpenChanged: {
        if (open) {
            // Disable cursor warping so dispatches don't drag the real cursor around
            Quickshell.execDetached(["hyprctl", "keyword", "cursor:no_warps", "true"])
            render = true
            fetchData()
            showT.restart()
        } else {
            Quickshell.execDetached(["hyprctl", "keyword", "cursor:no_warps", overview.noWarpOrig ? "true" : "false"])
            shown = false
            closeT.restart()
            selAddr = ""
            selClass = ""
        }
    }

    Timer { id: showT; interval: 16; onTriggered: overview.shown = true }
    Timer { id: closeT; interval: 400; onTriggered: overview.render = false }

    function fetchData() {
        dataProc.running = true
    }

    Process {
        id: dataProc
        command: ["sh", "-c", "echo '===WS==='; hyprctl workspaces -j; echo '===CL==='; hyprctl clients -j; echo '===MON==='; hyprctl monitors -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parts = text.split('===WS===\n')
                    if (parts.length < 2) return
                    const afterWs = parts[1].split('\n===CL===\n')
                    if (afterWs.length < 2) return
                    const wsText = afterWs[0]
                    const afterCl = afterWs[1].split('\n===MON===\n')
                    const clText = afterCl[0]
                    const monText = afterCl.length > 1 ? afterCl[1] : '[]'

                    overview.rawWorkspaces = JSON.parse(wsText.trim())
                    const clients = JSON.parse(clText.trim())
                    const monitors = JSON.parse(monText.trim())

                    const byWs = {}
                    for (const c of clients) {
                        const wsId = c.workspace.id
                        if (!byWs[wsId]) byWs[wsId] = []
                        byWs[wsId].push(c)
                    }

                    const activeIds = new Set()
                    for (const m of monitors) {
                        if (m.activeWorkspace && m.activeWorkspace.id !== undefined)
                            activeIds.add(m.activeWorkspace.id)
                    }

                    const wsMap = {}
                    for (const ws of rawWorkspaces) wsMap[ws.id] = ws

                    const monMap = {}
                    for (const m of monitors) {
                        monMap[m.name] = m
                    }

                    const data = []
                    for (let i = 1; i <= 10; i++) {
                        const info = wsMap[i]
                        const wsClients = byWs[i] || []
                        const monName = info ? info.monitor : ""
                        const mon = monMap[monName] || { width: 1920, height: 1080, x: 0, y: 0 }
                        data.push({
                            id: i,
                            name: info ? info.name : i.toString(),
                            monitor: monName,
                            windows: wsClients,
                            exists: !!info,
                            active: activeIds.has(i),
                            monW: mon.width,
                            monH: mon.height,
                            monX: mon.x,
                            monY: mon.y
                        })
                    }
                    overview.workspaceData = data
                } catch (e) {}
            }
        }
    }

    function focusWindow(addr) {
        Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + addr])
        Visibilities.overview = false
    }

    // Deterministic color per application class (same class -> same hue)
    function colorForClass(cls) {
        const s = cls || "?"
        let h = 0
        for (let i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) >>> 0
        const hue = (h % 360) / 360
        return Qt.hsla(hue, 0.45, 0.55, 1)
    }

    // Which workspace card (by id) is under a scene-coordinate point, or -1
    function cardIdAt(sx, sy) {
        for (const idStr in wsCardMap) {
            const card = wsCardMap[idStr]
            if (!card || !card.visible)
                continue
            const lp = card.mapFromItem(null, sx, sy)
            if (lp.x >= 0 && lp.y >= 0 && lp.x <= card.width && lp.y <= card.height)
                return parseInt(idStr)
        }
        return -1
    }

    function updateDropTarget() {
        dropTarget = cardIdAt(dragX, dragY)
    }

    // Real monitor coords of the current drop point inside card `id`'s mini canvas
    function dropRealPos(id) {
        const card = wsCardMap[id]
        if (!card)
            return null
        const cl = card.mapFromItem(null, dragX, dragY)
        const canvasW = card.width - 12   // canvas: x:6, width: parent.width - 12
        const canvasH = card.height - 38  // canvas: y:32, height: parent.height - 38
        let lx = Math.max(0, Math.min(canvasW, cl.x - 6))
        let ly = Math.max(0, Math.min(canvasH, cl.y - 32))
        return {
            x: dragMonX + lx / canvasW * dragMonW,
            y: dragMonY + ly / canvasH * dragMonH
        }
    }

    function finishDrag() {
        const target = cardIdAt(dragX, dragY)
        if (target > 0 && dragAddr) {
            if (target !== dragWsId) {
                // Dropped on a different workspace -> move it there
                Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspacesilent",
                    target.toString() + ",address:" + dragAddr])
            } else {
                // Dropped on its own workspace -> rearrange in place
                const p = dropRealPos(target)
                if (p) {
                    if (dragFloating) {
                        // Free-position floating window (center it on the drop point)
                        const px = Math.round(p.x - dragW / 2)
                        const py = Math.round(p.y - dragH / 2)
                        Quickshell.execDetached(["hyprctl", "dispatch", "movewindowpixel",
                            "exact " + px + " " + py + ",address:" + dragAddr])
                    } else {
                        // Tiled window -> swap with the neighbour toward the drop point
                        const dx = p.x - dragCx
                        const dy = p.y - dragCy
                        let dir = Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? "r" : "l") : (dy > 0 ? "d" : "u")
                        Quickshell.execDetached(["hyprctl", "--batch",
                            "dispatch focuswindow address:" + dragAddr + " ; dispatch swapwindow " + dir])
                    }
                }
            }
        }
        dragging = false
        dragAddr = ""
        dragClass = ""
        dropTarget = -1
        if (target > 0)
            fetchData()
    }

    Item {
        id: rootArea
        anchors.fill: parent
        focus: overview.open
        Keys.onEscapePressed: Visibilities.overview = false

        Rectangle {
            anchors.fill: parent
            color: Colours.shadow
            opacity: overview.shown ? 0.5 : 0
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: Visibilities.overview = false }
        }

        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: Math.min(parent.width - 120, 1300)
            height: parent.height - 120
            radius: Appearance.radius.large
            color: Colours.surface

            opacity: overview.shown ? 1 : 0
            scale: overview.shown ? 1 : 0.95
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.durations.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: Appearance.spacing.large + 8
                spacing: Appearance.spacing.large

                Row {
                    width: parent.width
                    spacing: Appearance.spacing.normal
                    Text {
                        text: "Overview"
                        color: Colours.text
                        font.family: Appearance.font.family
                        font.pixelSize: Appearance.font.sizeLarge
                        font.bold: true
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: overview.selAddr ? "— seleccionado: " + overview.selClass + " (click en workspace para mover)" : "— click ventana para seleccionar"
                        color: Colours.secondary
                        font.family: Appearance.font.family
                        font.pixelSize: Appearance.font.sizeSmall
                    }
                }

                Flickable {
                    id: scrollArea
                    width: parent.width
                    height: parent.height - implicitCellTitle
                    readonly property int implicitCellTitle: Appearance.font.sizeLarge + Appearance.spacing.large + 20
                    contentHeight: wsGrid.implicitHeight
                    clip: true

                    Grid {
                        id: wsGrid
                        width: parent.width
                        columns: 3
                        rowSpacing: Appearance.spacing.normal
                        columnSpacing: Appearance.spacing.normal

                        Repeater {
                            model: overview.workspaceData

                            delegate: Item {
                                required property var modelData
                                id: wsCard
                                width: (wsGrid.width - (wsGrid.columns - 1) * wsGrid.columnSpacing) / wsGrid.columns
                                height: 180

                                Component.onCompleted: wsCardMap[modelData.id] = wsCard
                                Component.onDestruction: delete wsCardMap[modelData.id]
                                Rectangle {
                                    id: wsBg
                                    anchors.fill: parent
                                    radius: Appearance.radius.normal
                                    color: modelData.active ? Colours.primary : Colours.surfaceContainer
                                    opacity: modelData.exists ? 1 : 0.4
                                    border.width: (overview.dragging && overview.dropTarget === modelData.id) ? 3 : (modelData.active ? 2 : 0)
                                    border.color: (overview.dragging && overview.dropTarget === modelData.id) ? Colours.secondary : (modelData.active ? Colours.primary : "transparent")

                                    Behavior on color { ColorAnimation { duration: Appearance.anim.durationFast } }

                                    // Workspace header — full-width tap target (move-selected / switch)
                                    Rectangle {
                                        id: header
                                        anchors { left: parent.left; right: parent.right; top: parent.top }
                                        height: 28
                                        color: "transparent"
                                        z: 5

                                        Row {
                                            x: 8; y: 4
                                            spacing: 4
                                            Text {
                                                text: modelData.id
                                                color: modelData.active ? Colours.primaryText : Colours.text
                                                font.family: Appearance.font.family
                                                font.pixelSize: Appearance.font.size
                                                font.bold: true
                                            }
                                            Text {
                                                text: modelData.monitor.replace("HDMI-A-", "H").replace("eDP-", "L")
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: modelData.active ? Colours.primaryText : Colours.subtext
                                                font.family: Appearance.font.family
                                                font.pixelSize: 9
                                            }
                                        }

                                        TapHandler {
                                            gesturePolicy: TapHandler.ReleaseWithinBounds
                                            onTapped: {
                                                if (overview.selAddr) {
                                                    Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspacesilent",
                                                        modelData.id.toString() + ",address:" + overview.selAddr])
                                                    overview.selAddr = ""
                                                    overview.selClass = ""
                                                    overview.fetchData()
                                                } else if (modelData.exists) {
                                                    Quickshell.execDetached(["hyprctl", "dispatch", "workspace", modelData.id.toString()])
                                                    Visibilities.overview = false
                                                }
                                            }
                                        }
                                    }

                                    // Mini canvas showing windows at actual positions
                                    Rectangle {
                                        id: canvas
                                        x: 6; y: 32
                                        width: parent.width - 12
                                        height: parent.height - 38
                                        radius: Appearance.radius.small
                                        color: Colours.surfaceContainer
                                        clip: true

                                        Repeater {
                                            model: modelData.windows

                                            delegate: Rectangle {
                                                required property var modelData
                                                visible: modelData.mapped === true
                                                x: (modelData.at[0] - wsCard.modelData.monX) / Math.max(wsCard.modelData.monW, 1) * canvas.width
                                                y: (modelData.at[1] - wsCard.modelData.monY) / Math.max(wsCard.modelData.monH, 1) * canvas.height
                                                width: Math.max(modelData.size[0] / Math.max(wsCard.modelData.monW, 1) * canvas.width, 8)
                                                height: Math.max(modelData.size[1] / Math.max(wsCard.modelData.monH, 1) * canvas.height, 6)
                                                radius: 2
                                                color: overview.selAddr === modelData.address ? Qt.lighter(overview.colorForClass(modelData.class), 1.3) : overview.colorForClass(modelData.class)
                                                border.width: overview.selAddr === modelData.address ? 2 : 1
                                                border.color: overview.selAddr === modelData.address ? Colours.primary : Qt.darker(overview.colorForClass(modelData.class), 1.4)
                                                opacity: 0.85

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.class
                                                    color: "#ffffff"
                                                    font.family: Appearance.font.family
                                                    font.pixelSize: 7
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                    width: parent.width - 4
                                                    horizontalAlignment: Text.AlignHCenter
                                                    visible: parent.width > 20 && parent.height > 14
                                                }

                                                TapHandler {
                                                    onTapped: {
                                                        if (overview.selAddr === modelData.address) {
                                                            overview.focusWindow(modelData.address)
                                                        } else {
                                                            overview.selAddr = modelData.address
                                                            overview.selClass = modelData.class
                                                        }
                                                    }
                                                }

                                                DragHandler {
                                                    target: null
                                                    onActiveChanged: {
                                                        if (active) {
                                                            overview.dragAddr = modelData.address
                                                            overview.dragClass = modelData.class
                                                            overview.dragFloating = modelData.floating === true
                                                            overview.dragWsId = wsCard.modelData.id
                                                            overview.dragMonX = wsCard.modelData.monX
                                                            overview.dragMonY = wsCard.modelData.monY
                                                            overview.dragMonW = Math.max(wsCard.modelData.monW, 1)
                                                            overview.dragMonH = Math.max(wsCard.modelData.monH, 1)
                                                            overview.dragW = modelData.size[0]
                                                            overview.dragH = modelData.size[1]
                                                            overview.dragCx = modelData.at[0] + modelData.size[0] / 2
                                                            overview.dragCy = modelData.at[1] + modelData.size[1] / 2
                                                            overview.dragX = centroid.scenePosition.x
                                                            overview.dragY = centroid.scenePosition.y
                                                            overview.dragging = true
                                                        } else {
                                                            overview.finishDrag()
                                                        }
                                                    }
                                                    onCentroidChanged: {
                                                        if (active) {
                                                            overview.dragX = centroid.scenePosition.x
                                                            overview.dragY = centroid.scenePosition.y
                                                            overview.updateDropTarget()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Hint when window selected
                                    Text {
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: overview.selAddr ? "Click en n° de workspace para mover" : ""
                                        color: Colours.secondary
                                        font.family: Appearance.font.family
                                        font.pixelSize: 8
                                        visible: overview.selAddr !== ""
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Floating drag ghost following the cursor
        Rectangle {
            id: dragGhost
            visible: overview.dragging
            x: overview.dragX - width / 2
            y: overview.dragY - height / 2
            width: 130
            height: 78
            z: 1000
            radius: Appearance.radius.normal
            color: Qt.lighter(Colours.primary, 1.2)
            border.width: 2
            border.color: Colours.primary
            opacity: 0.9

            Text {
                anchors.centerIn: parent
                text: overview.dragClass
                color: Colours.primaryText
                font.family: Appearance.font.family
                font.pixelSize: Appearance.font.size
                elide: Text.ElideRight
                width: parent.width - 12
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
