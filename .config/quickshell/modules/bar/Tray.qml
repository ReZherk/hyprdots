import Quickshell
import Quickshell.Services.SystemTray
import QtQuick
import "../../config"

Grid {
    id: root

    readonly property bool vertical: Appearance.bar.vertical

    rows: vertical ? -1 : 1
    columns: vertical ? 1 : -1
    rowSpacing: Appearance.spacing.normal
    columnSpacing: Appearance.spacing.normal

    Repeater {
        model: SystemTray.items

        delegate: Item {
            required property var modelData
            implicitWidth: Appearance.icon.size
            implicitHeight: Appearance.icon.size

            Image {
                anchors.fill: parent
                source: modelData.icon
                sourceSize.width: Appearance.icon.size
                sourceSize.height: Appearance.icon.size
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: function (mouse) {
                    if (mouse.button === Qt.LeftButton)
                        modelData.activate();
                    else
                        modelData.secondaryActivate();
                }
            }
        }
    }
}
