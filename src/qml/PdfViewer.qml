pragma ComponentBehavior: Bound
import QtQuick
import PDFClowne

Item {
    id: root

    property var pdfDocument: null
    property string previewSource: pdfDocument ? pdfDocument.previewSource : ""
    property var pageSources: previewSource.length > 0 ? [previewSource] : []
    readonly property var visiblePageSources: normalizedPageSources()
    property var pageRotations: []
    property int currentPageIndex: 0
    property real zoom: 1.0
    property string viewMode: "fitPage"
    property real renderScale: 4.0
    property real currentBaseScale: 1.0
    readonly property real currentZoomPercent: currentBaseScale * renderScale * zoom * 100
    property var zoomInAction: null
    property var zoomOutAction: null
    property var currentPageChangedAction: null

    onCurrentPageIndexChanged: jumpToPage(currentPageIndex)
    onZoomChanged: updateCurrentBaseScale()
    onViewModeChanged: {
        jumpToPage(currentPageIndex)
        Qt.callLater(updateCurrentBaseScale)
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.isDark ? "#12121F" : "#D8D9E8"
    }

    Flickable {
        id: viewport
        anchors.fill: parent
        clip: true
        contentWidth: Math.max(width, pagesColumn.width + 56)
        contentHeight: Math.max(height, pagesColumn.height + 56)
        boundsBehavior: Flickable.StopAtBounds
        onContentYChanged: root.updateCurrentPage()
        onWidthChanged: Qt.callLater(root.updateCurrentBaseScale)
        onHeightChanged: Qt.callLater(root.updateCurrentBaseScale)
        Component.onCompleted: Qt.callLater(function() {
            root.jumpToPage(root.currentPageIndex)
            root.updateCurrentBaseScale()
        })

        WheelHandler {
            acceptedModifiers: Qt.ControlModifier
            onWheel: function(event) {
                if (event.angleDelta.y > 0 && root.zoomInAction)
                    root.zoomInAction()
                else if (event.angleDelta.y < 0 && root.zoomOutAction)
                    root.zoomOutAction()
                event.accepted = true
            }
        }

        Column {
            id: pagesColumn
            x: Math.max(28, (viewport.width - width) / 2)
            y: 28
            spacing: 18

            Repeater {
                model: root.visiblePageSources

                Item {
                    id: pageFrame
                    required property int index
                    required property string modelData
                    readonly property int pageRotation: root.rotationForPage(index)
                    readonly property bool sideways: Math.abs(pageRotation % 180) === 90
                    readonly property real sourceWidth: pageImage.implicitWidth
                    readonly property real sourceHeight: pageImage.implicitHeight
                    readonly property real rotatedWidth: sideways ? sourceHeight : sourceWidth
                    readonly property real rotatedHeight: sideways ? sourceWidth : sourceHeight
                    readonly property real widthScale: rotatedWidth > 0 ? ((viewport.width - 56) * 0.8) / rotatedWidth : 1.0
                    readonly property real pageScale: rotatedWidth > 0 && rotatedHeight > 0
                                                      ? Math.min((viewport.width - 56) / rotatedWidth,
                                                                 (viewport.height - 56) / rotatedHeight)
                                                      : 1.0
                    readonly property real baseScale: root.viewMode === "fitPage" ? pageScale : widthScale
                    width: Math.max(1, rotatedWidth * baseScale * root.zoom)
                    height: Math.max(1, rotatedHeight * baseScale * root.zoom)
                    onBaseScaleChanged: if (index === root.currentPageIndex) root.updateCurrentBaseScale()

                    Image {
                        id: pageImage
                        anchors.centerIn: parent
                        width: Math.max(1, implicitWidth * pageFrame.baseScale * root.zoom)
                        height: Math.max(1, implicitHeight * pageFrame.baseScale * root.zoom)
                        source: pageFrame.modelData
                        fillMode: Image.PreserveAspectFit
                        cache: false
                        smooth: true
                        mipmap: true
                        rotation: pageFrame.pageRotation
                        transformOrigin: Item.Center
                        onImplicitWidthChanged: if (pageFrame.index === root.currentPageIndex) root.updateCurrentBaseScale()
                        onImplicitHeightChanged: if (pageFrame.index === root.currentPageIndex) root.updateCurrentBaseScale()
                    }
                }
            }
        }
    }

    function rotationForPage(index) {
        if (!pageRotations || index < 0 || index >= pageRotations.length)
            return 0
        return pageRotations[index] || 0
    }

    function normalizedPageSources() {
        var sources = []
        if (pageSources && pageSources.length !== undefined) {
            for (var i = 0; i < pageSources.length; ++i) {
                if (pageSources[i] && pageSources[i].length > 0)
                    sources.push(pageSources[i])
            }
        }

        if (sources.length === 0 && previewSource.length > 0)
            sources.push(previewSource)

        return sources
    }

    function jumpToPage(index) {
        var target = Math.max(0, Math.min(index, visiblePageSources.length - 1))
        Qt.callLater(function() {
            for (var i = 0; i < pagesColumn.children.length; ++i) {
                var item = pagesColumn.children[i]
                if (item && item.index === target) {
                    viewport.contentY = Math.max(0, pagesColumn.y + item.y - 18)
                    updateCurrentPage()
                    updateCurrentBaseScale()
                    return
                }
            }
        })
    }

    function updateCurrentBaseScale() {
        for (var i = 0; i < pagesColumn.children.length; ++i) {
            var item = pagesColumn.children[i]
            if (!item || item.index !== currentPageIndex)
                continue

            var scale = Number(item.baseScale)
            if (isFinite(scale) && scale > 0)
                currentBaseScale = scale

            return
        }
    }

    function updateCurrentPage() {
        var centerY = viewport.contentY + viewport.height / 2
        var closest = 0
        var bestDistance = Number.MAX_VALUE

        for (var i = 0; i < pagesColumn.children.length; ++i) {
            var item = pagesColumn.children[i]
            if (!item || item.height <= 0 || item.index === undefined)
                continue

            var pageCenter = pagesColumn.y + item.y + item.height / 2
            var distance = Math.abs(pageCenter - centerY)
            if (distance < bestDistance) {
                bestDistance = distance
                closest = item.index
            }
        }

        if (closest !== currentPageIndex) {
            currentPageIndex = closest
            if (currentPageChangedAction)
                currentPageChangedAction(closest)
        }

        updateCurrentBaseScale()
    }
}
