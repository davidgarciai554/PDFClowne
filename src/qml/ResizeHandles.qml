import QtQuick
import PDFClowne

// 8-point resize handle overlay. Parent sets width/height to match block.
// Drag any handle → resized(dx, dy, dw, dh) fires with delta adjustments.
Item {
    id: root
    anchors.fill: parent

    // "reflow" | "scaleFont" | "clip"
    property string resizeMode: "reflow"

    signal resized(real dx, real dy, real dw, real dh)

    readonly property real _hs: 5  // handle size px
    readonly property real _hh: _hs / 2

    // Positions: NW NE SE SW. Mid-edge handles were too intrusive for text.
    readonly property var _handles: [
        { cx: 0,           cy: 0,           cursor: Qt.SizeFDiagCursor, dx:  1, dy:  1, dw: -1, dh: -1 },
        { cx: 1,           cy: 0,           cursor: Qt.SizeBDiagCursor, dx:  0, dy:  1, dw:  1, dh: -1 },
        { cx: 1,           cy: 1,           cursor: Qt.SizeFDiagCursor, dx:  0, dy:  0, dw:  1, dh:  1 },
        { cx: 0,           cy: 1,           cursor: Qt.SizeBDiagCursor, dx:  1, dy:  0, dw: -1, dh:  1 },
    ]

    Repeater {
        model: root._handles

        Item {
            required property var modelData
            required property int index

            x: modelData.cx * root.width - root._hh
            y: modelData.cy * root.height - root._hh
            width: root._hs
            height: root._hs
            z: 10

            Rectangle {
                anchors.fill: parent
                color: Theme.accent
                border.color: Theme.surface
                border.width: 1
                radius: 1
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: parent.modelData.cursor
                drag.target: dragProxy
                drag.axis: Drag.XAndYAxis

                property real startX: 0
                property real startY: 0

                onPressed: function(mouse) {
                    startX = mouse.x
                    startY = mouse.y
                }

                onPositionChanged: function(mouse) {
                    if (!pressed) return
                    const rawDx = mouse.x - startX
                    const rawDy = mouse.y - startY
                    const md = parent.modelData

                    const finalDx = rawDx * md.dx
                    const finalDy = rawDy * md.dy
                    const finalDw = rawDx * md.dw
                    const finalDh = rawDy * md.dh

                    if (Math.abs(finalDx) + Math.abs(finalDy)
                        + Math.abs(finalDw) + Math.abs(finalDh) > 0.5) {
                        root.resized(finalDx, finalDy, finalDw, finalDh)
                        startX = mouse.x
                        startY = mouse.y
                    }
                }
            }
        }
    }

    // Invisible proxy item required by drag.target (drag needs a target)
    Item { id: dragProxy; visible: false }
}
