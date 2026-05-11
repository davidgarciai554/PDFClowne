pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import PDFClowne

Item {
    id: root

    property var editableElements: []
    property var mapRect: function(rect) { return rect || { x: 0, y: 0, width: 1, height: 1 } }
    property string selectedElementId: ""
    property string hoveredElementId: ""
    property bool handlesVisible: true

    signal selectionChanged(var element)
    signal elementActivated(var element)

    Repeater {
        model: root.editableElements || []

        Rectangle {
            id: elementFrame
            required property var modelData

            readonly property string elementId: String(modelData.stableElementId || modelData.id || modelData.blockKey || "")
            readonly property var mapped: root.mapRect(modelData.rect || modelData.bboxPdf || {})
            readonly property bool selected: root.selectedElementId.length > 0 && root.selectedElementId === elementId
            readonly property bool hovered: root.hoveredElementId === elementId

            x: mapped.x
            y: mapped.y
            width: Math.max(10, mapped.width)
            height: Math.max(10, mapped.height)
            color: selected ? root.colorWithAlpha(Theme.accent, 0.10)
                            : hovered ? root.colorWithAlpha(Theme.accent, 0.06)
                                      : "transparent"
            border.color: selected ? Theme.accent : root.colorWithAlpha(Theme.accent, hovered ? 0.75 : 0.38)
            border.width: selected ? 2 : 1
            radius: 2

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.IBeamCursor
                onEntered: root.hoveredElementId = elementFrame.elementId
                onExited: if (root.hoveredElementId === elementFrame.elementId) root.hoveredElementId = ""
                onPressed: function(mouse) {
                    mouse.accepted = true
                    root.selectedElementId = elementFrame.elementId
                    root.selectionChanged(elementFrame.modelData)
                    root.elementActivated(elementFrame.modelData)
                }
                onClicked: function(mouse) {
                    mouse.accepted = true
                }
            }

            Repeater {
                model: root.handlesVisible && elementFrame.selected
                       ? [
                             { x: 0, y: 0 },
                             { x: elementFrame.width, y: 0 },
                             { x: elementFrame.width, y: elementFrame.height },
                             { x: 0, y: elementFrame.height }
                         ]
                       : []

                Rectangle {
                    required property var modelData
                    x: modelData.x - width / 2
                    y: modelData.y - height / 2
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.surface
                    border.color: Theme.accent
                    border.width: 1
                }
            }
        }
    }

    function colorWithAlpha(colorValue, alpha) {
        var color = Qt.color(colorValue)
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }
}
