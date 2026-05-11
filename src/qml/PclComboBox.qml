import QtQuick
import QtQuick.Controls
import PDFClowne

ComboBox {
    id: root

    implicitHeight: Theme.controlHeight

    background: Rectangle {
        radius: Theme.radius
        color: root.enabled ? (root.hovered ? Theme.controlFillHover : Theme.controlFill)
                            : Theme.controlDisabled
        border.color: root.activeFocus ? Theme.focusRing : Theme.border
        border.width: root.activeFocus ? 2 : 1
    }

    contentItem: Text {
        leftPadding: 10
        rightPadding: 26
        text: root.displayText
        color: root.enabled ? Theme.text : Theme.secondaryText
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: root.width - width - 8
        y: Math.round((root.height - height) / 2)
        text: "⌄"
        color: root.enabled ? Theme.secondaryText : Theme.border
        font.pixelSize: 13
    }

    popup: Popup {
        y: root.height + 4
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 220)
        padding: 4

        background: Rectangle {
            radius: Theme.radius
            color: Theme.surface
            border.color: Theme.border
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
        }
    }

    delegate: ItemDelegate {
        width: root.width - 8
        height: Theme.compactControlHeight
        highlighted: root.highlightedIndex === index

        background: Rectangle {
            radius: Theme.radius
            color: highlighted ? Theme.hover : "transparent"
        }

        contentItem: Text {
            text: root.textRole.length > 0 ? model[root.textRole] : modelData
            color: Theme.text
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }
}
