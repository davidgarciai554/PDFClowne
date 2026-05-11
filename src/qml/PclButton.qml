import QtQuick
import QtQuick.Controls
import PDFClowne

Button {
    id: root

    property bool primary: false
    property bool danger: false

    implicitHeight: Theme.controlHeight
    padding: 0

    background: Rectangle {
        radius: Theme.radius
        color: {
            if (!root.enabled) return Theme.controlDisabled
            if (root.primary) {
                if (root.down) return Qt.darker(Theme.accent, 1.12)
                if (root.hovered) return Qt.lighter(Theme.accent, 1.08)
                return Theme.accent
            }
            if (root.danger) {
                if (root.down) return Qt.darker(Theme.danger, 1.12)
                if (root.hovered) return Qt.lighter(Theme.danger, 1.08)
                return Theme.danger
            }
            if (root.down) return Theme.controlFillPressed
            if (root.hovered) return Theme.controlFillHover
            return Theme.controlFill
        }
        border.color: root.activeFocus ? Theme.focusRing
                    : (root.primary ? Theme.accent : root.danger ? Theme.danger : Theme.border)
        border.width: root.activeFocus ? 2 : 1
        opacity: root.enabled ? 1.0 : 0.55
    }

    contentItem: Text {
        text: root.text
        color: (root.primary || root.danger) ? Theme.accentText
              : root.enabled ? Theme.text : Theme.secondaryText
        font.pixelSize: 12
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
