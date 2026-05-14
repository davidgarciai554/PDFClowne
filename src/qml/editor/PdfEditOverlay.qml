import QtQuick
import PDFClowne.Editing

FocusScope {
    id: root
    focus: visible

    property var controller: null
    property int pageIndex: -1
    property real pageScale: 1.0
    property bool debugRegions: false
    property bool debugInputLogging: false
    property bool suppressFinishForCurrentClick: false
    property bool inputEnabled: true
    property color accentColor: "#4D8DFF"
    property var activeBox: activeSelectionBox()

    function updateControllerMetrics() {
        if (!controller)
            return
        controller.updatePageViewMetrics(pageIndex,
                                         Math.max(1, Math.round(width)),
                                         Math.max(1, Math.round(height)),
                                         pageScale)
    }

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

        suppressFinishForCurrentClick = true
        finishSuppressionTimer.restart()

        var pdfX = Number(position.x || 0) / Math.max(0.01, pageScale)
        var pdfY = Number(position.y || 0) / Math.max(0.01, pageScale)
        if (debugInputLogging)
            console.log("[PDF_EDIT_CLICK]", "page=", pageIndex, "x=", position.x, "y=", position.y, "pdfX=", pdfX, "pdfY=", pdfY)
        var started = controller.beginSession(pageIndex,
                                              pdfX,
                                              pdfY,
                                              Math.max(1, Math.round(width)),
                                              Math.max(1, Math.round(height)),
                                              pageScale)

        if (started) {
            root.forceActiveFocus(Qt.MouseFocusReason)
            glyphLayer.forceActiveFocus(Qt.MouseFocusReason)
            Qt.callLater(function() {
                if (controller && controller.active)
                    glyphLayer.forceActiveFocus(Qt.MouseFocusReason)
                if (debugInputLogging)
                    console.log("[PDF_EDIT_FOCUS]", "afterBegin rootFocus=", root.activeFocus, "glyphFocus=", glyphLayer.activeFocus, "active=", controller ? controller.active : false)
            })
            if (debugInputLogging)
                console.log("[PDF_EDIT_FOCUS]", "started=", started, "rootFocus=", root.activeFocus, "glyphFocus=", glyphLayer.activeFocus, "active=", controller.active)
            Qt.inputMethod.show()
        } else if (debugInputLogging) {
            console.log("[PDF_EDIT_BEGIN]", "miss page=", pageIndex, "active=", controller.active)
        }
    }

    function commitActiveEditor() {
        if (controller && controller.commitActiveEdit)
            controller.commitActiveEdit()
    }

    function activeSelectionBox() {
        var quads = root.controller && root.controller.active
                ? root.parseArray(root.controller.selectionQuadsJson)
                : []
        if (!quads || quads.length <= 0)
            return { x: 0, y: 0, width: 0, height: 0 }

        var quad = quads[0]
        if (!quad || quad.length < 4)
            return { x: 0, y: 0, width: 0, height: 0 }

        var minX = Number.MAX_VALUE
        var minY = Number.MAX_VALUE
        var maxX = -Number.MAX_VALUE
        var maxY = -Number.MAX_VALUE
        for (var i = 0; i < quad.length; ++i) {
            var point = quad[i]
            if (!point || point.length < 2)
                continue
            var x = Number(point[0]) * root.pageScale
            var y = Number(point[1]) * root.pageScale
            minX = Math.min(minX, x)
            minY = Math.min(minY, y)
            maxX = Math.max(maxX, x)
            maxY = Math.max(maxY, y)
        }

        if (minX === Number.MAX_VALUE)
            return { x: 0, y: 0, width: 0, height: 0 }

        return { x: minX, y: minY, width: Math.max(1, maxX - minX), height: Math.max(1, maxY - minY) }
    }

    function caretXInActiveBox() {
        if (!controller)
            return 0

        var textLength = Math.max(1, String(controller.activeText || "").length)
        var cursor = Math.max(0, Math.min(Number(controller.cursorPosition || 0), textLength))
        if (controller.replaceSelectionOnInput || controller.selectionLength > 0)
            cursor = Number(controller.selectionStart || 0)

        return activeBox.x + activeBox.width * (cursor / textLength)
    }

    Timer {
        id: finishSuppressionTimer
        interval: 250
        repeat: false
        onTriggered: root.suppressFinishForCurrentClick = false
    }

    Keys.priority: Keys.AfterItem
    Keys.onPressed: function(event) {
        if (!controller || !controller.active)
            return

        if (glyphLayer.activeFocus && !event.accepted)
            return

        if (debugInputLogging)
            console.log("[PDF_EDIT_KEY]", "source=QML_FALLBACK key=", event.key, "textLength=", event.text ? event.text.length : 0, "acceptedBefore=", event.accepted)

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

        if (event.key === Qt.Key_Home) {
            controller.moveCursorHome()
            event.accepted = true
            return
        }

        if (event.key === Qt.Key_End) {
            controller.moveCursorEnd()
            event.accepted = true
            return
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            controller.commitActiveText("EnterPressed")
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

    onWidthChanged: updateControllerMetrics()
    onHeightChanged: updateControllerMetrics()
    onPageScaleChanged: updateControllerMetrics()
    onPageIndexChanged: updateControllerMetrics()
    onVisibleChanged: if (visible) updateControllerMetrics()
    Component.onCompleted: updateControllerMetrics()
    onActiveFocusChanged: {
        if (debugInputLogging && controller && controller.active)
            console.log("[PDF_EDIT_FOCUS]", "rootActiveFocus=", activeFocus, "glyphFocus=", glyphLayer.activeFocus, "suppressed=", suppressFinishForCurrentClick)
    }

    PdfGlyphOverlayItem {
        id: glyphLayer
        anchors.fill: parent
        controller: root.controller
        focus: true
        z: 20
    }

    Rectangle {
        id: activeFrame
        visible: root.controller && root.controller.active && root.activeBox.width > 0 && root.activeBox.height > 0
        enabled: false
        z: 25
        x: root.activeBox.x
        y: root.activeBox.y
        width: root.activeBox.width
        height: root.activeBox.height
        color: "transparent"
        border.color: root.accentColor
        border.width: 1
    }

    Rectangle {
        id: caret
        visible: root.controller && root.controller.active && root.activeBox.height > 0
        enabled: false
        z: 26
        x: root.caretXInActiveBox()
        y: root.activeBox.y
        width: Math.max(1, Math.round(1.5 * root.pageScale))
        height: root.activeBox.height
        color: root.accentColor
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
        enabled: root.inputEnabled
        acceptedButtons: Qt.LeftButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.Stylus | PointerDevice.TouchScreen
        onTapped: root.beginAt(point.position)
    }
}
