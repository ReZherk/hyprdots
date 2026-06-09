import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "../../config"
import "../../services"

// Keybindings cheatsheet — auto-generated from ~/.config/hypr/configs/keybinds.conf.
// Opens with Super+/ (quickshell:cheatsheet). Mirrors the Overview panel style so
// it follows matugen theming and the shell's Material 3 motion.
PanelWindow {
    id: sheet

    readonly property bool open: Visibilities.cheatsheet
    property bool render: false
    property bool shown: false

    // All parsed categories: [{ name, items: [{combo, action}] }]
    property var categories: []
    property string filter: ""

    // Categories with items filtered by the search box (empties dropped).
    readonly property var view: {
        const f = filter.toLowerCase()
        const out = []
        for (const cat of categories) {
            const items = f
                ? cat.items.filter(it => it.combo.toLowerCase().indexOf(f) >= 0
                                      || it.action.toLowerCase().indexOf(f) >= 0)
                : cat.items
            if (items.length) out.push({ name: cat.name, items: items })
        }
        return out
    }

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    visible: render

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    GlobalShortcut {
        name: "cheatsheet"
        description: "Toggle keybindings cheatsheet"
        onPressed: Visibilities.cheatsheet = !Visibilities.cheatsheet
    }

    onOpenChanged: {
        if (open) {
            render = true
            kbFile.reload()
            showT.restart()
        } else {
            shown = false
            filter = ""
            closeT.restart()
        }
    }

    Timer { id: showT; interval: 16; onTriggered: sheet.shown = true }
    Timer { id: closeT; interval: 400; onTriggered: sheet.render = false }

    // ── Parsing ───────────────────────────────────────────────────────────
    FileView {
        id: kbFile
        path: Quickshell.env("HOME") + "/.config/hypr/configs/keybinds.conf"
        onLoaded: sheet.categories = sheet.parse(text())
    }

    function prettyMods(m) {
        return m.replace(/\$mainMod/g, "Super")
                .replace(/SUPER/g, "Super")
                .replace(/SHIFT/g, "Shift")
                .replace(/CONTROL/g, "Ctrl")
                .replace(/CTRL/g, "Ctrl")
                .replace(/ALT/g, "Alt")
                .trim().split(/\s+/).filter(Boolean)
    }

    function prettyKey(k) {
        const map = {
            "left": "←", "right": "→", "up": "↑", "down": "↓",
            "Return": "⏎", "SPACE": "Space", "PRINT": "Print", "Tab": "Tab",
            "slash": "/", "mouse_down": "Scroll↓", "mouse_up": "Scroll↑",
            "mouse:272": "Click Izq", "mouse:273": "Click Der"
        }
        return map[k] || k
    }

    function friendlyAction(disp, args, vars) {
        const a = (args || "").trim()
        if (disp === "exec") {
            let cmd = a
            for (const v in vars) cmd = cmd.split(v).join(vars[v])
            return cmd
        }
        if (disp === "global")
            return a.replace("quickshell:", "").replace(/^\w/, c => c.toUpperCase())
        const map = {
            "killactive": "Cerrar ventana",
            "togglefloating": "Alternar flotante",
            "fullscreen": "Pantalla completa",
            "layoutmsg": "Cambiar layout (" + a + ")",
            "movefocus": "Mover foco " + sheet.prettyKey(a),
            "workspace": "Ir a workspace " + a,
            "movetoworkspace": "Mover ventana a workspace " + a,
            "movetoworkspacesilent": "Mover ventana (silencioso) " + a,
            "togglespecialworkspace": "Scratchpad",
            "movewindow": "Mover ventana (arrastrar)",
            "resizewindow": "Redimensionar (arrastrar)"
        }
        if (map[disp] !== undefined) return map[disp]
        return disp + (a ? " " + a : "")
    }

    function categoryOf(disp, args, key) {
        if (disp === "workspace" || disp === "movetoworkspace"
            || disp === "movetoworkspacesilent" || disp === "togglespecialworkspace")
            return "Workspaces"
        if (disp === "killactive" || disp === "togglefloating" || disp === "fullscreen"
            || disp === "layoutmsg" || disp === "movefocus" || disp === "movewindow"
            || disp === "resizewindow")
            return "Ventanas"
        const a = (args || "")
        if (a.indexOf("quickshell:bar") === 0) return "Barra"
        if (disp === "global" || disp === "exec") {
            if (key.indexOf("XF86") === 0 || key === "PRINT"
                || a.indexOf("brightnessctl") >= 0 || a.indexOf("wpctl") >= 0
                || a.indexOf("hyprshot") >= 0 || a.indexOf("lock") >= 0)
                return "Multimedia y Sistema"
            return "Apps y Shell"
        }
        return "Otros"
    }

    function parse(txt) {
        const lines = txt.split("\n")
        const vars = {}
        const order = ["Apps y Shell", "Workspaces", "Ventanas", "Barra", "Multimedia y Sistema", "Otros"]
        const buckets = {}

        for (let raw of lines) {
            const line = raw.trim()
            if (!line || line[0] === "#") continue

            const vm = line.match(/^\$(\w+)\s*=\s*(.+)$/)
            if (vm) { vars["$" + vm[1]] = vm[2].trim(); continue }

            const bm = line.match(/^bind[a-z]*\s*=\s*(.+)$/)
            if (!bm) continue
            const parts = bm[1].split(",")
            if (parts.length < 2) continue
            const mods = sheet.prettyMods(parts[0])
            const key = (parts[1] || "").trim()
            const disp = (parts[2] || "").trim()
            const args = parts.slice(3).join(",").trim()

            const combo = mods.concat([sheet.prettyKey(key)]).filter(Boolean).join(" + ")
            const action = sheet.friendlyAction(disp, args, vars)
            const cat = sheet.categoryOf(disp, args, key)

            if (!buckets[cat]) buckets[cat] = []
            buckets[cat].push({ combo: combo, action: action, key: key,
                                disp: disp, mods: mods.join(" ") })
        }

        const result = []
        for (const name of order) {
            const items = buckets[name]
            if (!items || !items.length) continue
            result.push({ name: name, items: sheet.collapseDigits(items) })
        }
        return result
    }

    // Collapse runs of single-digit keys (e.g. workspaces 1..0) into one row.
    function collapseDigits(items) {
        const out = []
        const seen = {}
        for (const it of items) {
            if (/^[0-9]$/.test(it.key)) {
                const gk = it.mods + "|" + it.disp
                if (seen[gk]) continue
                seen[gk] = true
                const m = it.mods ? sheet.prettyMods(it.mods).join(" + ") + " + " : ""
                const act = it.action.replace(/\s*\d+\s*$/, "").trim()
                out.push({ combo: m + "1 – 0", action: act + " 1–10" })
            } else {
                out.push({ combo: it.combo, action: it.action })
            }
        }
        return out
    }

    // ── UI ────────────────────────────────────────────────────────────────
    Item {
        id: rootArea
        anchors.fill: parent
        focus: sheet.open
        Keys.onEscapePressed: Visibilities.cheatsheet = false

        Rectangle {
            anchors.fill: parent
            color: Colours.shadow
            opacity: sheet.shown ? 0.5 : 0
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: Visibilities.cheatsheet = false }
        }

        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: Math.min(parent.width - 120, 1100)
            height: Math.min(parent.height - 120, 820)
            radius: Appearance.radius.large
            color: Colours.surface

            opacity: sheet.shown ? 1 : 0
            scale: sheet.shown ? 1 : 0.95
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.durations.expressiveDefaultSpatial
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
                }
            }

            // Header: title + live search box
            Item {
                id: header
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Appearance.spacing.large
                height: 40

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Atajos de teclado"
                    color: Colours.text
                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.sizeLarge
                    font.bold: true
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 260
                    height: 32
                    radius: Appearance.radius.normal
                    color: Colours.surfaceContainer
                    border.width: searchInput.activeFocus ? 1 : 0
                    border.color: Colours.primary

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        text: ""   // nerd font: magnifier
                        color: Colours.subtext
                        font.family: Appearance.font.family
                        font.pixelSize: Appearance.font.size
                    }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 30
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: Colours.text
                        font.family: Appearance.font.family
                        font.pixelSize: Appearance.font.size
                        focus: sheet.shown
                        onTextChanged: sheet.filter = text
                        Keys.onEscapePressed: Visibilities.cheatsheet = false

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "buscar..."
                            color: Colours.subtext
                            visible: searchInput.text.length === 0
                            font.family: Appearance.font.family
                            font.pixelSize: Appearance.font.size
                        }
                    }
                }
            }

            Rectangle {
                id: divider
                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Appearance.spacing.large
                anchors.rightMargin: Appearance.spacing.large
                anchors.topMargin: Appearance.spacing.small
                height: 1
                color: Colours.outline
            }

            // Category cards in 3 columns, wrapping & scrolling as needed
            Flickable {
                anchors.top: divider.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Appearance.spacing.large
                contentHeight: flow.implicitHeight
                clip: true

                Flow {
                    id: flow
                    width: parent.width
                    spacing: Appearance.spacing.large

                    Repeater {
                        model: sheet.view

                        Rectangle {
                            id: catCard
                            required property var modelData
                            width: (flow.width - Appearance.spacing.large * 2) / 3
                            implicitHeight: cardCol.implicitHeight + 2 * Appearance.spacing.normal
                            radius: Appearance.radius.normal
                            color: Colours.surfaceContainer

                            Column {
                                id: cardCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Appearance.spacing.normal
                                spacing: 4

                                Text {
                                    text: catCard.modelData.name
                                    color: Colours.primary
                                    font.family: Appearance.font.family
                                    font.pixelSize: Appearance.font.size
                                    font.bold: true
                                    bottomPadding: 2
                                }

                                Repeater {
                                    model: catCard.modelData.items

                                    Item {
                                        id: row
                                        required property var modelData
                                        width: cardCol.width
                                        height: 22

                                        Text {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width * 0.54
                                            elide: Text.ElideRight
                                            text: row.modelData.action
                                            color: Colours.text
                                            font.family: Appearance.font.family
                                            font.pixelSize: Appearance.font.sizeSmall
                                        }

                                        Text {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width * 0.42
                                            horizontalAlignment: Text.AlignRight
                                            elide: Text.ElideLeft
                                            text: row.modelData.combo
                                            color: Colours.subtext
                                            font.family: Appearance.font.family
                                            font.pixelSize: Appearance.font.sizeSmall
                                            font.bold: true
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
