import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../config"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property string pos: Appearance.bar.position
    readonly property bool vertical: Appearance.bar.vertical

    anchors {
        top: root.pos === "top" || root.vertical
        bottom: root.pos === "bottom" || root.vertical
        left: root.pos === "left" || !root.vertical
        right: root.pos === "right" || !root.vertical
    }
    margins {
        top: Appearance.bar.margin
        bottom: Appearance.bar.margin
        left: Appearance.bar.margin
        right: Appearance.bar.margin
    }
    implicitHeight: root.vertical ? 0 : Appearance.bar.thickness
    implicitWidth: root.vertical ? Appearance.bar.thickness : 0
    // Reserve only edge-gap + bar (not double margin), so the bar↔window gap
    // matches the screen-edge↔bar gap. Hyprland adds gaps_out on top.
    // exclusionMode Normal is required for a manual exclusiveZone to apply
    // (default Auto ignores it).
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Appearance.bar.thickness   // Quickshell adds the anchor margin → reserved = margin + thickness
    color: "transparent"

    // A layer-shell window can't smoothly travel between screen edges, so on a
    // position change we just do a quick clean fade-in at the new edge (no
    // slide/travel — that read as "close then arrive").
    onPosChanged: barEnter.restart()
    SequentialAnimation {
        id: barEnter
        ScriptAction { script: bg.opacity = 0 }
        NumberAnimation {
            target: bg; property: "opacity"; to: 1
            duration: Appearance.anim.durations.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.emphasizedDecel
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: Appearance.radius.normal
        color: Colours.surface

        // A Loader swaps the WHOLE layout when orientation changes, so we never
        // mutate anchor targets at runtime (which silently drops items in QML).
        Loader {
            anchors.fill: parent
            sourceComponent: root.vertical ? vLayout : hLayout
        }
    }

    // ── Horizontal layout (top / bottom) ──
    Component {
        id: hLayout
        Item {
            anchors.fill: parent

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Appearance.spacing.large
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.spacing.large

                Workspaces { anchors.verticalCenter: parent.verticalCenter }
                ActiveWindow {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 360)
                }
            }

            Clock { anchors.centerIn: parent }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: Appearance.spacing.large
                anchors.verticalCenter: parent.verticalCenter
                spacing: Appearance.spacing.large

                StatusIcons { anchors.verticalCenter: parent.verticalCenter }
                Tray { anchors.verticalCenter: parent.verticalCenter }
                PositionPicker { anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // ── Vertical layout (left / right) ──
    Component {
        id: vLayout
        Item {
            anchors.fill: parent

            Column {
                anchors.top: parent.top
                anchors.topMargin: Appearance.spacing.large
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Appearance.spacing.large

                Workspaces { anchors.horizontalCenter: parent.horizontalCenter }
            }

            Clock { anchors.centerIn: parent }

            Column {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.spacing.large
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Appearance.spacing.large

                StatusIcons { anchors.horizontalCenter: parent.horizontalCenter }
                Tray { anchors.horizontalCenter: parent.horizontalCenter }
                PositionPicker { anchors.horizontalCenter: parent.horizontalCenter }
            }
        }
    }
}
