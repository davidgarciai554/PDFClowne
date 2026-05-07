import QtQuick
import QtQuick.Controls

Item {
    id: root

    required property string blockId
    property bool   isEditable: true
    property bool   isSelected: false
    property string plainText: ""
    property string fontFamily: "Helvetica"
    property real   fontSize: 12
    property real   originalHeight: height
    property bool   editingActive: false
    property string resizeMode: "reflow"   // "reflow" | "scaleFont" | "clip"
    property bool   bold: false
    property bool   italic: false
    property int    textAlignment: Qt.AlignLeft

    // Other blocks' screen rects for snap-to-guides (array of {x,y,width,height})
    property var siblingRects: []
    readonly property real snapThresholdPx: 6

    // Set by the parent when a font fallback was triggered for this block.
    property string fallbackFontName: ""

    signal blockClicked(string blockId)
    signal blockHovered(string blockId)
    signal blockUnhovered(string blockId)
    signal textEditing(string blockId, string newText)
    signal resized(string blockId, real dx, real dy, real dw, real dh)
    signal styleChanged(string blockId, string prop, var value)

    // ── helpers ──────────────────────────────────────────────────────────────

    function snapDelta(val, candidates) {
        let best = val
        let bestDist = snapThresholdPx
        for (const c of candidates) {
            const d = Math.abs(val - c)
            if (d < bestDist) { bestDist = d; best = c }
        }
        return best - val
    }

    // ── background ───────────────────────────────────────────────────────────

    Rectangle {
        id: overlay
        anchors.fill: parent
        radius: 2
        color: {
            if (root.editingActive)       return "#08000000"
            if (root.isSelected)          return "#152196F3"
            if (hoverArea.containsMouse)  return root.isEditable ? "#104CAF50" : "#10FF9800"
            return "transparent"
        }
        border.color: {
            if (root.editingActive || root.isSelected) return "#2196F3"
            if (hoverArea.containsMouse)               return root.isEditable ? "#4CAF50" : "#FF9800"
            return "transparent"
        }
        border.width: (root.isSelected || root.editingActive) ? 2 : 1
    }

    // ── text edit ────────────────────────────────────────────────────────────

    TextEdit {
        id: editArea
        anchors { left: parent.left; right: parent.right; top: parent.top }
        visible: root.editingActive
        enabled: root.editingActive
        wrapMode: TextEdit.Wrap
        font.family: root.fontFamily
        font.pointSize: Math.max(1, root.fontSize)
        font.bold: root.bold
        font.italic: root.italic
        horizontalAlignment: root.textAlignment
        color: "#1C1C2E"
        text: root.plainText
        selectByMouse: true
        leftPadding: 2
        rightPadding: 2

        onTextChanged: root.textEditing(root.blockId, text)
    }

    // ── overflow indicator ───────────────────────────────────────────────────

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 3
        radius: 1
        color: "#EF5350"
        visible: root.editingActive
                 && editArea.contentHeight > root.originalHeight
                 && root.originalHeight > 0
    }

    // ── font-fallback warning banner ─────────────────────────────────────────

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: fallbackLabel.implicitHeight + 6
        color: "#FFF8E1"
        border.color: "#FFB300"
        border.width: 1
        radius: 2
        visible: root.editingActive && root.fallbackFontName !== ""
        z: 5

        Text {
            id: fallbackLabel
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                      leftMargin: 4; rightMargin: 4 }
            text: qsTr("Font substituted: %1").arg(root.fallbackFontName)
            font.pixelSize: 9
            color: "#7B4F00"
            elide: Text.ElideRight
            wrapMode: Text.NoWrap
        }
    }

    // ── resize handles (visible when selected, not editing) ──────────────────

    ResizeHandles {
        anchors.fill: parent
        visible: root.isSelected && !root.editingActive
        resizeMode: root.resizeMode

        onResized: function(dx, dy, dw, dh) {
            // Snap x/y movement to sibling left/top edges
            if (root.siblingRects.length > 0) {
                const lefts   = root.siblingRects.map(r => r.x)
                const tops    = root.siblingRects.map(r => r.y)
                const rights  = root.siblingRects.map(r => r.x + r.width)
                const bottoms = root.siblingRects.map(r => r.y + r.height)

                if (Math.abs(dx) > 0) dx += snapDelta(root.x + dx, lefts.concat(rights))
                if (Math.abs(dy) > 0) dy += snapDelta(root.y + dy, tops.concat(bottoms))
                if (Math.abs(dw) > 0) dw += snapDelta(root.x + root.width + dw, rights.concat(lefts))
                if (Math.abs(dh) > 0) dh += snapDelta(root.y + root.height + dh, bottoms.concat(tops))
            }
            root.resized(root.blockId, dx, dy, dw, dh)
        }
    }

    // ── contextual toolbar (above block when selected) ───────────────────────

    EditingToolbar {
        id: toolbar
        visible: root.isSelected || root.editingActive
        anchors { left: parent.left; bottom: parent.top; bottomMargin: 4 }
        fontFamily:  root.fontFamily
        fontSize:    root.fontSize
        bold:        root.bold
        italic:      root.italic
        alignment:   root.textAlignment
        resizeMode:  root.resizeMode

        onFontSizeChangeRequested:    function(s) { root.styleChanged(root.blockId, "fontSize",   s) }
        onBoldToggled:                            { root.styleChanged(root.blockId, "bold",       !root.bold)   }
        onItalicToggled:                          { root.styleChanged(root.blockId, "italic",     !root.italic) }
        onAlignmentChangeRequested:   function(a) { root.styleChanged(root.blockId, "alignment",  a) }
        onResizeModeChangeRequested:  function(m) { root.resizeMode = m }
    }

    // ── mouse area (hover + click + double-click) ─────────────────────────────

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.isEditable ? Qt.IBeamCursor : Qt.ForbiddenCursor
        enabled: !root.editingActive

        onEntered:  root.blockHovered(root.blockId)
        onExited:   root.blockUnhovered(root.blockId)
        onClicked:  root.blockClicked(root.blockId)
        onDoubleClicked: {
            if (root.isEditable) {
                root.editingActive = true
                editArea.forceActiveFocus()
                editArea.cursorPosition = editArea.length
            }
        }
    }

    Keys.onEscapePressed: root.editingActive = false
}
