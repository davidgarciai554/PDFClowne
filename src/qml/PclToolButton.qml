import QtQuick
import QtQuick.Controls
import PDFClowne

Button {
    id: root

    property bool danger: false
    property string tooltip: ""

    implicitHeight: Theme.compactControlHeight
    implicitWidth: Math.max(Theme.iconButtonSize, contentItem.implicitWidth + 14)
    padding: 0

    ToolTip.visible: hovered && tooltip.length > 0
    ToolTip.text: tooltip
    ToolTip.delay: 450

    background: Rectangle {
        radius: Theme.radius
        color: {
            if (!root.enabled) return Theme.controlDisabled
            if (root.checked) return root.danger ? Theme.danger : Theme.accent
            if (root.down) return Theme.controlFillPressed
            if (root.hovered) return Theme.controlFillHover
            return Theme.controlFill
        }
        border.color: root.activeFocus ? Theme.focusRing
                    : root.checked ? (root.danger ? Theme.danger : Theme.accent)
                    : Theme.border
        border.width: root.activeFocus ? 2 : 1
        opacity: root.enabled ? 1.0 : 0.55
    }

    contentItem: Text {
        text: root.text
        color: root.checked ? Theme.accentText
              : root.danger ? Theme.danger
              : root.enabled ? Theme.text : Theme.secondaryText
        font.pixelSize: 11
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
