import QtQuick
import QtQuick.Controls
import PDFClowne

CheckBox {
    id: root

    implicitHeight: Theme.controlHeight
    spacing: 8

    indicator: Rectangle {
        implicitWidth: 20
        implicitHeight: 20
        x: 0
        y: Math.round((root.height - height) / 2)
        radius: 3
        color: root.checked ? Theme.accent : Theme.controlFill
        border.color: root.activeFocus ? Theme.focusRing : Theme.border
        border.width: root.activeFocus ? 2 : 1

        Text {
            anchors.centerIn: parent
            text: root.checked ? "✓" : ""
            color: Theme.accentText
            font.pixelSize: 14
            font.weight: Font.Bold
        }
    }

    contentItem: Text {
        text: root.text
        color: root.enabled ? Theme.text : Theme.secondaryText
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
        leftPadding: root.indicator.width + root.spacing
        elide: Text.ElideRight
    }
}
