pragma ComponentBehavior: Bound
import QtQuick
import PDFClowne

Item {
    id: root

    property var pdfDocument: null
    property string previewSource: pdfDocument ? pdfDocument.previewSource : ""
    property var pageSources: previewSource.length > 0 ? [previewSource] : []
    property var thumbnailSources: []
    property int pageCount: pageSources && pageSources.length !== undefined ? pageSources.length : 0
    property string pageSizesJson: "[]"
    property bool sidePanelVisible: true
    property string sidePanelMode: "thumbnails"
    property var cachedPageSources: []
    property var cachedThumbnailSources: []
    readonly property var visiblePageSources: normalizedPageSources()
    readonly property var pageSizes: normalizedPageSizes()
    readonly property var pageRows: buildPageRows()
    property var pageRotations: []
    property int currentPageIndex: 0
    property real zoom: 1.0
    property string layoutMode: "continuous"
    property string zoomMode: "fitPage"
    property bool separateCoverPage: true
    property real renderScale: 4.0
    property real currentBaseScale: 1.0
    readonly property real currentZoomPercent: currentBaseScale * renderScale * zoom * 100
    property var zoomInAction: null
    property var zoomOutAction: null
    property var renderPageAction: null
    property var renderThumbnailAction: null
    property var currentPageChangedAction: null

    onCurrentPageIndexChanged: navigateToPage(currentPageIndex)
    onZoomChanged: updateCurrentBaseScale()
    onLayoutModeChanged: relayoutToCurrentPage()
    onZoomModeChanged: relayoutToCurrentPage()
    onPageRowsChanged: relayoutToCurrentPage()
    onPageSourcesChanged: {
        syncPageCache()
        resetPageCache()
    }
    onThumbnailSourcesChanged: {
        syncThumbnailCache()
        resetThumbnailCache()
    }
    onPageCountChanged: resetPageCache()
    Component.onCompleted: {
        syncPageCache()
        syncThumbnailCache()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.isDark ? "#12121F" : "#D8D9E8"
    }

    Rectangle {
        id: sidePanel
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
        width: root.sidePanelVisible ? 154 : 0
        visible: root.sidePanelVisible
        clip: true
        color: Theme.surface
        border.color: Theme.border

        ListView {
            id: thumbnailList
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8
            clip: true
            model: root.visiblePageSources.length

            delegate: Rectangle {
                id: thumbnailFrame
                required property int index

                width: thumbnailList.width
                height: 150
                radius: Theme.radius
                color: root.currentPageIndex === index ? Theme.tabActive
                                                       : thumbnailMouse.containsMouse ? Theme.hover : "transparent"
                border.color: root.currentPageIndex === index ? Theme.accent : Theme.border

                Image {
                    id: thumbnailImage
                    anchors {
                        top: parent.top
                        horizontalCenter: parent.horizontalCenter
                        topMargin: 8
                    }
                    width: Math.min(parent.width - 18, 104)
                    height: 116
                    source: root.thumbnailSourceForPage(thumbnailFrame.index)
                    fillMode: Image.PreserveAspectFit
                    cache: true
                    smooth: true
                    rotation: root.rotationForPage(thumbnailFrame.index)
                    transformOrigin: Item.Center
                }

                Text {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        bottomMargin: 6
                    }
                    text: String(thumbnailFrame.index + 1)
                    color: Theme.secondaryText
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                }

                MouseArea {
                    id: thumbnailMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (root.currentPageChangedAction)
                            root.currentPageChangedAction(thumbnailFrame.index)
                        else
                            root.navigateToPage(thumbnailFrame.index)
                    }
                }

                Component.onCompleted: root.ensureThumbnail(thumbnailFrame.index)
            }
        }
    }

    Flickable {
        id: viewport
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: sidePanel.right
            right: parent.right
        }
        clip: true
        contentWidth: Math.max(width, pagesColumn.width + 56)
        contentHeight: Math.max(height, pagesColumn.height + 56)
        boundsBehavior: Flickable.StopAtBounds
        onContentYChanged: root.updateCurrentPage()
        onMovementEnded: root.ensureViewportPages()
        onWidthChanged: Qt.callLater(root.updateCurrentBaseScale)
        onHeightChanged: Qt.callLater(root.updateCurrentBaseScale)
        Component.onCompleted: {
            root.relayoutToCurrentPage()
            root.ensureViewportPages()
        }

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
            width: Math.max(1, childrenRect.width)
            height: Math.max(1, childrenRect.height)
            spacing: root.isContinuousLayout() ? 18 : 28

            Repeater {
                model: root.pageRows

                Row {
                    id: pageRow
                    required property var modelData

                    spacing: 18

                    Repeater {
                        model: pageRow.modelData.pages

                        Item {
                            id: pageFrame
                            required property var modelData

                            readonly property bool pageItem: true
                            readonly property int pageIndex: modelData.pageIndex
                            readonly property string pageSource: root.sourceForPage(pageIndex)
                            readonly property int pageRotation: root.rotationForPage(pageIndex)
                            readonly property bool sideways: Math.abs(pageRotation % 180) === 90
                            readonly property var pageSize: root.sizeForPage(pageIndex)
                            readonly property real sourceWidth: pageImage.implicitWidth > 0 ? pageImage.implicitWidth : pageSize.width * root.renderScale
                            readonly property real sourceHeight: pageImage.implicitHeight > 0 ? pageImage.implicitHeight : pageSize.height * root.renderScale
                            readonly property real rotatedWidth: sideways ? sourceHeight : sourceWidth
                            readonly property real rotatedHeight: sideways ? sourceWidth : sourceHeight
                            readonly property bool paired: root.isTwoPageLayout()
                            readonly property real availableWidth: Math.max(1, viewport.width - 56)
                            readonly property real availableHeight: Math.max(1, viewport.height - 56)
                            readonly property real pageAvailableWidth: paired ? Math.max(1, (availableWidth - pageRow.spacing) / 2) : availableWidth
                            readonly property real widthScale: rotatedWidth > 0 ? (pageAvailableWidth * 0.9) / rotatedWidth : 1.0
                            readonly property real heightScale: rotatedHeight > 0 ? availableHeight / rotatedHeight : 1.0
                            readonly property real pageScale: rotatedWidth > 0 && rotatedHeight > 0
                                                                  ? Math.min(pageAvailableWidth / rotatedWidth, availableHeight / rotatedHeight)
                                                                  : 1.0
                            readonly property real baseScale: root.baseScaleFor(pageFrame)

                            width: Math.max(1, rotatedWidth * baseScale * root.zoom)
                            height: Math.max(1, rotatedHeight * baseScale * root.zoom)
                            onBaseScaleChanged: if (pageIndex === root.currentPageIndex) root.updateCurrentBaseScale()

                            Image {
                                id: pageImage
                                anchors.centerIn: parent
                                width: Math.max(1, implicitWidth * pageFrame.baseScale * root.zoom)
                                height: Math.max(1, implicitHeight * pageFrame.baseScale * root.zoom)
                                source: pageFrame.pageSource
                                fillMode: Image.PreserveAspectFit
                                cache: false
                                smooth: true
                                mipmap: true
                                rotation: pageFrame.pageRotation
                                transformOrigin: Item.Center
                                onImplicitWidthChanged: if (pageFrame.pageIndex === root.currentPageIndex) root.updateCurrentBaseScale()
                                onImplicitHeightChanged: if (pageFrame.pageIndex === root.currentPageIndex) root.updateCurrentBaseScale()
                            }

                            Rectangle {
                                anchors.fill: pageImage
                                visible: pageImage.source.toString().length === 0
                                color: Theme.isDark ? "#202033" : "#F5F6FB"
                                border.color: Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "Cargando " + String(pageFrame.pageIndex + 1)
                                    color: Theme.secondaryText
                                    font.pixelSize: 12
                                }
                            }

                        }
                    }
                }
            }
        }
    }

    function isTwoPageLayout() {
        return layoutMode === "twoPage" || layoutMode === "twoPageContinuous"
    }

    function isContinuousLayout() {
        return layoutMode === "continuous" || layoutMode === "twoPageContinuous"
    }

    function baseScaleFor(pageFrame) {
        if (zoomMode === "fitWidth")
            return pageFrame.widthScale
        if (zoomMode === "fitHeight")
            return pageFrame.heightScale
        if (zoomMode === "actualSize")
            return 1.0 / renderScale
        return pageFrame.pageScale
    }

    function resetPageCache() {
        relayoutToCurrentPage()
        Qt.callLater(ensureViewportPages)
    }

    function syncPageCache() {
        var sources = []
        if (pageSources && pageSources.length !== undefined) {
            for (var i = 0; i < pageSources.length; ++i)
                sources.push(pageSources[i] || "")
        }
        cachedPageSources = sources
    }

    function syncThumbnailCache() {
        var sources = []
        if (thumbnailSources && thumbnailSources.length !== undefined) {
            for (var i = 0; i < thumbnailSources.length; ++i)
                sources.push(thumbnailSources[i] || "")
        }
        cachedThumbnailSources = sources
    }

    function resetThumbnailCache() {
        Qt.callLater(function() {
            for (var i = 0; i < Math.min(visiblePageSources.length, 12); ++i)
                ensureThumbnail(i)
        })
    }

    function relayoutToCurrentPage() {
        Qt.callLater(function() {
            navigateToPage(currentPageIndex)
            updateCurrentBaseScale()
        })
    }

    function rotationForPage(index) {
        if (!pageRotations || index < 0 || index >= pageRotations.length)
            return 0
        return pageRotations[index] || 0
    }

    function normalizedPageSources() {
        var sources = []
        if (cachedPageSources && cachedPageSources.length !== undefined) {
            for (var i = 0; i < cachedPageSources.length; ++i) {
                sources.push(cachedPageSources[i] || "")
            }
        }

        while (sources.length < pageCount)
            sources.push("")

        if (sources.length === 0 && previewSource.length > 0)
            sources.push(previewSource)

        return sources
    }

    function normalizedPageSizes() {
        var sizes = []
        try {
            sizes = JSON.parse(pageSizesJson || "[]")
        } catch(e) {
            sizes = []
        }

        while (sizes.length < visiblePageSources.length)
            sizes.push({ width: 612, height: 792 })

        return sizes
    }

    function sizeForPage(index) {
        if (index >= 0 && index < pageSizes.length && pageSizes[index])
            return pageSizes[index]
        return { width: 612, height: 792 }
    }

    function sourceForPage(index) {
        if (index >= 0 && index < visiblePageSources.length)
            return visiblePageSources[index] || ""
        return ""
    }

    function thumbnailSourceForPage(index) {
        if (cachedThumbnailSources && index >= 0 && index < cachedThumbnailSources.length)
            return cachedThumbnailSources[index] || sourceForPage(index)
        return sourceForPage(index)
    }

    function ensurePage(index) {
        if (!renderPageAction || index < 0 || index >= visiblePageSources.length)
            return
        if (visiblePageSources[index] && visiblePageSources[index].length > 0)
            return

        var rendered = renderPageAction(index, renderScale)
        if (!rendered || rendered.length === 0)
            return

        var sources = visiblePageSources.slice()
        sources[index] = rendered
        cachedPageSources = sources
    }

    function ensureThumbnail(index) {
        if (!renderThumbnailAction || index < 0 || index >= visiblePageSources.length)
            return
        if (cachedThumbnailSources && index < cachedThumbnailSources.length && cachedThumbnailSources[index] && cachedThumbnailSources[index].length > 0)
            return

        var rendered = renderThumbnailAction(index)
        if (!rendered || rendered.length === 0)
            return

        var thumbs = []
        if (cachedThumbnailSources && cachedThumbnailSources.length !== undefined)
            thumbs = cachedThumbnailSources.slice()
        while (thumbs.length < visiblePageSources.length)
            thumbs.push("")
        thumbs[index] = rendered
        cachedThumbnailSources = thumbs
    }

    function ensureViewportPages() {
        var top = viewport.contentY - viewport.height * 0.5
        var bottom = viewport.contentY + viewport.height * 1.5

        forEachPageItem(function(item) {
            var itemTop = pagesColumn.y + item.parent.y + item.y
            var itemBottom = itemTop + item.height
            if (itemBottom >= top && itemTop <= bottom)
                ensurePage(item.pageIndex)
        })
    }

    function buildPageRows() {
        var sources = normalizedPageSources()
        var rows = []

        if (layoutMode === "single") {
            var singlePage = Math.max(0, Math.min(currentPageIndex, sources.length - 1))
            if (sources.length > 0)
                rows.push({ pages: [{ pageIndex: singlePage, source: sources[singlePage] }] })
            return rows
        }

        if (layoutMode === "twoPage") {
            if (sources.length === 0)
                return rows

            var rightPage = currentPageIndex
            var leftPage = currentPageIndex

            if (currentPageIndex % 2 === 0) {
                rightPage = currentPageIndex
                leftPage = currentPageIndex + 1
            } else {
                leftPage = currentPageIndex
                rightPage = currentPageIndex - 1
            }

            var spread = []
            if (rightPage >= 0 && rightPage < sources.length)
                spread.push({ pageIndex: rightPage, source: sources[rightPage] })
            if (leftPage >= 0 && leftPage < sources.length)
                spread.push({ pageIndex: leftPage, source: sources[leftPage] })
            rows.push({ pages: spread })
            return rows
        }

        if (!isTwoPageLayout()) {
            for (var i = 0; i < sources.length; ++i)
                rows.push({ pages: [{ pageIndex: i, source: sources[i] }] })
            return rows
        }

        for (var page = 0; page < sources.length; page += 2) {
            var pair = []
            pair.push({ pageIndex: page, source: sources[page] })
            if (page + 1 < sources.length)
                pair.push({ pageIndex: page + 1, source: sources[page + 1] })
            rows.push({ pages: pair })
        }

        return rows
    }

    function forEachPageItem(callback) {
        function visit(item) {
            if (!item)
                return

            if (item.pageItem)
                callback(item)

            var children = item.children || []
            for (var i = 0; i < children.length; ++i)
                visit(children[i])
        }

        visit(pagesColumn)
    }

    function navigateToPage(index) {
        var target = Math.max(0, Math.min(index, visiblePageSources.length - 1))
        if (layoutMode === "single") {
            ensurePage(target)
            ensureThumbnail(target)
            viewport.contentY = 0
            Qt.callLater(function() {
                updateCurrentBaseScale()
                ensureViewportPages()
            })
            return
        }

        jumpToPage(target)
    }

    function jumpToPage(index) {
        var target = Math.max(0, Math.min(index, visiblePageSources.length - 1))
        Qt.callLater(function() {
            var found = false
            forEachPageItem(function(item) {
                if (found || item.pageIndex !== target)
                    return

                viewport.contentY = Math.max(0, pagesColumn.y + item.parent.y + item.y - 18)
                found = true
            })

            if (!found) {
                ensurePage(target)
                updateCurrentBaseScale()
                ensureViewportPages()
                return
            }

            updateCurrentPage()
            updateCurrentBaseScale()
            ensureViewportPages()
        })
    }

    function updateCurrentBaseScale() {
        var found = false
        forEachPageItem(function(item) {
            if (found || item.pageIndex !== currentPageIndex)
                return

            var scale = Number(item.baseScale)
            if (isFinite(scale) && scale > 0)
                currentBaseScale = scale

            found = true
        })
    }

    function updateCurrentPage() {
        if (layoutMode === "single") {
            updateCurrentBaseScale()
            return
        }

        var centerY = viewport.contentY + viewport.height / 2
        var closest = 0
        var bestDistance = Number.MAX_VALUE

        forEachPageItem(function(item) {
            if (item.height <= 0 || item.pageIndex === undefined)
                return

            var pageCenter = pagesColumn.y + item.parent.y + item.y + item.height / 2
            var distance = Math.abs(pageCenter - centerY)
            if (distance < bestDistance) {
                bestDistance = distance
                closest = item.pageIndex
            }
        })

        if (closest !== currentPageIndex && currentPageChangedAction)
            currentPageChangedAction(closest)

        updateCurrentBaseScale()
    }
}
