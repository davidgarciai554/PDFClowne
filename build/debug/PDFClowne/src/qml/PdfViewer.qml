pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import PDFClowne

FocusScope {
    id: root
    focus: visible

    property var pdfDocument: null
    property string previewSource: pdfDocument ? pdfDocument.previewSource : ""
    property var pageSources: previewSource.length > 0 ? [previewSource] : []
    property var thumbnailSources: []
    property int pageCount: pageSources && pageSources.length !== undefined ? pageSources.length : 0
    property string pageSizesJson: "[]"
    property bool sidePanelVisible: true
    property string sidePanelMode: "thumbnails"
    property var outlineEntries: []
    property var pageLinks: []
    property string searchQuery: ""
    property var searchResults: []
    property int activeSearchResultIndex: -1
    property var thumbnailListView: null
    property var cachedPageSources: []
    property var cachedThumbnailSources: []
    property var pendingPageRequests: ({})
    property var pendingThumbnailRequests: ({})
    property bool pageChangeFromViewport: false
    property int pendingJumpPage: -1
    property bool programmaticJumpActive: false
    property int prefetchRadius: 8
    property bool largeJumpMode: false
    property int largeJumpTargetPage: -1
    property real largeJumpPreviewScale: 1.0
    property bool largeJumpHighQualityRequested: false
    property bool pageTransitionActive: false
    property int pageTransitionTargetPage: -1
    property bool pageTransitionHasPreview: false
    property bool progressiveRenderingEnabled: false
    property real progressivePreviewScale: 0.9
    property var progressiveHighQualityRequests: ({})
    readonly property var visiblePageSources: normalizedPageSources()
    readonly property var pageSizes: normalizedPageSizes()
    readonly property var pageRows: buildPageRows()
    readonly property bool viewportInteracting: viewport.moving || viewport.flicking
    property int lastPageRowCount: 0
    property var pageRotations: []
    property int currentPageIndex: 0
    property string selectedText: ""
    property real zoom: 1.0
    property string layoutMode: "continuous"
    property string zoomMode: "fitPage"
    property bool separateCoverPage: true
    property bool presentationMode: false
    property bool handToolEnabled: false
    property bool snapToPage: false
    property real pageSpacing: 18
    property real renderScale: 2.5
    property real currentBaseScale: 1.0
    readonly property real currentZoomPercent: currentBaseScale * renderScale * zoom * 100
    property var zoomInAction: null
    property var zoomOutAction: null
    property var requestPageRenderAction: null
    property var requestThumbnailRenderAction: null
    property var currentPageChangedAction: null
    property var sidePanelModeChangedAction: null
    property var outlineActivatedAction: null
    property var linkActivatedAction: null
    property var searchResultActivatedAction: null
    property string selectionGeometryJson: "[]"
    property int selectionPageIndex: -1
    property var beginSelectionAction: null
    property var updateSelectionAction: null
    property var endSelectionAction: null
    property var clearSelectionAction: null
    property var copySelectionAction: null
    readonly property bool searchPanelAvailable: searchQuery.trim().length > 0 || searchResults.length > 0 || sidePanelMode === "search"

    Keys.priority: Keys.BeforeItem
    Keys.onShortcutOverride: function(event) {
        if (root.shouldHandleCopyShortcut(event)) {
            event.accepted = true
        }
    }
    Keys.onPressed: function(event) {
        if (!root.shouldHandleCopyShortcut(event))
            return

        event.accepted = true
        if (root.copySelectionAction)
            root.copySelectionAction()
    }

    Timer {
        id: prefetchTimer
        interval: 140
        repeat: false
        onTriggered: root.prefetchAround(root.currentPageIndex, root.effectivePrefetchRadius())
    }

    Timer {
        id: pageTransitionCompleteTimer
        interval: 180
        repeat: false
        onTriggered: root.finishPageTransition()
    }

    Timer {
        id: thumbnailSyncRetryTimer
        interval: 90
        repeat: false
        onTriggered: root.syncThumbnailViewport()
    }

    Timer {
        id: programmaticJumpTimer
        interval: 220
        repeat: false
        onTriggered: root.completeProgrammaticJump()
    }

    onCurrentPageIndexChanged: {
        syncThumbnailViewport()
        if (pageChangeFromViewport) {
            pageChangeFromViewport = false
            pendingJumpPage = -1
            ensurePage(currentPageIndex)
            Qt.callLater(ensureViewportPages)
            prefetchTimer.restart()
            return
        }
        beginPageTransition(currentPageIndex, largeJumpMode)
        pendingJumpPage = currentPageIndex
        programmaticJumpActive = true
        programmaticJumpTimer.restart()
        navigateToPage(currentPageIndex)
        if (largeJumpMode && currentPageIndex === largeJumpTargetPage) {
            Qt.callLater(function() {
                if (!largeJumpHighQualityRequested && requestPageRenderAction)
                    requestPageRenderAction(currentPageIndex, largeJumpPreviewScale)
            })
            return
        }
        if (!pageTransitionActive)
            prefetchTimer.restart()
    }
    onZoomChanged: updateCurrentBaseScale()
    onLayoutModeChanged: relayoutToCurrentPage()
    onZoomModeChanged: relayoutToCurrentPage()
    onPageRowsChanged: {
        var nextRowCount = pageRows && pageRows.length !== undefined ? pageRows.length : 0
        var shouldRelayout = nextRowCount !== lastPageRowCount
        lastPageRowCount = nextRowCount
        if (shouldRelayout)
            relayoutToCurrentPage()
    }
    onPageSourcesChanged: {
        syncPageCache()
        if (pageTransitionActive && pageTransitionTargetPage >= 0 && sourceForPage(pageTransitionTargetPage))
            pageTransitionHasPreview = true
        Qt.callLater(ensureViewportPages)
    }
    onThumbnailSourcesChanged: {
        syncThumbnailCache()
        resetThumbnailCache()
    }
    onPageCountChanged: resetPageCache()
    onProgressiveRenderingEnabledChanged: {
        progressiveHighQualityRequests = {}
        prefetchTimer.restart()
    }
    Component.onCompleted: {
        syncPageCache()
        syncThumbnailCache()
        lastPageRowCount = pageRows && pageRows.length !== undefined ? pageRows.length : 0
        syncThumbnailViewport()
    }

    Rectangle {
        anchors.fill: parent
        color: root.presentationMode ? "#050608" : Theme.isDark ? "#12121F" : "#D8D9E8"
    }

    Rectangle {
        id: sidePanel
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: parent.left
        }
        width: root.sidePanelVisible ? 232 : 0
        visible: root.sidePanelVisible
        clip: true
        color: Theme.surface
        border.color: Theme.border

        Column {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                width: parent.width
                height: 38
                color: Theme.surfaceAlt
                border.color: Theme.border

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(112, parent.width - 12)
                    height: 30
                    radius: Theme.radius
                    color: Theme.background
                    border.color: Theme.border

                    Row {
                        anchors.fill: parent
                        anchors.margins: 3
                        spacing: 4
                        readonly property int segmentCount: root.searchPanelAvailable ? 3 : 2
                        readonly property real segmentWidth: Math.floor((width - spacing * (segmentCount - 1)) / segmentCount)

                        Rectangle {
                            id: thumbnailsModeButton
                            width: parent.segmentWidth
                            height: parent.height
                            radius: Theme.radius
                            color: root.sidePanelMode === "thumbnails" ? Theme.accent : Theme.surface
                            border.color: root.sidePanelMode === "thumbnails" ? Qt.darker(Theme.accent, 1.08) : Theme.border
                            border.width: root.sidePanelMode === "thumbnails" ? 2 : 1

                            Text {
                                anchors.centerIn: parent
                                text: "Miniaturas"
                                color: root.sidePanelMode === "thumbnails" ? Theme.accentText : Theme.text
                                font.pixelSize: 10
                                font.weight: root.sidePanelMode === "thumbnails" ? Font.DemiBold : Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (root.sidePanelModeChangedAction)
                                        root.sidePanelModeChangedAction("thumbnails")
                                    else
                                        root.sidePanelMode = "thumbnails"
                                }
                            }
                        }

                        Rectangle {
                            width: parent.segmentWidth
                            height: parent.height
                            radius: Theme.radius
                            color: root.sidePanelMode === "outline" ? Theme.accent : Theme.surface
                            border.color: root.sidePanelMode === "outline" ? Qt.darker(Theme.accent, 1.08) : Theme.border
                            border.width: root.sidePanelMode === "outline" ? 2 : 1

                            Text {
                                anchors.centerIn: parent
                                text: "Indice"
                                color: root.sidePanelMode === "outline" ? Theme.accentText : Theme.text
                                font.pixelSize: 10
                                font.weight: root.sidePanelMode === "outline" ? Font.DemiBold : Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (root.sidePanelModeChangedAction)
                                        root.sidePanelModeChangedAction("outline")
                                    else
                                        root.sidePanelMode = "outline"
                                }
                            }
                        }

                        Rectangle {
                            visible: root.searchPanelAvailable
                            width: parent.segmentWidth
                            height: parent.height
                            radius: Theme.radius
                            color: root.sidePanelMode === "search" ? Theme.accent : Theme.surface
                            border.color: root.sidePanelMode === "search" ? Qt.darker(Theme.accent, 1.08) : Theme.border
                            border.width: root.sidePanelMode === "search" ? 2 : 1

                            Text {
                                anchors.centerIn: parent
                                text: "Buscar"
                                color: root.sidePanelMode === "search" ? Theme.accentText : Theme.text
                                font.pixelSize: 10
                                font.weight: root.sidePanelMode === "search" ? Font.DemiBold : Font.Medium
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (root.sidePanelModeChangedAction)
                                        root.sidePanelModeChangedAction("search")
                                    else
                                        root.sidePanelMode = "search"
                                }
                            }
                        }
                    }
                }
            }

            Loader {
                id: sidePanelLoader
                width: parent.width
                height: parent.height - 38
                sourceComponent: root.sidePanelMode === "outline"
                               ? outlinePanelComponent
                               : root.sidePanelMode === "search"
                                 ? searchPanelComponent
                                 : thumbnailPanelComponent
                onLoaded: root.syncThumbnailViewport()
            }
        }
    }

    Component {
        id: thumbnailPanelComponent

        ListView {
            id: thumbnailList
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8
            clip: true
            model: root.visiblePageSources.length
            highlightMoveDuration: 0
            highlightResizeDuration: 0
            preferredHighlightBegin: Math.max(0, (height - 150) / 2)
            preferredHighlightEnd: preferredHighlightBegin + 150
            highlightRangeMode: ListView.ApplyRange
            onCountChanged: root.syncThumbnailViewport()
            onHeightChanged: root.syncThumbnailViewport()
            onVisibleChanged: if (visible) root.syncThumbnailViewport()
            Component.onCompleted: {
                root.thumbnailListView = thumbnailList
                root.syncThumbnailViewport()
            }
            Component.onDestruction: {
                if (root.thumbnailListView === thumbnailList)
                    root.thumbnailListView = null
            }

            delegate: Rectangle {
                id: thumbnailFrame
                required property int index

                width: thumbnailList.width
                height: 150
                radius: Theme.radius
                color: root.currentPageIndex === index ? Theme.tabActive
                                                       : thumbnailMouse.containsMouse ? Theme.hover : "transparent"
                border.color: root.currentPageIndex === index ? Theme.accent : Theme.border
                border.width: root.currentPageIndex === index ? 2 : 1

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
                    asynchronous: true
                    retainWhileLoading: true
                    cache: false
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
                    color: root.currentPageIndex === index ? Theme.text : Theme.secondaryText
                    font.pixelSize: 11
                    font.weight: root.currentPageIndex === index ? Font.DemiBold : Font.Normal
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

    Component {
        id: outlinePanelComponent

        ListView {
            id: outlineList
            anchors.fill: parent
            anchors.margins: 8
            spacing: 4
            clip: true
            model: root.outlineEntries

            delegate: Rectangle {
                id: outlineEntry
                required property var modelData

                width: outlineList.width
                height: 30
                radius: Theme.radius
                color: outlineMouse.containsMouse ? Theme.hover : "transparent"
                border.color: modelData.pageIndex === root.currentPageIndex ? Theme.accent : "transparent"

                Text {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 10 + (modelData.depth || 0) * 14
                        rightMargin: 10
                    }
                    text: modelData.title || "Bookmark"
                    color: Theme.text
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: outlineMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (root.outlineActivatedAction)
                            root.outlineActivatedAction(modelData.uri || "", modelData.pageIndex)
                    }
                }
            }
        }
    }

    Component {
        id: searchPanelComponent

        Item {
            anchors.fill: parent

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Rectangle {
                    width: parent.width
                    height: 44
                    radius: Theme.radius
                    color: Theme.surfaceAlt
                    border.color: Theme.border

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 2

                        Text {
                            text: root.searchQuery.trim().length > 0 ? "\"" + root.searchQuery + "\"" : "Busqueda"
                            color: Theme.text
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            text: root.searchResults.length > 0
                                  ? String(root.searchResults.length) + (root.searchResults.length === 1 ? " resultado" : " resultados")
                                  : "Sin coincidencias"
                            color: Theme.secondaryText
                            font.pixelSize: 10
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    visible: root.searchResults.length === 0
                    width: parent.width
                    height: 72
                    radius: Theme.radius
                    color: "transparent"
                    border.color: Theme.border
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 20
                        text: root.searchQuery.trim().length > 0
                              ? "No se encontraron coincidencias en este documento."
                              : "Escribe en el buscador para ver resultados aqui."
                        color: Theme.secondaryText
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                ListView {
                    visible: root.searchResults.length > 0
                    width: parent.width
                    height: parent.height - 52
                    clip: true
                    spacing: 6
                    model: root.searchResults

                    delegate: Rectangle {
                        id: searchResultCard
                        required property int index
                        required property var modelData

                        width: ListView.view.width
                        height: snippetText.implicitHeight + 34
                        radius: Theme.radius
                        color: index === root.activeSearchResultIndex ? Theme.tabActive
                              : searchResultMouse.containsMouse ? Theme.hover
                              : Theme.surface
                        border.color: index === root.activeSearchResultIndex ? Theme.accent : Theme.border
                        border.width: index === root.activeSearchResultIndex ? 2 : 1

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 5

                            Text {
                                text: "Pagina " + String((modelData.pageLabel || 0))
                                color: index === root.activeSearchResultIndex ? Theme.accent : Theme.secondaryText
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }

                            Text {
                                id: snippetText
                                width: parent.width
                                text: modelData.snippet || "Coincidencia"
                                color: Theme.text
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            id: searchResultMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (root.searchResultActivatedAction)
                                    root.searchResultActivatedAction(index)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: pageRowDelegateComponent

        Item {
            id: pageRowDelegate
            required property int index
            required property var modelData

            readonly property bool pageRowDelegate: true
            readonly property int rowIndex: index
            property bool pooledForReuse: false

            width: viewport.width
            height: Math.max(1, rowContent.height)

            ListView.onPooled: pooledForReuse = true
            ListView.onReused: pooledForReuse = false

            Row {
                id: rowContent
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: root.pageSpacing

                Repeater {
                    model: pageRowDelegate.modelData.pages

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
                        readonly property real pageAvailableWidth: paired ? Math.max(1, (availableWidth - rowContent.spacing) / 2) : availableWidth
                        readonly property real widthScale: rotatedWidth > 0 ? (pageAvailableWidth * 0.9) / rotatedWidth : 1.0
                        readonly property real heightScale: rotatedHeight > 0 ? availableHeight / rotatedHeight : 1.0
                        readonly property real pageScale: rotatedWidth > 0 && rotatedHeight > 0
                                                              ? Math.min(pageAvailableWidth / rotatedWidth, availableHeight / rotatedHeight)
                                                              : 1.0
                        readonly property real baseScale: root.baseScaleFor(pageFrame)
                        readonly property var pagePaperItem: pagePaper

                        width: Math.max(1, rotatedWidth * baseScale * root.zoom)
                        height: Math.max(1, rotatedHeight * baseScale * root.zoom)
                        onBaseScaleChanged: if (pageIndex === root.currentPageIndex) root.updateCurrentBaseScale()

                        Item {
                            id: pagePaper
                            anchors.centerIn: parent
                            width: Math.max(1, pageFrame.sourceWidth * pageFrame.baseScale * root.zoom)
                            height: Math.max(1, pageFrame.sourceHeight * pageFrame.baseScale * root.zoom)
                            rotation: pageFrame.pageRotation
                            transformOrigin: Item.Center
                            readonly property real pageScale: pageFrame.pageSize.width > 0
                                                              ? width / pageFrame.pageSize.width
                                                              : 1.0

                            Image {
                                id: pageImage
                                anchors.fill: parent
                                source: pageFrame.pageSource
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                retainWhileLoading: true
                                cache: false
                                smooth: true
                                mipmap: true
                                onImplicitWidthChanged: if (pageFrame.pageIndex === root.currentPageIndex) root.updateCurrentBaseScale()
                                onImplicitHeightChanged: if (pageFrame.pageIndex === root.currentPageIndex) root.updateCurrentBaseScale()
                            }

                            Shape {
                                anchors.fill: parent
                                visible: pageImage.status === Image.Ready && pageFrame.pageIndex === root.selectionPageIndex

                                ShapePath {
                                    strokeWidth: -1
                                    fillColor: Theme.isDark ? "#66E6C35A" : "#88F7D95A"
                                    scale: Qt.size(pagePaper.pageScale, pagePaper.pageScale)

                                    PathMultiline {
                                        paths: root.selectionPaths()
                                    }
                                }
                            }

                            DragHandler {
                                id: textSelectionDrag
                                enabled: !root.handToolEnabled && root.pdfDocument && root.pdfDocument.isLoaded
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.Stylus
                                target: null
                                onActiveChanged: {
                                    if (active) {
                                        root.forceActiveFocus()
                                        if (root.beginSelectionAction)
                                            root.beginSelectionAction(pageFrame.pageIndex, root.selectionPoint(textSelectionDrag.centroid.pressPosition, pagePaper.pageScale))
                                    } else {
                                        if (root.updateSelectionAction)
                                            root.updateSelectionAction(pageFrame.pageIndex, root.selectionPoint(textSelectionDrag.centroid.position, pagePaper.pageScale))
                                        if (root.endSelectionAction)
                                            root.endSelectionAction()
                                    }
                                }
                                onCentroidChanged: {
                                    if (active && root.updateSelectionAction)
                                        root.updateSelectionAction(pageFrame.pageIndex, root.selectionPoint(textSelectionDrag.centroid.position, pagePaper.pageScale))
                                }
                            }

                            TapHandler {
                                id: selectionTapHandler
                                enabled: !root.handToolEnabled
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.Stylus | PointerDevice.TouchScreen
                                onTapped: {
                                    root.forceActiveFocus()
                                    if (root.clearSelectionAction)
                                        root.clearSelectionAction()
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: pagePaper
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

                        Repeater {
                            model: root.linksForPage(pageFrame.pageIndex)

                            Rectangle {
                                required property var modelData
                                readonly property var mappedRect: root.mapPageRect(modelData.rect || {}, pageFrame.pageSize, pagePaper, pageFrame.pageRotation)
                                x: mappedRect.x
                                y: mappedRect.y
                                width: Math.max(8, mappedRect.width)
                                height: Math.max(8, mappedRect.height)
                                color: "transparent"
                                border.color: linkMouse.containsMouse ? Theme.accent : "transparent"
                                border.width: linkMouse.containsMouse ? 1 : 0
                                visible: pageImage.status === Image.Ready

                                MouseArea {
                                    id: linkMouse
                                    anchors.fill: parent
                                    enabled: !root.handToolEnabled
                                    hoverEnabled: true
                                    cursorShape: root.handToolEnabled ? Qt.OpenHandCursor : Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.linkActivatedAction)
                                            root.linkActivatedAction(modelData.uri || "", modelData.pageIndex)
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: root.searchHighlightsForPage(pageFrame.pageIndex)

                            Rectangle {
                                required property var modelData
                                readonly property var mappedRect: root.mapPageRect(modelData, pageFrame.pageSize, pagePaper, pageFrame.pageRotation)
                                x: mappedRect.x
                                y: mappedRect.y
                                width: Math.max(modelData.active ? 12 : 6, mappedRect.width)
                                height: Math.max(modelData.active ? 12 : 6, mappedRect.height)
                                color: modelData.active
                                       ? (Theme.isDark ? "#C7FFD54F" : "#D7FFD54F")
                                       : (Theme.isDark ? "#66E6C35A" : "#88F7D95A")
                                border.color: modelData.active ? "#FFB300" : Theme.accent
                                border.width: modelData.active ? 3 : 1
                                radius: modelData.active ? 4 : 2
                                visible: pageImage.status === Image.Ready
                                opacity: modelData.active ? 1.0 : 0.88

                                SequentialAnimation on opacity {
                                    running: modelData.active && parent.visible
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 0.72; duration: 520; easing.type: Easing.InOutQuad }
                                    NumberAnimation { from: 0.72; to: 1.0; duration: 520; easing.type: Easing.InOutQuad }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ListView {
        id: viewport
        anchors {
            top: parent.top
            bottom: parent.bottom
            left: sidePanel.right
            right: parent.right
        }
        clip: true
        reuseItems: true
        cacheBuffer: Math.max(0, height * 2)
        topMargin: 28
        bottomMargin: 28
        leftMargin: 28
        rightMargin: 28
        spacing: root.isContinuousLayout() ? root.pageSpacing : Math.max(24, root.pageSpacing + 10)
        boundsBehavior: Flickable.StopAtBounds
        model: root.pageRows
        delegate: pageRowDelegateComponent
        onContentYChanged: {
            root.updateCurrentPage()
            root.ensureViewportPages()
        }
        onMovementEnded: {
            root.completeProgrammaticJump()
            root.updateCurrentPage()
            if (root.snapToPage && root.isContinuousLayout())
                root.jumpToPage(root.currentPageIndex)
            else
                root.ensureViewportPages()
        }
        onWidthChanged: Qt.callLater(root.updateCurrentBaseScale)
        onHeightChanged: Qt.callLater(root.updateCurrentBaseScale)
        Component.onCompleted: {
            root.relayoutToCurrentPage()
            root.ensureViewportPages()
        }

        MouseArea {
            id: panToolArea
            anchors.fill: parent
            z: root.handToolEnabled ? 100 : 0
            enabled: root.handToolEnabled
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            propagateComposedEvents: false

            property real pressX: 0
            property real pressY: 0
            property real startContentX: 0
            property real startContentY: 0

            onPressed: function(mouse) {
                pressX = mouse.x
                pressY = mouse.y
                startContentX = viewport.contentX
                startContentY = viewport.contentY
                mouse.accepted = true
            }

            onPositionChanged: function(mouse) {
                if (!pressed)
                    return

                var nextX = startContentX - (mouse.x - pressX)
                var nextY = startContentY - (mouse.y - pressY)
                viewport.contentX = Math.max(0, Math.min(nextX, Math.max(0, viewport.contentWidth - viewport.width)))
                viewport.contentY = Math.max(0, Math.min(nextY, Math.max(0, viewport.contentHeight - viewport.height)))
                mouse.accepted = true
            }
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

        var pending = {}
        for (var pageIndex = 0; pageIndex < sources.length; ++pageIndex) {
            if (!sources[pageIndex] || sources[pageIndex].length === 0)
                continue
            pending[String(pageIndex)] = false
        }
        pendingPageRequests = pending
    }

    function syncThumbnailCache() {
        var sources = []
        if (thumbnailSources && thumbnailSources.length !== undefined) {
            for (var i = 0; i < thumbnailSources.length; ++i)
                sources.push(thumbnailSources[i] || "")
        }
        cachedThumbnailSources = sources

        var pending = {}
        for (var thumbIndex = 0; thumbIndex < sources.length; ++thumbIndex) {
            if (!sources[thumbIndex] || sources[thumbIndex].length === 0)
                continue
            pending[String(thumbIndex)] = false
        }
        pendingThumbnailRequests = pending
    }

    function resetThumbnailCache() {
        Qt.callLater(function() {
            for (var i = 0; i < Math.min(visiblePageSources.length, 4); ++i)
                ensureThumbnail(i)
        })
    }

    function syncThumbnailViewport() {
        Qt.callLater(function() {
            var list = thumbnailListView
            if (!list || !list.visible || visiblePageSources.length <= 0)
                return

            var target = Math.max(0, Math.min(currentPageIndex, visiblePageSources.length - 1))
            if (list.count <= target) {
                thumbnailSyncRetryTimer.restart()
                return
            }

            list.currentIndex = target
            list.positionViewAtIndex(target, thumbnailPositionMode(target, list))
            list.returnToBounds()
            Qt.callLater(function() {
                list = thumbnailListView
                if (!list || list.count <= target)
                    return

                list.currentIndex = target
                list.positionViewAtIndex(target, thumbnailPositionMode(target, list))
                list.returnToBounds()
            })
        })
    }

    function thumbnailPositionMode(index, list) {
        var targetList = list || thumbnailListView
        if (!targetList)
            return ListView.Center

        var target = Math.max(0, Math.min(Number(index) || 0, Math.max(0, targetList.count - 1)))
        if (target <= 1)
            return ListView.Beginning
        if (target >= Math.max(0, targetList.count - 2))
            return ListView.End
        return ListView.Center
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

    function linksForPage(index) {
        if (pageLinks && index >= 0 && index < pageLinks.length)
            return pageLinks[index] || []
        return []
    }

    function searchHighlightsForPage(index) {
        var highlights = []
        if (!searchResults || searchResults.length === undefined)
            return highlights

        for (var i = 0; i < searchResults.length; ++i) {
            var item = searchResults[i] || {}
            if (Number(item.pageIndex) !== index)
                continue

            var rect = item.rect || item
            rect.active = i === activeSearchResultIndex
            highlights.push(rect)
        }

        return highlights
    }

    function mapPageRect(rect, pageSize, imageItem, rotation) {
        var rectX = Number(rect.x || 0)
        var rectY = Number(rect.y || 0)
        var rectWidth = Number(rect.width || 0)
        var rectHeight = Number(rect.height || 0)
        var pageWidth = Math.max(1, Number(pageSize.width || 1))
        var pageHeight = Math.max(1, Number(pageSize.height || 1))
        var imageWidth = Math.max(1, Number(imageItem.width || 1))
        var imageHeight = Math.max(1, Number(imageItem.height || 1))
        var normalizedRotation = ((Number(rotation) % 360) + 360) % 360

        if (normalizedRotation === 90) {
            return {
                x: imageItem.x + imageWidth - ((rectY + rectHeight) / pageHeight) * imageWidth,
                y: imageItem.y + (rectX / pageWidth) * imageHeight,
                width: (rectHeight / pageHeight) * imageWidth,
                height: (rectWidth / pageWidth) * imageHeight
            }
        }

        if (normalizedRotation === 180) {
            return {
                x: imageItem.x + imageWidth - ((rectX + rectWidth) / pageWidth) * imageWidth,
                y: imageItem.y + imageHeight - ((rectY + rectHeight) / pageHeight) * imageHeight,
                width: (rectWidth / pageWidth) * imageWidth,
                height: (rectHeight / pageHeight) * imageHeight
            }
        }

        if (normalizedRotation === 270) {
            return {
                x: imageItem.x + (rectY / pageHeight) * imageWidth,
                y: imageItem.y + imageHeight - ((rectX + rectWidth) / pageWidth) * imageHeight,
                width: (rectHeight / pageHeight) * imageWidth,
                height: (rectWidth / pageWidth) * imageHeight
            }
        }

        return {
            x: imageItem.x + (rectX / pageWidth) * imageWidth,
            y: imageItem.y + (rectY / pageHeight) * imageHeight,
            width: (rectWidth / pageWidth) * imageWidth,
            height: (rectHeight / pageHeight) * imageHeight
        }
    }

    function selectionPoint(point, scale) {
        var safeScale = Math.max(0.01, Number(scale) || 0.01)
        return Qt.point((Number(point.x) || 0) / safeScale, (Number(point.y) || 0) / safeScale)
    }

    function shouldHandleCopyShortcut(event) {
        if (!event || !root.activeFocus || String(root.selectedText || "").trim().length === 0)
            return false

        if (event.matches(StandardKey.Copy))
            return true

        var modifiers = Number(event.modifiers || 0)
        return event.key === Qt.Key_C
               && (modifiers & Qt.ControlModifier)
               && !(modifiers & Qt.AltModifier)
               && !(modifiers & Qt.MetaModifier)
               && !(modifiers & Qt.ShiftModifier)
    }

    function selectionPaths() {
        var parsed = []
        try {
            parsed = JSON.parse(selectionGeometryJson || "[]")
        } catch(e) {
            parsed = []
        }

        var paths = []
        for (var pathIndex = 0; pathIndex < parsed.length; ++pathIndex) {
            var sourcePath = parsed[pathIndex]
            if (!sourcePath || sourcePath.length === undefined)
                continue

            var targetPath = []
            for (var pointIndex = 0; pointIndex < sourcePath.length; ++pointIndex) {
                var sourcePoint = sourcePath[pointIndex]
                if (!sourcePoint || sourcePoint.length === undefined || sourcePoint.length < 2)
                    continue

                targetPath.push(Qt.point(Number(sourcePoint[0]) || 0, Number(sourcePoint[1]) || 0))
            }

            if (targetPath.length > 0)
                paths.push(targetPath)
        }

        return paths
    }

    function thumbnailSourceForPage(index) {
        if (cachedThumbnailSources && index >= 0 && index < cachedThumbnailSources.length)
            return cachedThumbnailSources[index] || sourceForPage(index)
        return sourceForPage(index)
    }

    function ensurePage(index) {
        if (!requestPageRenderAction || index < 0 || index >= visiblePageSources.length)
            return
        if (visiblePageSources[index] && visiblePageSources[index].length > 0)
            return
        var key = String(index)
        if (pendingPageRequests[key])
            return
        pendingPageRequests[key] = true
        requestPageRenderAction(index, initialPageRenderScale(index))
    }

    function ensureThumbnail(index) {
        if (!requestThumbnailRenderAction || index < 0 || index >= visiblePageSources.length)
            return
        if (cachedThumbnailSources && index < cachedThumbnailSources.length && cachedThumbnailSources[index] && cachedThumbnailSources[index].length > 0)
            return
        var key = String(index)
        if (pendingThumbnailRequests[key])
            return
        pendingThumbnailRequests[key] = true
        requestThumbnailRenderAction(index)
    }

    function ensureViewportPages() {
        if (pageTransitionActive) {
            var transitionTarget = pageTransitionTargetPage >= 0 ? pageTransitionTargetPage : currentPageIndex
            if (largeJumpMode && transitionTarget === largeJumpTargetPage) {
                if (requestPageRenderAction && !sourceForPage(transitionTarget))
                    requestPageRenderAction(transitionTarget, largeJumpPreviewScale)
            } else {
                ensurePage(transitionTarget)
            }
            return
        }

        if (largeJumpMode && currentPageIndex === largeJumpTargetPage) {
            if (requestPageRenderAction && !sourceForPage(currentPageIndex))
                requestPageRenderAction(currentPageIndex, largeJumpPreviewScale)
            return
        }

        if (!sourceForPage(currentPageIndex)) {
            ensurePage(currentPageIndex)
            return
        }

        var top = viewport.contentY - viewport.height * 0.15
        var bottom = viewport.contentY + viewport.height * 1.15

        forEachPageItem(function(item) {
            var itemTop = pageTopInViewport(item)
            var itemBottom = itemTop + item.height
            if (itemBottom >= top && itemTop <= bottom)
                ensurePage(item.pageIndex)
        })
    }

    function prefetchAround(index, radius) {
        if (visiblePageSources.length <= 0)
            return

        var target = Math.max(0, Math.min(index, visiblePageSources.length - 1))
        var safeRadius = Math.max(0, Number(radius) || 0)
        ensurePage(target)

        for (var offset = 1; offset <= safeRadius; ++offset) {
            if (target + offset < visiblePageSources.length)
                ensurePage(target + offset)
            if (target - offset >= 0)
                ensurePage(target - offset)
        }
    }

    function effectivePrefetchRadius() {
        return progressiveRenderingEnabled ? Math.min(1, prefetchRadius) : prefetchRadius
    }

    function initialPageRenderScale(index) {
        if (!progressiveRenderingEnabled)
            return renderScale

        if (index === currentPageIndex || index === pageTransitionTargetPage)
            return Math.max(0.5, Math.min(renderScale, progressivePreviewScale))

        return Math.max(0.5, Math.min(renderScale, progressivePreviewScale))
    }

    function requestProgressiveHighQualityRender(pageIndex, renderedScale) {
        if (!progressiveRenderingEnabled || !requestPageRenderAction)
            return

        var scale = Number(renderedScale)
        if (!isFinite(scale) || scale + 0.01 >= renderScale)
            return

        if (pageIndex !== currentPageIndex && pageIndex !== pageTransitionTargetPage)
            return

        var key = String(pageIndex)
        if (progressiveHighQualityRequests[key])
            return

        progressiveHighQualityRequests[key] = true
        requestPageRenderAction(pageIndex, renderScale)
    }

    function beginLargeJump(targetPage, previewScale) {
        largeJumpMode = true
        largeJumpTargetPage = Math.max(0, Number(targetPage) || 0)
        largeJumpPreviewScale = Math.max(0.75, Number(previewScale) || 1.0)
        largeJumpHighQualityRequested = false
        pendingJumpPage = largeJumpTargetPage
        beginPageTransition(largeJumpTargetPage, true)
    }

    function completeLargeJumpRender(pageIndex, renderedScale) {
        if (!largeJumpMode || pageIndex !== largeJumpTargetPage)
            return

        var scale = Number(renderedScale)
        if (!isFinite(scale) || scale <= 0)
            return

        if (scale + 0.01 < renderScale) {
            if (!largeJumpHighQualityRequested && requestPageRenderAction) {
                largeJumpHighQualityRequested = true
                requestPageRenderAction(pageIndex, renderScale)
            }
            return
        }

        largeJumpMode = false
        largeJumpTargetPage = -1
        largeJumpHighQualityRequested = false
        pageTransitionHasPreview = true
        pageTransitionCompleteTimer.restart()
    }

    function beginPageTransition(targetPage, forceOverlay) {
        var lastPage = Math.max(0, visiblePageSources.length - 1)
        var target = Math.max(0, Math.min(Number(targetPage) || 0, lastPage))
        var shouldForceOverlay = !!forceOverlay
        var alreadyVisible = !!sourceForPage(target)

        pageTransitionCompleteTimer.stop()
        prefetchTimer.stop()
        pageTransitionTargetPage = target
        pageTransitionHasPreview = alreadyVisible
        pageTransitionActive = shouldForceOverlay || !alreadyVisible

        if (!pageTransitionActive)
            pageTransitionTargetPage = -1
    }

    function finishPageTransition() {
        pageTransitionActive = false
        pageTransitionTargetPage = -1
        pageTransitionHasPreview = false

        if (!largeJumpMode)
            prefetchTimer.restart()
    }

    function notePageRenderCompleted(pageIndex, renderedScale) {
        if (pageIndex === currentPageIndex || pageIndex === pageTransitionTargetPage)
            pageTransitionHasPreview = true

        completeLargeJumpRender(pageIndex, renderedScale)

        var scale = Number(renderedScale)
        if (isFinite(scale) && scale + 0.01 >= renderScale) {
            var key = String(pageIndex)
            if (progressiveHighQualityRequests[key])
                progressiveHighQualityRequests[key] = false
        }

        requestProgressiveHighQualityRender(pageIndex, renderedScale)

        if (!pageTransitionActive || largeJumpMode)
            return

        if (pageIndex !== currentPageIndex && pageIndex !== pageTransitionTargetPage)
            return

        if (isFinite(scale) && (scale + 0.01 >= renderScale || progressiveRenderingEnabled))
            pageTransitionCompleteTimer.restart()
    }

    function buildPageRows() {
        var totalPages = Math.max(0, Number(pageCount) || 0)
        if (totalPages <= 0 && previewSource.length > 0)
            totalPages = 1

        var rows = []

        if (layoutMode === "single") {
            var singlePage = Math.max(0, Math.min(currentPageIndex, totalPages - 1))
            if (totalPages > 0)
                rows.push({ pages: [{ pageIndex: singlePage }] })
            return rows
        }

        if (layoutMode === "twoPage") {
            if (totalPages === 0)
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
            if (rightPage >= 0 && rightPage < totalPages)
                spread.push({ pageIndex: rightPage })
            if (leftPage >= 0 && leftPage < totalPages)
                spread.push({ pageIndex: leftPage })
            rows.push({ pages: spread })
            return rows
        }

        if (!isTwoPageLayout()) {
            for (var i = 0; i < totalPages; ++i)
                rows.push({ pages: [{ pageIndex: i }] })
            return rows
        }

        for (var page = 0; page < totalPages; page += 2) {
            var pair = []
            pair.push({ pageIndex: page })
            if (page + 1 < totalPages)
                pair.push({ pageIndex: page + 1 })
            rows.push({ pages: pair })
        }

        return rows
    }

    function rowIndexForPage(pageIndex) {
        var target = Math.max(0, Math.min(Number(pageIndex) || 0, Math.max(0, visiblePageSources.length - 1)))
        if (layoutMode === "single" || layoutMode === "twoPage")
            return 0
        if (!isTwoPageLayout())
            return target
        return Math.floor(target / 2)
    }

    function rowDelegateForRowIndex(rowIndex) {
        var targetRow = Number(rowIndex)
        if (!isFinite(targetRow) || !viewport || !viewport.contentItem)
            return null

        var children = viewport.contentItem.children || []
        for (var i = 0; i < children.length; ++i) {
            var child = children[i]
            if (child && child.pageRowDelegate && !child.pooledForReuse && Number(child.rowIndex) === targetRow)
                return child
        }

        return null
    }

    function pageTopInViewport(item) {
        if (!item)
            return 0
        return viewport.topMargin + item.parent.parent.y + item.parent.y + item.y
    }

    function forEachPageItem(callback) {
        if (!viewport || !viewport.contentItem)
            return

        var children = viewport.contentItem.children || []
        for (var i = 0; i < children.length; ++i) {
            var rowDelegate = children[i]
            if (!rowDelegate || !rowDelegate.pageRowDelegate || rowDelegate.pooledForReuse)
                continue

            var rowChildren = rowDelegate.children || []
            for (var rowChildIndex = 0; rowChildIndex < rowChildren.length; ++rowChildIndex) {
                var rowChild = rowChildren[rowChildIndex]
                var pageItems = rowChild.children || []
                for (var pageIndex = 0; pageIndex < pageItems.length; ++pageIndex) {
                    var pageItem = pageItems[pageIndex]
                    if (pageItem && pageItem.pageItem)
                        callback(pageItem)
                }
            }
        }
    }

    function navigateToPage(index) {
        var target = Math.max(0, Math.min(index, visiblePageSources.length - 1))
        if (!isContinuousLayout()) {
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
        pendingJumpPage = target
        programmaticJumpActive = true
        programmaticJumpTimer.restart()
        Qt.callLater(function() {
            var targetRow = rowIndexForPage(target)
            viewport.positionViewAtIndex(targetRow, ListView.Beginning)
            var found = !!rowDelegateForRowIndex(targetRow)

            if (!found) {
                ensurePage(target)
                updateCurrentBaseScale()
                ensureViewportPages()
                return
            }

            ensurePage(target)
            updateCurrentBaseScale()
            ensureViewportPages()
        })
    }

    function closestVisiblePageIndex() {
        var centerY = viewport.contentY + viewport.height / 2
        var closest = -1
        var bestDistance = Number.MAX_VALUE

        forEachPageItem(function(item) {
            if (item.height <= 0 || item.pageIndex === undefined)
                return

            var pageCenter = pageTopInViewport(item) + item.height / 2
            var distance = Math.abs(pageCenter - centerY)
            if (distance < bestDistance) {
                bestDistance = distance
                closest = item.pageIndex
            }
        })

        return closest
    }

    function completeProgrammaticJump() {
        if (!programmaticJumpActive)
            return

        var closest = closestVisiblePageIndex()
        if (closest < 0)
            return

        if (pendingJumpPage >= 0 && closest !== pendingJumpPage) {
            programmaticJumpTimer.restart()
            return
        }

        pendingJumpPage = -1
        programmaticJumpActive = false
        syncThumbnailViewport()
    }

    function focusSearchResult(result) {
        if (!result || result.pageIndex === undefined)
            return

        var targetPage = Math.max(0, Math.min(Number(result.pageIndex), visiblePageSources.length - 1))
        var targetRect = result.rect || {}

        Qt.callLater(function() {
            var found = false

            forEachPageItem(function(item) {
                if (found || item.pageIndex !== targetPage)
                    return

                found = true
                var paper = item.pagePaperItem
                if (!paper) {
                    jumpToPage(targetPage)
                    return
                }

                var mappedRect = mapPageRect(targetRect, item.pageSize, paper, item.pageRotation)
                var absoluteX = item.parent.x + item.x + mappedRect.x + mappedRect.width / 2
                var absoluteY = pageTopInViewport(item) + mappedRect.y + mappedRect.height / 2

                var maxX = Math.max(0, viewport.contentWidth - viewport.width)
                var maxY = Math.max(0, viewport.contentHeight - viewport.height)

                viewport.contentX = Math.max(0, Math.min(absoluteX - viewport.width / 2, maxX))
                viewport.contentY = Math.max(0, Math.min(absoluteY - viewport.height / 2, maxY))
                updateCurrentPage()
                ensureViewportPages()
            })

            if (!found) {
                jumpToPage(targetPage)
                Qt.callLater(function() {
                    focusSearchResult(result)
                })
            }
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
        if (!isContinuousLayout()) {
            updateCurrentBaseScale()
            return
        }

        if (pageTransitionActive) {
            updateCurrentBaseScale()
            return
        }

        var closest = closestVisiblePageIndex()
        if (closest < 0) {
            updateCurrentBaseScale()
            return
        }

        if (programmaticJumpActive && closest !== pendingJumpPage) {
            updateCurrentBaseScale()
            return
        }

        if (pendingJumpPage >= 0 && closest !== pendingJumpPage) {
            updateCurrentBaseScale()
            return
        }

        if (programmaticJumpActive && closest === pendingJumpPage) {
            updateCurrentBaseScale()
            return
        }

        if (pendingJumpPage >= 0 && closest === pendingJumpPage)
            pendingJumpPage = -1

        if (closest !== currentPageIndex && currentPageChangedAction)
        {
            pageChangeFromViewport = true
            currentPageChangedAction(closest)
        }

        updateCurrentBaseScale()
    }
}
