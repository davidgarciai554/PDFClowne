import QtQuick
import PDFClowne.Editing

FocusScope {
    id: root
    focus: visible

    property var controller: null
    property int pageIndex: -1
    property real pageScale: 1.0
    property bool debugRegions: false
    property color accentColor: "#4D8DFF"

    function parseArray(jsonText) {
        try {
            var parsed = JSON.parse(jsonText || "[]")
            return parsed && parsed.length !== undefined ? parsed : []
        } catch (e) {
            return []
        }
    }

    function rectFromBox(box) {
        return {
            x: Number(box && box.x !== undefined ? box.x : 0) * pageScale,
            y: Number(box && box.y !== undefined ? box.y : 0) * pageScale,
            width: Number(box && box.width !== undefined ? box.width : 1) * pageScale,
            height: Number(box && box.height !== undefined ? box.height : 1) * pageScale
        }
    }

    function beginAt(position) {
        if (!controller)
            return

        var pdfX = Number(position.x || 0) / Math.max(0.01, pageScale)
        var pdfY = Number(position.y || 0) / Math.max(0.01, pageScale)
        var started = controller.beginSession(pageIndex,
                                              pdfX,
                                              pdfY,
                                              Math.max(1, Math.round(width)),
                                              Math.max(1, Math.round(height)),
                                              pageScale)

        if (started) {
            root.forceActiveFocus(Qt.MouseFocusReason)
            glyphLayer.forceActiveFocus(Qt.MouseFocusReason)
            Qt.inputMethod.show()
        }
    }

    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
        if (!controller || !controller.active)
            return

        if (event.key === Qt.Key_Backspace) {
            controller.handleBackspace()
            event.accepted = true
            return
        }

        if (event.key === Qt.Key_Delete) {
            controller.handleDelete()
            event.accepted = true
            return
        }

        if (event.key === Qt.Key_Left) {
            controller.moveCursorLeft()
            event.accepted = true
            return
        }

        if (event.key === Qt.Key_Right) {
            controller.moveCursorRight()
            event.accepted = true
            return
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            controller.commitActiveText()
            event.accepted = true
            return
        }

        if (event.key === Qt.Key_Escape) {
            controller.cancelActiveEdit()
            event.accepted = true
            return
        }

        if (event.text && event.text.length > 0) {
            controller.handleKeyText(event.text)
            event.accepted = true
            return
        }
    }

    PdfGlyphOverlayItem {
        id: glyphLayer
        anchors.fill: parent
        controller: root.controller
        focus: true
        z: 20
    }

    Repeater {
        model: root.debugRegions && root.controller
               ? root.parseArray(root.controller.editableRegionsJson)
               : []

        Rectangle {
            required property var modelData
            enabled: false
            z: 5
            readonly property var mapped: root.rectFromBox(modelData.box || {})
            x: mapped.x
            y: mapped.y
            width: Math.max(1, mapped.width)
            height: Math.max(1, mapped.height)
            color: "transparent"
            border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.42)
            border.width: 1
        }
    }

    Repeater {
        model: root.controller && root.controller.active
               ? root.parseArray(root.controller.selectionQuadsJson)
               : []

        Rectangle {
            required property var modelData
            enabled: false
            z: 5
            readonly property real minX: Math.min(modelData[0][0], modelData[1][0], modelData[2][0], modelData[3][0]) * root.pageScale
            readonly property real minY: Math.min(modelData[0][1], modelData[1][1], modelData[2][1], modelData[3][1]) * root.pageScale
            readonly property real maxX: Math.max(modelData[0][0], modelData[1][0], modelData[2][0], modelData[3][0]) * root.pageScale
            readonly property real maxY: Math.max(modelData[0][1], modelData[1][1], modelData[2][1], modelData[3][1]) * root.pageScale
            x: minX
            y: minY
            width: Math.max(1, maxX - minX)
            height: Math.max(1, maxY - minY)
            color: "transparent"
            border.color: root.accentColor
            border.width: 1
        }
    }

    TapHandler {
        id: editTapHandler
        acceptedDevices: PointerDevice.Mouse | PointerDevice.Stylus | PointerDevice.TouchScreen
        onTapped: root.beginAt(point.position)
    }
}
