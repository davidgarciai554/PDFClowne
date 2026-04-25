pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Pdf
import QtQuick.Shapes
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
    property var outlineEntries: []
    property var pageLinks: []
    property string searchQuery: ""
    property var searchResults: []
    property int activeSearchResultIndex: -1
    property var cachedPageSources: []
    property var cachedThumbnailSources: []
    readonly property var visiblePageSources: normalizedPageSources()
    readonly property var pageSizes: normalizedPageSizes()
    readonly property var pageRows: buildPageRows()
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
    property real renderScale: 4.0
    property real currentBaseScale: 1.0
    readonly property real currentZoomPercent: currentBaseScale * renderScale * zoom * 100
    property var zoomInAction: null
    property var zoomOutAction: null
    property var renderPageAction: null
    property var renderThumbnailAction: null
    property var currentPageChangedAction: null
    property var sidePanelModeChangedAction: null
    property var outlineActivatedAction: null
    property var linkActivatedAction: null
    property var searchResultActivatedAction: null
    property url selectionDocumentSource: ""
    readonly property bool searchPanelAvailable: searchQuery.trim().length > 0 || searchResults.length > 0 || sidePanelMode === "search"

    onCurrentPageIndexChanged: {
        selectedText = ""
        navigateToPage(currentPageIndex)
    }
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

    PdfDocument {
        id: selectionDocument
        source: root.selectionDocumentSource
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
                width: parent.width
                height: parent.height - 38
                sourceComponent: root.sidePanelMode === "outline"
                               ? outlinePanelComponent
                               : root.sidePanelMode === "search"
                                 ? searchPanelComponent
                                 : thumbnailPanelComponent
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
        onMovementEnded: {
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

        Column {
            id: pagesColumn
            x: Math.max(28, (viewport.width - width) / 2)
            y: 28
            width: Math.max(1, childrenRect.width)
            height: Math.max(1, childrenRect.height)
            spacing: root.isContinuousLayout() ? root.pageSpacing : Math.max(24, root.pageSpacing + 10)

            Repeater {
                model: root.pageRows

                Row {
                    id: pageRow
                    required property var modelData

                    spacing: root.pageSpacing

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
                                    cache: false
                                    smooth: true
                                    mipmap: true
                                    onImplicitWidthChanged: if (pageFrame.pageIndex === root.currentPageIndex) root.updateCurrentBaseScale()
                                    onImplicitHeightChanged: if (pageFrame.pageIndex === root.currentPageIndex) root.updateCurrentBaseScale()
                                }

                                Shape {
                                    anchors.fill: parent
                                    visible: pageImage.status === Image.Ready

                                    ShapePath {
                                        strokeWidth: -1
                                        fillColor: Theme.isDark ? "#66E6C35A" : "#88F7D95A"
                                        scale: Qt.size(pagePaper.pageScale, pagePaper.pageScale)

                                        PathMultiline {
                                            paths: selection.geometry
                                        }
                                    }
                                }

                                DragHandler {
                                    id: textSelectionDrag
                                    enabled: !root.handToolEnabled && selectionDocument.status === PdfDocument.Ready
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.Stylus
                                    target: null
                                }

                                TapHandler {
                                    id: selectionTapHandler
                                    enabled: !root.handToolEnabled
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.Stylus | PointerDevice.TouchScreen
                                    onTapped: {
                                        selection.clear()
                                        selection.forceActiveFocus()
                                        root.selectedText = ""
                                    }
                                }

                                PdfSelection {
                                    id: selection
                                    anchors.fill: parent
                                    document: selectionDocument
                                    page: pageFrame.pageIndex
                                    renderScale: pagePaper.pageScale
                                    from: textSelectionDrag.centroid.pressPosition
                                    to: textSelectionDrag.centroid.position
                                    hold: !textSelectionDrag.active && !selectionTapHandler.pressed
                                    focus: true
                                    onTextChanged: {
                                        if (text.length > 0 || pageFrame.pageIndex === root.currentPageIndex)
                                            root.selectedText = text
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
                var absoluteX = pagesColumn.x + item.parent.x + item.x + mappedRect.x + mappedRect.width / 2
                var absoluteY = pagesColumn.y + item.parent.y + item.y + mappedRect.y + mappedRect.height / 2

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
