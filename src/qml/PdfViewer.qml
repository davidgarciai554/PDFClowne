pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
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
    property bool editModeEnabled: false
    property var editingController: null
    property string editTool: "text"
    property var editAnnotations: []
    property string editFontFamily: "Arial"
    property int editFontSize: 12
    property string editTextColor: "#1C1C2E"
    property bool editBold: false
    property bool editItalic: false
    property bool editUnderline: false
    property string editHighlightColor: "#FFE45A"
    property bool syncingPdfTextStyle: false
    property var activeTextDraft: null
    property var pageTextBlockCache: ({})
    property var beginSelectionAction: null
    property var updateSelectionAction: null
    property var endSelectionAction: null
    property var clearSelectionAction: null
    property var copySelectionAction: null
    property var textEditSeedAction: null
    property var textElementsForPageAction: null
    property var textBlocksForPageAction: null
    property var commitTextEditAction: null
    property var commitHighlightAction: null
    property var eraseAnnotationAction: null
    property var movePageAction: null
    property var deletePageAction: null
    property var rotatePageAction: null
    readonly property bool searchPanelAvailable: searchQuery.trim().length > 0 || searchResults.length > 0 || sidePanelMode === "search"
    readonly property bool inlineTextEditingActive: !!activeTextDraft

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
        clearTextBlockCache()
        if (pageTransitionActive && pageTransitionTargetPage >= 0 && sourceForPage(pageTransitionTargetPage))
            pageTransitionHasPreview = true
        Qt.callLater(ensureViewportPages)
    }
    onThumbnailSourcesChanged: {
        syncThumbnailCache()
        resetThumbnailCache()
    }
    onPageCountChanged: {
        resetPageCache()
        clearTextBlockCache()
    }
    onProgressiveRenderingEnabledChanged: {
        progressiveHighQualityRequests = {}
        prefetchTimer.restart()
    }
    onEditModeEnabledChanged: {
        if (!editModeEnabled)
            activeTextDraft = null
        clearTextBlockCache()
    }
    onEditToolChanged: {
        if (editTool !== "text")
            activeTextDraft = null
        clearTextBlockCache()
    }
    onEditFontFamilyChanged: {
        if (activeTextDraft && !syncingPdfTextStyle)
            updateActiveTextDraftStyle({ fontFamily: editFontFamily })
    }
    onEditFontSizeChanged: {
        if (activeTextDraft && !syncingPdfTextStyle)
            updateActiveTextDraftStyle({ fontSize: editFontSize })
    }
    onEditTextColorChanged: {
        if (activeTextDraft && !syncingPdfTextStyle)
            updateActiveTextDraftStyle({ color: editTextColor })
    }
    onEditBoldChanged: {
        if (activeTextDraft && !syncingPdfTextStyle)
            updateActiveTextDraftStyle({ bold: editBold })
    }
    onEditItalicChanged: {
        if (activeTextDraft && !syncingPdfTextStyle)
            updateActiveTextDraftStyle({ italic: editItalic })
    }
    onEditUnderlineChanged: {
        if (activeTextDraft && !syncingPdfTextStyle)
            updateActiveTextDraftStyle({ underline: editUnderline })
    }
    onActiveTextDraftChanged: {
        if (activeTextDraft)
            Qt.callLater(function() {
                draftTextArea.cursorPosition = Math.max(0, Math.min(String(activeTextDraft.text || "").length, Number(activeTextDraft.cursorPosition || 0)))
                draftTextArea.forceActiveFocus()
            })
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
                readonly property real slotExtent: height + thumbnailList.spacing

                width: thumbnailList.width
                height: 150
                z: thumbnailDragMouse.drag.active ? 10 : 0
                scale: thumbnailDragMouse.drag.active ? 1.01 : 1.0
                radius: Theme.radius
                color: root.currentPageIndex === index ? Theme.tabActive
                                                       : thumbnailMouse.containsMouse ? Theme.hover : "transparent"
                border.color: root.currentPageIndex === index ? Theme.accent : Theme.border
                border.width: root.currentPageIndex === index ? 2 : 1

                Rectangle {
                    id: thumbnailCard
                    x: 0
                    y: 0
                    width: parent.width
                    height: parent.height
                    color: "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Rectangle {
                            id: thumbnailDragHandle
                            width: 28
                            height: 54
                            y: Math.round((parent.height - height) / 2)
                            radius: Theme.radius
                            color: thumbnailDragMouse.drag.active ? Theme.tabActive
                                  : thumbnailDragHover.hovered ? Theme.hover
                                  : Theme.surfaceAlt
                            border.color: thumbnailDragMouse.drag.active ? Theme.accent : Theme.border
                            border.width: thumbnailDragMouse.drag.active ? 2 : 1

                            Grid {
                                anchors.centerIn: parent
                                columns: 2
                                rowSpacing: 4
                                columnSpacing: 4

                                Repeater {
                                    model: 6

                                    Rectangle {
                                        width: 4
                                        height: 4
                                        radius: 2
                                        color: Theme.secondaryText
                                    }
                                }
                            }

                            HoverHandler {
                                id: thumbnailDragHover
                            }

                            MouseArea {
                                id: thumbnailDragMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                drag.target: thumbnailCard
                                drag.axis: Drag.YAxis
                                drag.minimumY: -thumbnailFrame.y
                                drag.maximumY: Math.max(-thumbnailFrame.y,
                                                         thumbnailList.contentHeight - thumbnailFrame.y - thumbnailFrame.height)
                                onReleased: {
                                    var centerPoint = thumbnailCard.mapToItem(thumbnailList.contentItem,
                                                                              thumbnailCard.width / 2,
                                                                              thumbnailCard.height / 2)
                                    var targetIndex = Math.floor(centerPoint.y / thumbnailFrame.slotExtent)
                                    targetIndex = Math.max(0, Math.min(root.pageCount - 1, targetIndex))
                                    if (targetIndex > thumbnailFrame.index)
                                        targetIndex -= 1
                                    thumbnailCard.y = 0
                                    if (root.movePageAction && targetIndex !== thumbnailFrame.index)
                                        root.movePageAction(thumbnailFrame.index, targetIndex)
                                }
                            }
                        }

                        Item {
                            id: thumbnailContent
                            width: parent.width - thumbnailDragHandle.width - 10
                            height: parent.height

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
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    if (root.currentPageChangedAction)
                                        root.currentPageChangedAction(thumbnailFrame.index)
                                    else
                                        root.navigateToPage(thumbnailFrame.index)
                                }
                            }
                        }
                    }
                }

                Button {
                    id: thumbnailMenuButton
                    anchors {
                        top: parent.top
                        right: parent.right
                        topMargin: 8
                        rightMargin: 8
                    }
                    width: 28
                    height: 28
                    visible: thumbnailMouse.containsMouse || thumbnailMenu.visible
                    text: "⋮"
                    onClicked: thumbnailMenu.open()

                    contentItem: Text {
                        text: thumbnailMenuButton.text
                        color: Theme.text
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: Theme.radius
                        color: thumbnailMenuButton.down ? Theme.tabActive
                              : thumbnailMenuButton.hovered ? Theme.hover
                              : Theme.surface
                        border.color: Theme.border
                    }
                }

                Menu {
                    id: thumbnailMenu
                    y: thumbnailMenuButton.height + 6

                    MenuItem {
                        text: "Rotar a la izquierda"
                        onTriggered: {
                            if (root.rotatePageAction)
                                root.rotatePageAction(thumbnailFrame.index, -90)
                        }
                    }

                    MenuItem {
                        text: "Rotar a la derecha"
                        onTriggered: {
                            if (root.rotatePageAction)
                                root.rotatePageAction(thumbnailFrame.index, 90)
                        }
                    }

                    MenuSeparator {}

                    MenuItem {
                        enabled: root.pageCount > 1
                        implicitWidth: 176
                        implicitHeight: 34
                        contentItem: Row {
                            spacing: 10

                            Item { width: 10; height: 1 }

                            Canvas {
                                id: thumbnailTrashIcon
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: root.pageCount > 1 ? 1.0 : 0.45
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.strokeStyle = Theme.danger
                                    ctx.lineWidth = 1.6
                                    ctx.beginPath()
                                    ctx.moveTo(4, 5)
                                    ctx.lineTo(12, 5)
                                    ctx.moveTo(6, 5)
                                    ctx.lineTo(6.5, 13)
                                    ctx.moveTo(10, 5)
                                    ctx.lineTo(9.5, 13)
                                    ctx.moveTo(5, 5)
                                    ctx.lineTo(5.6, 14)
                                    ctx.lineTo(10.4, 14)
                                    ctx.lineTo(11, 5)
                                    ctx.moveTo(6, 3)
                                    ctx.lineTo(10, 3)
                                    ctx.lineTo(10.8, 5)
                                    ctx.moveTo(3, 5)
                                    ctx.lineTo(13, 5)
                                    ctx.stroke()
                                }
                            }

                            Text {
                                text: "Eliminar pagina"
                                color: root.pageCount > 1 ? Theme.danger : Theme.secondaryText
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                        onTriggered: {
                            if (root.deletePageAction)
                                root.deletePageAction(thumbnailFrame.index)
                        }
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

                            Item {
                                id: pdfTextBlockOverlay
                                anchors.fill: parent
                                visible: pageImage.status === Image.Ready
                                         && root.editModeEnabled
                                         && root.editTool === "text"
                                z: 3

                                Repeater {
                                    model: root.pageTextBlocks(pageFrame.pageIndex)

                                    Rectangle {
                                        required property var modelData
                                        readonly property var mappedRect: root.mapPageRect(modelData.rect || {},
                                                                                           pageFrame.pageSize,
                                                                                           pagePaper,
                                                                                           pageFrame.pageRotation)
                                        visible: pdfTextBlockOverlay.visible
                                                 && !root.hasReplacementForBlock(pageFrame.pageIndex, modelData.blockKey)
                                                 && (!root.activeTextDraft || String(root.activeTextDraft.blockKey || "") !== String(modelData.blockKey || ""))
                                        x: mappedRect.x
                                        y: mappedRect.y
                                        width: Math.max(20, mappedRect.width)
                                        height: Math.max(16, mappedRect.height)
                                        color: "transparent"
                                        border.color: root.colorWithOpacity(Theme.accent, 0.58)
                                        border.width: 1

                                        Repeater {
                                            model: root.draftLineMaskRects(modelData,
                                                                           pageFrame.pageSize,
                                                                           pagePaper,
                                                                           pageFrame.pageRotation)

                                            Rectangle {
                                                required property var modelData
                                                readonly property var lineRect: modelData
                                                x: lineRect.x - parent.mappedRect.x
                                                y: lineRect.y - parent.mappedRect.y
                                                width: Math.max(1, lineRect.width)
                                                height: Math.max(1, lineRect.height)
                                                color: "transparent"
                                                border.color: root.colorWithOpacity(Theme.accent, 0.28)
                                                border.width: 1
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: parent.visible
                                            hoverEnabled: true
                                            cursorShape: Qt.IBeamCursor
                                            onClicked: function(mouse) {
                                                mouse.accepted = true
                                                root.forceActiveFocus()
                                                root.activateTextBlock(pageFrame.pageIndex, modelData)
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                id: phase5BlockOverlay
                                anchors.fill: parent
                                visible: pageImage.status === Image.Ready
                                         && root.editModeEnabled
                                         && root.editingController !== null
                                         && root.editingController.ready
                                         && pageFrame.pageIndex === root.currentPageIndex
                                z: 4

                                onVisibleChanged: {
                                    if (visible)
                                        root.editingController.extractBlocksForPage(pageFrame.pageIndex)
                                }

                                Repeater {
                                    model: phase5BlockOverlay.visible
                                           ? root.editingController.currentPageBlocks : null

                                    delegate: Item {
                                        id: blockDelegate
                                        required property string blockId
                                        required property bool isEditable
                                        required property double bboxX
                                        required property double bboxY
                                        required property double bboxWidth
                                        required property double bboxHeight
                                        required property string dominantFontName
                                        required property double dominantFontSize
                                        required property string plainText

                                        readonly property var ps: pageFrame.pageSize
                                        readonly property real scX: ps.width > 0
                                            ? pagePaper.width / ps.width : 1.0
                                        readonly property real scY: ps.height > 0
                                            ? pagePaper.height / ps.height : 1.0

                                        property real reflowedHeightPt: blockDelegate.bboxHeight

                                        x: blockDelegate.bboxX * scX
                                        y: (ps.height - blockDelegate.bboxY - blockDelegate.reflowedHeightPt) * scY
                                        width: Math.max(4, blockDelegate.bboxWidth * scX)
                                        height: Math.max(4, blockDelegate.reflowedHeightPt * scY)

                                        EditableTextBox {
                                            id: editBox
                                            anchors.fill: parent
                                            blockId: blockDelegate.blockId
                                            isEditable: blockDelegate.isEditable
                                            isSelected: root.editingController !== null
                                                        && root.editingController.selectedBlockId === blockDelegate.blockId
                                            plainText: blockDelegate.plainText
                                            fontFamily: blockDelegate.dominantFontName
                                            fontSize: blockDelegate.dominantFontSize
                                            originalHeight: blockDelegate.bboxHeight * blockDelegate.scY

                                            onBlockClicked: function(id) {
                                                if (root.editingController)
                                                    root.editingController.selectBlock(id)
                                            }
                                            onTextEditing: function(id, newText) {
                                                if (root.editingController) {
                                                    root.editingController.updateBlockText(id, newText)
                                                    const newH = root.editingController.reflowText(id, newText)
                                                    if (newH > 0)
                                                        blockDelegate.reflowedHeightPt = newH
                                                    editBox.fallbackFontName =
                                                        root.editingController.fallbackFontFor(id, newText)
                                                }
                                            }
                                            onResized: function(id, dx, dy, dw, dh) {
                                                blockDelegate.x      = Math.max(0, blockDelegate.x + dx)
                                                blockDelegate.y      = Math.max(0, blockDelegate.y + dy)
                                                const minSz = 4
                                                const newW = Math.max(minSz, blockDelegate.width  + dw)
                                                const newH = Math.max(minSz, blockDelegate.height + dh)
                                                blockDelegate.width  = newW
                                                blockDelegate.height = newH
                                                blockDelegate.reflowedHeightPt = newH / blockDelegate.scY
                                            }
                                            onStyleChanged: function(id, prop, value) {
                                                // Forward style changes back to C++ when persistence is ready
                                            }
                                        }
                                    }
                                }
                            }

                            Repeater {
                                model: root.annotationsForPage(pageFrame.pageIndex)

                                Item {
                                    id: annotationDelegateComponent
                                    required property var modelData
                                    anchors.fill: parent
                                    z: 4
                                    visible: pageImage.status === Image.Ready

                                    Repeater {
                                        model: root.annotationHighlightRects(annotationDelegateComponent.modelData,
                                                                           pageFrame.pageSize,
                                                                           pagePaper,
                                                                           pageFrame.pageRotation)

                                        Rectangle {
                                            required property var modelData
                                            x: modelData.x
                                            y: modelData.y
                                            width: Math.max(4, modelData.width)
                                            height: Math.max(4, modelData.height)
                                            color: root.colorWithOpacity(annotationDelegateComponent.modelData.color || root.editHighlightColor,
                                                                        annotationDelegateComponent.modelData.opacity || 0.42)
                                            border.color: root.editModeEnabled && root.editTool === "erase" ? Theme.danger : "transparent"
                                            border.width: root.editModeEnabled && root.editTool === "erase" ? 1 : 0
                                            radius: 2

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: root.editModeEnabled && root.editTool === "erase"
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root.eraseAnnotationAction)
                                                        root.eraseAnnotationAction(annotationDelegateComponent.modelData.id)
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        readonly property bool replacementBlock: annotationDelegateComponent.modelData.type === "replaceTextBlock"
                                        readonly property var mappedRect: root.mapPageRect(annotationDelegateComponent.modelData.rect || {},
                                                                                           pageFrame.pageSize,
                                                                                           pagePaper,
                                                                                           pageFrame.pageRotation)
                                        visible: annotationDelegateComponent.modelData.type === "freeText"
                                                 || annotationDelegateComponent.modelData.type === "replaceTextBlock"

                                        Repeater {
                                            model: parent.replacementBlock
                                                   ? root.draftLineMaskRects(annotationDelegateComponent.modelData,
                                                                            pageFrame.pageSize,
                                                                            pagePaper,
                                                                            pageFrame.pageRotation)
                                                   : []

                                            Rectangle {
                                                required property var modelData
                                                x: modelData.x
                                                y: modelData.y
                                                width: Math.max(1, modelData.width)
                                                height: Math.max(1, modelData.height)
                                                color: "#FFFFFFFF"
                                            }
                                        }

                                        Repeater {
                                            model: parent.replacementBlock
                                                   ? root.visualRunsForDraft(annotationDelegateComponent.modelData,
                                                                             pageFrame.pageSize,
                                                                             pagePaper,
                                                                             pageFrame.pageRotation)
                                                   : []

                                            Text {
                                                required property var modelData
                                                x: modelData.rect.x
                                                y: modelData.rect.y
                                                width: Math.max(1, modelData.rect.width)
                                                height: Math.max(1, modelData.rect.height)
                                                text: modelData.text || ""
                                                color: modelData.color || annotationDelegateComponent.modelData.color || root.editTextColor
                                                font.family: root.displayFontFamily(modelData.fontFaceName
                                                                                   || modelData.fontFamily
                                                                                   || annotationDelegateComponent.modelData.fontFaceName
                                                                                   || annotationDelegateComponent.modelData.fontFamily
                                                                                   || root.editFontFamily)
                                                font.pixelSize: Math.max(6, Number(modelData.fontSize || annotationDelegateComponent.modelData.fontSize || root.editFontSize) * pagePaper.pageScale)
                                                font.bold: !!modelData.bold
                                                font.italic: !!modelData.italic
                                                font.underline: !!modelData.underline
                                                wrapMode: Text.NoWrap
                                                clip: false
                                                verticalAlignment: Text.AlignTop
                                            }
                                        }

                                        Rectangle {
                                            x: parent.mappedRect.x
                                            y: parent.mappedRect.y
                                            width: Math.max(24, parent.mappedRect.width)
                                            height: Math.max(18, parent.mappedRect.height)
                                            color: "transparent"
                                            border.color: root.editModeEnabled && root.editTool === "erase" ? Theme.danger : "transparent"
                                            border.width: root.editModeEnabled && root.editTool === "erase" ? 1 : 0

                                            Text {
                                                visible: !parent.parent.replacementBlock
                                                anchors.fill: parent
                                                anchors.margins: 2
                                                text: annotationDelegateComponent.modelData.text || ""
                                                color: annotationDelegateComponent.modelData.color || root.editTextColor
                                                font.family: root.displayFontFamily(annotationDelegateComponent.modelData.fontFamily || root.editFontFamily)
                                                font.pixelSize: Math.max(6, Number(annotationDelegateComponent.modelData.fontSize || root.editFontSize) * pagePaper.pageScale)
                                                font.bold: !!annotationDelegateComponent.modelData.bold
                                                font.italic: !!annotationDelegateComponent.modelData.italic
                                                font.underline: !!annotationDelegateComponent.modelData.underline
                                                wrapMode: Text.WordWrap
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: root.editModeEnabled
                                                         && (root.editTool === "erase"
                                                             || (root.editTool === "text"
                                                                 && annotationDelegateComponent.modelData.type === "replaceTextBlock"))
                                                cursorShape: root.editTool === "erase" ? Qt.PointingHandCursor : Qt.IBeamCursor
                                                onClicked: {
                                                    if (root.editTool === "text"
                                                            && annotationDelegateComponent.modelData.type === "replaceTextBlock") {
                                                        root.forceActiveFocus()
                                                        root.activateTextBlock(pageFrame.pageIndex, annotationDelegateComponent.modelData)
                                                    } else if (root.eraseAnnotationAction) {
                                                        root.eraseAnnotationAction(annotationDelegateComponent.modelData.id)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                id: inlinePdfTextLayer
                                readonly property bool draftVisible: root.activeTextDraft && root.activeTextDraft.pageIndex === pageFrame.pageIndex
                                readonly property var draftInputRect: draftVisible
                                                                         ? root.mapPageRect(root.activeTextDraft.rect || root.activeTextDraft.originalRect || {},
                                                                                            pageFrame.pageSize,
                                                                                            pagePaper,
                                                                                            pageFrame.pageRotation)
                                                                         : ({ x: 0, y: 0, width: 1, height: 1 })
                                visible: draftVisible
                                z: 8
                                anchors.fill: parent

                                Rectangle {
                                    id: activeTextSelectionFrame
                                    x: inlinePdfTextLayer.draftInputRect.x
                                    y: inlinePdfTextLayer.draftInputRect.y
                                    width: Math.max(24, inlinePdfTextLayer.draftInputRect.width)
                                    height: Math.max(18, inlinePdfTextLayer.draftInputRect.height)
                                    color: "transparent"
                                    border.color: "#FF4D3D"
                                    border.width: 1
                                    z: 20

                                    Repeater {
                                        model: root.selectionHandleRects(inlinePdfTextLayer.draftInputRect)

                                        Rectangle {
                                            required property var modelData
                                            x: modelData.x - activeTextSelectionFrame.x
                                            y: modelData.y - activeTextSelectionFrame.y
                                            width: modelData.width
                                            height: modelData.height
                                            radius: width / 2
                                            color: "#FFFFFFFF"
                                            border.color: "#FF4D3D"
                                            border.width: 1
                                        }
                                    }
                                }

                                Repeater {
                                    model: root.activeTextDraft
                                           ? root.draftLineMaskRects(root.activeTextDraft,
                                                                     pageFrame.pageSize,
                                                                     pagePaper,
                                                                     pageFrame.pageRotation)
                                           : []

                                    Rectangle {
                                        required property var modelData
                                        x: modelData.x
                                        y: modelData.y
                                        width: Math.max(1, modelData.width)
                                        height: Math.max(1, modelData.height)
                                        color: "#FFFFFFFF"
                                    }
                                }

                                Repeater {
                                    model: root.activeTextDraft
                                           ? root.selectionRectsForDraft(root.activeTextDraft,
                                                                         pageFrame.pageSize,
                                                                         pagePaper,
                                                                         pageFrame.pageRotation)
                                           : []

                                    Rectangle {
                                        required property var modelData
                                        x: modelData.x
                                        y: modelData.y
                                        width: Math.max(1, modelData.width)
                                        height: Math.max(1, modelData.height)
                                        color: root.colorWithOpacity(Theme.accent, 0.30)
                                        z: 12
                                    }
                                }

                                Repeater {
                                    model: root.activeTextDraft
                                           ? root.visualRunsForDraft(root.activeTextDraft,
                                                                     pageFrame.pageSize,
                                                                     pagePaper,
                                                                     pageFrame.pageRotation)
                                           : []

                                    Text {
                                        required property var modelData
                                        x: modelData.rect.x
                                        y: modelData.rect.y
                                        width: Math.max(1, modelData.rect.width)
                                        height: Math.max(1, modelData.rect.height)
                                        text: modelData.text || ""
                                        color: modelData.color || root.editTextColor
                                        font.family: root.displayFontFamily(modelData.fontFaceName
                                                                           || modelData.fontFamily
                                                                           || (root.activeTextDraft ? root.activeTextDraft.fontFaceName || root.activeTextDraft.fontFamily : "")
                                                                           || root.editFontFamily)
                                        font.pixelSize: Math.max(6, Number(modelData.fontSize || (root.activeTextDraft ? root.activeTextDraft.fontSize : root.editFontSize) || root.editFontSize) * pagePaper.pageScale)
                                        font.bold: !!modelData.bold
                                        font.italic: !!modelData.italic
                                        font.underline: !!modelData.underline
                                        wrapMode: Text.NoWrap
                                        clip: false
                                        verticalAlignment: Text.AlignTop
                                    }
                                }

                                Rectangle {
                                    id: pdfNativeCaret
                                    readonly property var caretRect: root.caretRectForTextPosition(root.activeTextDraft,
                                                                                                   root.activeTextDraft ? Number(root.activeTextDraft.cursorPosition || 0) : 0,
                                                                                                   pageFrame.pageSize,
                                                                                                   pagePaper,
                                                                                                   pageFrame.pageRotation)
                                    x: caretRect.x
                                    y: caretRect.y
                                    width: Math.max(1, caretRect.width)
                                    height: Math.max(8, caretRect.height)
                                    color: "#FF3B30"
                                    visible: inlinePdfTextLayer.draftVisible
                                    z: 30

                                    SequentialAnimation on opacity {
                                        running: pdfNativeCaret.visible
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 1.0; to: 1.0; duration: 520 }
                                        NumberAnimation { from: 0.15; to: 0.15; duration: 360 }
                                    }
                                }

                                TextEdit {
                                    id: draftTextArea
                                    x: inlinePdfTextLayer.draftInputRect.x
                                    y: inlinePdfTextLayer.draftInputRect.y
                                    width: Math.max(24, inlinePdfTextLayer.draftInputRect.width)
                                    height: Math.max(18, inlinePdfTextLayer.draftInputRect.height)
                                    text: root.activeTextDraft ? root.activeTextDraft.text || "" : ""
                                    textFormat: TextEdit.PlainText
                                    selectByMouse: true
                                    persistentSelection: true
                                    leftPadding: 0
                                    rightPadding: 0
                                    topPadding: 0
                                    bottomPadding: 0
                                    wrapMode: root.activeTextDraft && root.activeTextDraft.layoutMode === "preserve-lines"
                                              ? TextEdit.NoWrap
                                              : TextEdit.WordWrap
                                    color: "transparent"
                                    selectedTextColor: "transparent"
                                    selectionColor: root.colorWithOpacity(Theme.accent, 0.35)
                                    opacity: 0.01
                                    cursorVisible: false
                                    font.family: root.displayFontFamily(root.activeTextDraft ? (root.activeTextDraft.fontFaceName || root.activeTextDraft.fontFamily || root.editFontFamily) : root.editFontFamily)
                                    font.pixelSize: Math.max(6, Number(root.activeTextDraft ? (root.activeTextDraft.fontSize || root.editFontSize) : root.editFontSize) * pagePaper.pageScale)
                                    font.bold: root.activeTextDraft ? !!root.activeTextDraft.bold : root.editBold
                                    font.italic: root.activeTextDraft ? !!root.activeTextDraft.italic : root.editItalic
                                    font.underline: root.activeTextDraft ? !!root.activeTextDraft.underline : root.editUnderline
                                    onTextChanged: root.updateActiveDraftText(text)
                                    onCursorPositionChanged: root.setActiveDraftCursorPosition(cursorPosition)
                                    onSelectionStartChanged: root.syncActiveDraftTextSelection(selectionStart, selectionEnd)
                                    onSelectionEndChanged: root.syncActiveDraftTextSelection(selectionStart, selectionEnd)
                                    onVisibleChanged: if (visible) forceActiveFocus()
                                    Keys.onPressed: function(event) {
                                        if (event.key === Qt.Key_Escape) {
                                            root.activeTextDraft = null
                                            event.accepted = true
                                        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Z) {
                                            if (event.modifiers & Qt.ShiftModifier)
                                                draftTextArea.redo()
                                            else
                                                draftTextArea.undo()
                                            event.accepted = true
                                        } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Y) {
                                            draftTextArea.redo()
                                            event.accepted = true
                                        } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                                   && (event.modifiers & Qt.ControlModifier)) {
                                            root.commitActiveTextDraft()
                                            event.accepted = true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: activeDraftMouseArea
                                    anchors.fill: parent
                                    enabled: inlinePdfTextLayer.draftVisible
                                    hoverEnabled: true
                                    cursorShape: Qt.IBeamCursor
                                    z: 40
                                    acceptedButtons: Qt.LeftButton
                                    onPressed: function(mouse) {
                                        var pagePoint = root.selectionPoint(Qt.point(activeDraftMouseArea.mouseX, activeDraftMouseArea.mouseY),
                                                                            pagePaper.pageScale)
                                        if (!root.pointInsideRect(pagePoint, root.activeTextDraft ? root.activeTextDraft.rect || root.activeTextDraft.originalRect || {} : {})) {
                                            mouse.accepted = false
                                            return
                                        }
                                        root.moveCaretInActiveDraft(pagePoint)
                                        draftTextArea.forceActiveFocus()
                                        mouse.accepted = true
                                    }
                                    onClicked: function(mouse) {
                                        var pagePoint = root.selectionPoint(Qt.point(activeDraftMouseArea.mouseX, activeDraftMouseArea.mouseY),
                                                                            pagePaper.pageScale)
                                        if (!root.pointInsideRect(pagePoint, root.activeTextDraft ? root.activeTextDraft.rect || root.activeTextDraft.originalRect || {} : {})) {
                                            mouse.accepted = false
                                            return
                                        }
                                        root.moveCaretInActiveDraft(pagePoint)
                                        draftTextArea.forceActiveFocus()
                                        mouse.accepted = true
                                    }
                                }
                            }

                            TapHandler {
                                id: textEditTapHandler
                                enabled: root.editModeEnabled && root.editTool === "text"
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.Stylus | PointerDevice.TouchScreen
                                onTapped: {
                                    root.forceActiveFocus()
                                    root.startTextEdit(pageFrame.pageIndex,
                                                       root.selectionPoint(textEditTapHandler.point.position, pagePaper.pageScale))
                                }
                            }

                            DragHandler {
                                id: textSelectionDrag
                                enabled: !root.handToolEnabled
                                         && root.pdfDocument
                                         && root.pdfDocument.isLoaded
                                         && (!root.editModeEnabled || root.editTool === "highlight")
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
                                        if (root.editModeEnabled && root.editTool === "highlight")
                                            Qt.callLater(function() {
                                                if (root.commitHighlightAction)
                                                    root.commitHighlightAction()
                                            })
                                    }
                                }
                                onCentroidChanged: {
                                    if (active && root.updateSelectionAction)
                                        root.updateSelectionAction(pageFrame.pageIndex, root.selectionPoint(textSelectionDrag.centroid.position, pagePaper.pageScale))
                                }
                            }

                            TapHandler {
                                id: selectionTapHandler
                                enabled: !root.handToolEnabled && ((!root.editModeEnabled || root.editTool === "highlight")
                                         || (root.editModeEnabled && root.editTool === "text" && !!root.activeTextDraft))
                                acceptedDevices: PointerDevice.Mouse | PointerDevice.Stylus | PointerDevice.TouchScreen
                                onTapped: {
                                    root.forceActiveFocus()
                                    if (root.editModeEnabled && root.editTool === "text" && root.activeTextDraft) {
                                        root.commitActiveTextDraft()
                                    } else if (root.clearSelectionAction) {
                                        root.clearSelectionAction()
                                    }
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
                                    cursorShape: root.handToolEnabled ? Qt.OpenHandCursor : Qt.ArrowCursor
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
            hoverEnabled: root.handToolEnabled
            cursorShape: root.handToolEnabled ? (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
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

            positionThumbnailListAtIndex(list, target)
            Qt.callLater(function() {
                list = thumbnailListView
                if (!list || list.count <= target)
                    return

                positionThumbnailListAtIndex(list, target)
            })
        })
    }

    function positionThumbnailListAtIndex(thumbnailList, target) {
        var positionMode = thumbnailPositionMode(target, thumbnailList)
        thumbnailList.currentIndex = target
        thumbnailList.positionViewAtIndex(target, positionMode)
        if (positionMode === ListView.Center) {
            var slotExtent = 150 + thumbnailList.spacing
            var centeredY = Math.max(0,
                                     Math.min(target * slotExtent + slotExtent / 2 - thumbnailList.height / 2,
                                              Math.max(0, thumbnailList.contentHeight - thumbnailList.height)))
            thumbnailList.contentY = centeredY
        }
        thumbnailList.returnToBounds()
    }

    function thumbnailPositionMode(index, list) {
        var targetList = list || thumbnailListView
        if (!targetList)
            return ListView.Center

        var target = Math.max(0, Math.min(Number(index) || 0, Math.max(0, targetList.count - 1)))
        var positionMode = ListView.Center
        if (target <= 1)
            positionMode = ListView.Beginning
        else if (target >= Math.max(0, targetList.count - 2))
            positionMode = ListView.End
        return positionMode
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

    function displayFontFamily(fontFamily) {
        var value = String(fontFamily || "").trim()
        if (value.length === 0)
            return String(root.editFontFamily || "Arial")

        if (value.charAt(0) === "/")
            value = value.substring(1)
        var subsetMarker = value.indexOf("+")
        if (subsetMarker > 0 && subsetMarker < value.length - 1)
            value = value.substring(subsetMarker + 1)

        return value
    }

    function colorWithOpacity(colorValue, opacityValue) {
        var colorText = String(colorValue || "#FFE45A")
        var alpha = Math.max(0.05, Math.min(1.0, Number(opacityValue) || 0.42))
        if (colorText.charAt(0) !== "#" || colorText.length < 7)
            return Qt.rgba(1, 0.9, 0.35, alpha)

        var red = parseInt(colorText.substr(1, 2), 16)
        var green = parseInt(colorText.substr(3, 2), 16)
        var blue = parseInt(colorText.substr(5, 2), 16)
        if (!isFinite(red) || !isFinite(green) || !isFinite(blue))
            return Qt.rgba(1, 0.9, 0.35, alpha)

        return Qt.rgba(red / 255, green / 255, blue / 255, alpha)
    }

    function annotationsForPage(pageIndex) {
        var list = []
        if (!editAnnotations || editAnnotations.length === undefined)
            return list

        for (var i = 0; i < editAnnotations.length; ++i) {
            var item = editAnnotations[i] || {}
            if (Number(item.pageIndex) === Number(pageIndex))
                list.push(item)
        }

        return list
    }

    function hasReplacementForBlock(pageIndex, blockKey) {
        if (!blockKey)
            return false

        var annotations = annotationsForPage(pageIndex)
        for (var i = 0; i < annotations.length; ++i) {
            var item = annotations[i] || {}
            if (String(item.type || "") === "replaceTextBlock"
                    && String(item.blockKey || "") === String(blockKey || "")) {
                return true
            }
        }

        return false
    }

    function rectFromQuadPath(path) {
        if (!path || path.length === undefined || path.length < 4)
            return { x: 0, y: 0, width: 1, height: 1 }

        var minX = Number.MAX_VALUE
        var minY = Number.MAX_VALUE
        var maxX = -Number.MAX_VALUE
        var maxY = -Number.MAX_VALUE
        for (var i = 0; i < path.length; ++i) {
            var point = path[i]
            if (!point || point.length === undefined || point.length < 2)
                continue
            var x = Number(point[0]) || 0
            var y = Number(point[1]) || 0
            minX = Math.min(minX, x)
            minY = Math.min(minY, y)
            maxX = Math.max(maxX, x)
            maxY = Math.max(maxY, y)
        }

        if (minX === Number.MAX_VALUE)
            return { x: 0, y: 0, width: 1, height: 1 }

        return { x: minX, y: minY, width: Math.max(1, maxX - minX), height: Math.max(1, maxY - minY) }
    }

    function annotationHighlightRects(annotation, pageSize, paperItem, rotation) {
        var rects = []
        if (!annotation || annotation.type !== "highlight")
            return rects

        var paths = annotation.quads || []
        for (var i = 0; i < paths.length; ++i)
            rects.push(mapPageRect(rectFromQuadPath(paths[i]), pageSize, paperItem, rotation))
        return rects
    }

    function draftLineMaskRects(draft, pageSize, paperItem, rotation) {
        var rects = []
        if (!draft)
            return rects

        var lines = draft.lines || []
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i] || {}
            if (line.bbox)
                rects.push(mapPageRect(line.bbox, pageSize, paperItem, rotation))
        }

        return rects
    }

    function pointInsideRect(point, rect) {
        if (!point || !rect)
            return false
        var x = Number(point.x) || 0
        var y = Number(point.y) || 0
        return x >= Number(rect.x || 0)
                && y >= Number(rect.y || 0)
                && x <= Number(rect.x || 0) + Math.max(0, Number(rect.width || 0))
                && y <= Number(rect.y || 0) + Math.max(0, Number(rect.height || 0))
    }

    function selectionHandleRects(rect) {
        if (!rect)
            return []
        var size = 8
        var half = size / 2
        var left = Number(rect.x || 0)
        var top = Number(rect.y || 0)
        var right = left + Math.max(1, Number(rect.width || 1))
        var bottom = top + Math.max(1, Number(rect.height || 1))
        var midX = (left + right) / 2
        var midY = (top + bottom) / 2
        return [
            { x: left - half, y: top - half, width: size, height: size },
            { x: midX - half, y: top - half, width: size, height: size },
            { x: right - half, y: top - half, width: size, height: size },
            { x: right - half, y: midY - half, width: size, height: size },
            { x: right - half, y: bottom - half, width: size, height: size },
            { x: midX - half, y: bottom - half, width: size, height: size },
            { x: left - half, y: bottom - half, width: size, height: size },
            { x: left - half, y: midY - half, width: size, height: size }
        ]
    }

    function lineTextFromSpans(line) {
        var spans = line && line.spans ? line.spans : []
        var text = ""
        for (var i = 0; i < spans.length; ++i)
            text += String((spans[i] || {}).text || "")
        return text
    }

    function runRectFromSource(run, fallbackLine, pageSize, paperItem, rotation) {
        var rect = (run && run.bbox) ? run.bbox : ((fallbackLine && fallbackLine.bbox) ? fallbackLine.bbox : null)
        if (!rect && run && run.glyphs && run.glyphs.length > 0) {
            var glyphRects = []
            for (var i = 0; i < run.glyphs.length; ++i) {
                var glyph = run.glyphs[i] || {}
                if (glyph.quad)
                    glyphRects.push(rectFromQuadPath(glyph.quad))
            }
            if (glyphRects.length > 0) {
                var minX = Number.MAX_VALUE
                var minY = Number.MAX_VALUE
                var maxX = -Number.MAX_VALUE
                var maxY = -Number.MAX_VALUE
                for (var j = 0; j < glyphRects.length; ++j) {
                    minX = Math.min(minX, glyphRects[j].x)
                    minY = Math.min(minY, glyphRects[j].y)
                    maxX = Math.max(maxX, glyphRects[j].x + glyphRects[j].width)
                    maxY = Math.max(maxY, glyphRects[j].y + glyphRects[j].height)
                }
                rect = { x: minX, y: minY, width: Math.max(1, maxX - minX), height: Math.max(1, maxY - minY) }
            }
        }

        return mapPageRect(rect || { x: 0, y: 0, width: 1, height: 1 }, pageSize, paperItem, rotation)
    }

    function sourceTextLinesForDraft(draft) {
        var result = []
        if (!draft)
            return result

        var lines = draft.lines || []
        var offset = 0
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i] || {}
            var text = line.text !== undefined ? String(line.text || "") : lineTextFromSpans(line)
            var glyphs = []
            var spans = line.spans || []
            for (var spanIndex = 0; spanIndex < spans.length; ++spanIndex) {
                var spanGlyphs = (spans[spanIndex] || {}).glyphs || []
                for (var glyphIndex = 0; glyphIndex < spanGlyphs.length; ++glyphIndex)
                    glyphs.push(spanGlyphs[glyphIndex] || {})
            }

            result.push({
                source: line,
                lineIndex: i,
                text: text,
                start: offset,
                end: offset + text.length,
                glyphs: glyphs
            })
            offset += text.length + 1
        }

        return result
    }

    function estimateTextWidth(text, fontSize, fallbackWidth) {
        var value = String(text || "")
        if (value.length === 0)
            return 1
        var size = Math.max(6, Number(fontSize || root.editFontSize || 12))
        return Math.max(1, Math.min(Math.max(1, Number(fallbackWidth || 1)), value.length * size * 0.56))
    }

    function insertionXFromGlyphAdvances(lineRect, glyphs, sourceStart, cursorInLine, editedLength, fontSize) {
        var left = Number(lineRect.x || 0)
        var width = Math.max(1, Number(lineRect.width || 1))
        var count = Math.max(0, Number(editedLength || 0))
        var cursor = Math.max(0, Math.min(count, Number(cursorInLine || 0)))
        var insertionPoints = [left]
        var currentX = left

        for (var i = 0; i < count; ++i) {
            var glyph = i < glyphs.length ? glyphs[i] || {} : null
            var advance = glyph && Number(glyph.advance) > 0 ? Number(glyph.advance) : 0
            if (advance <= 0 && glyph && glyph.bbox)
                advance = Math.max(1, Number(glyph.bbox.width || 0))
            if (advance <= 0)
                advance = Math.max(1, Number(fontSize || root.editFontSize || 12) * 0.56)
            currentX = Math.min(left + width, currentX + advance)
            insertionPoints.push(currentX)
        }

        while (insertionPoints.length <= cursor)
            insertionPoints.push(Math.min(left + width, insertionPoints[insertionPoints.length - 1] + Math.max(1, Number(fontSize || root.editFontSize || 12) * 0.56)))

        return insertionPoints
    }

    function editableLineLayout(draft, sourceLine, editedLineText) {
        var source = sourceLine || {}
        var line = source.source || {}
        var lineRect = line.bbox || (draft ? draft.rect : null) || { x: 0, y: 0, width: 1, height: 12 }
        var text = String(editedLineText || "")
        var originalLineText = String(source.text || "")
        var spans = line.spans || []
        var firstSpan = spans.length > 0 ? spans[0] || {} : {}
        var fontSize = Number(firstSpan.fontSize || line.fontSize || (draft ? draft.fontSize : root.editFontSize) || root.editFontSize)
        var glyph = source.glyphs && source.glyphs.length > 0 ? source.glyphs[0] || {} : {}
        var glyphAdvanceHint = glyph.advance !== undefined ? Number(glyph.advance || 0) : 0
        if ((!isFinite(fontSize) || fontSize <= 0) && glyphAdvanceHint > 0)
            fontSize = Math.max(6, glyphAdvanceHint * 1.8)
        var insertionPoints = []
        insertionPoints = insertionXFromGlyphAdvances(lineRect,
                                                      source.glyphs || [],
                                                      Number(source.start || 0),
                                                      text.length,
                                                      text.length,
                                                      fontSize)
        var runWidth = text === originalLineText
                ? Math.max(1, Number(lineRect.width || 1))
                : estimateTextWidth(text, fontSize, Number(lineRect.width || 1))

        return {
            line: line,
            lineIndex: Number(source.lineIndex || 0),
            start: Number(source.start || 0),
            end: Number(source.start || 0) + text.length,
            text: text,
            rect: {
                x: Number(lineRect.x || 0),
                y: Number(lineRect.y || 0),
                width: Math.max(1, runWidth),
                height: Math.max(8, Number(lineRect.height || fontSize || 12))
            },
            fullRect: lineRect,
            insertionPoints: insertionPoints,
            geometryFidelity: editedLineText === originalLineText ? "exact" : "estimated",
            runs: [{
                text: text,
                bbox: {
                    x: Number(lineRect.x || 0),
                    y: Number(lineRect.y || 0),
                    width: Math.max(1, runWidth),
                    height: Math.max(8, Number(lineRect.height || fontSize || 12))
                },
                fontFamily: firstSpan.fontFamily || (draft ? draft.fontFamily : "") || "",
                fontFaceName: firstSpan.fontFaceName || (draft ? draft.fontFaceName : "") || "",
                fontResourceName: firstSpan.fontResourceName || (draft ? draft.fontResourceName : "") || "",
                fontSize: fontSize,
                color: firstSpan.color || (draft ? draft.color : root.editTextColor) || root.editTextColor,
                bold: firstSpan.bold !== undefined ? !!firstSpan.bold : !!(draft && draft.bold),
                italic: firstSpan.italic !== undefined ? !!firstSpan.italic : !!(draft && draft.italic),
                underline: firstSpan.underline !== undefined ? !!firstSpan.underline : !!(draft && draft.underline)
            }]
        }
    }

    function editableLayoutForDraft(draft) {
        var layout = { lines: [], geometryFidelity: "fallback" }
        if (!draft)
            return layout

        var sourceLines = sourceTextLinesForDraft(draft)
        var editedLines = String(draft.text || draft.editablePlainText || "").split("\n")
        if (sourceLines.length === 0) {
            var fallbackRect = draft.rect || { x: 0, y: 0, width: 1, height: 12 }
            var fallbackSource = {
                source: { bbox: fallbackRect, text: String(draft.text || "") },
                lineIndex: 0,
                text: String(draft.originalText || draft.text || ""),
                start: 0,
                end: String(draft.text || "").length,
                glyphs: []
            }
            layout.lines.push(editableLineLayout(draft, fallbackSource, String(draft.text || "")))
            layout.geometryFidelity = "fallback"
            return layout
        }

        var exact = true
        for (var i = 0; i < sourceLines.length; ++i) {
            var editedLine = i < editedLines.length ? editedLines[i] : sourceLines[i].text
            var lineLayout = editableLineLayout(draft, sourceLines[i], editedLine)
            if (lineLayout.geometryFidelity !== "exact")
                exact = false
            layout.lines.push(lineLayout)
        }
        layout.geometryFidelity = exact && editedLines.length === sourceLines.length ? "exact" : "estimated"
        return layout
    }

    function visualRunsForDraft(draft, pageSize, paperItem, rotation) {
        var runs = []
        if (!draft)
            return runs

        var layout = editableLayoutForDraft(draft)
        if (layout.lines.length > 0) {
            for (var layoutLineIndex = 0; layoutLineIndex < layout.lines.length; ++layoutLineIndex) {
                var layoutLine = layout.lines[layoutLineIndex] || {}
                var layoutRuns = layoutLine.runs || []
                for (var layoutRunIndex = 0; layoutRunIndex < layoutRuns.length; ++layoutRunIndex) {
                    var layoutRun = layoutRuns[layoutRunIndex] || {}
                    runs.push({
                        text: String(layoutRun.text || ""),
                        rect: mapPageRect(layoutRun.bbox || layoutLine.rect || layoutLine.fullRect || { x: 0, y: 0, width: 1, height: 1 },
                                          pageSize,
                                          paperItem,
                                          rotation),
                        fontFamily: layoutRun.fontFamily || draft.fontFamily || "",
                        fontFaceName: layoutRun.fontFaceName || draft.fontFaceName || "",
                        fontResourceName: layoutRun.fontResourceName || draft.fontResourceName || "",
                        fontSize: layoutRun.fontSize || draft.fontSize || root.editFontSize,
                        color: layoutRun.color || draft.color || root.editTextColor,
                        bold: layoutRun.bold !== undefined ? !!layoutRun.bold : !!draft.bold,
                        italic: layoutRun.italic !== undefined ? !!layoutRun.italic : !!draft.italic,
                        underline: layoutRun.underline !== undefined ? !!layoutRun.underline : !!draft.underline
                    })
                }
            }
            return runs
        }

        var explicitRuns = draft.visualRuns
                           || (draft.visualDocumentModel ? draft.visualDocumentModel.visualRuns : null)
                           || (draft.editableDocumentModel ? draft.editableDocumentModel.visualRuns : null)
        var currentDraftText = String(draft.text || draft.editablePlainText || "")
        var extractedDraftText = draftTextFromLines(draft)
        if (explicitRuns && explicitRuns.length !== undefined && explicitRuns.length > 0
                && (currentDraftText.length === 0 || currentDraftText === extractedDraftText)) {
            for (var explicitIndex = 0; explicitIndex < explicitRuns.length; ++explicitIndex) {
                var explicitRun = explicitRuns[explicitIndex] || {}
                if (explicitRun.runs && explicitRun.runs.length !== undefined) {
                    for (var nestedIndex = 0; nestedIndex < explicitRun.runs.length; ++nestedIndex) {
                        var nestedRun = explicitRun.runs[nestedIndex] || {}
                        runs.push({
                            text: String(nestedRun.text || ""),
                            rect: runRectFromSource(nestedRun, explicitRun, pageSize, paperItem, rotation),
                            fontFamily: nestedRun.fontFamily || draft.fontFamily || "",
                            fontFaceName: nestedRun.fontFaceName || draft.fontFaceName || "",
                            fontResourceName: nestedRun.fontResourceName || draft.fontResourceName || "",
                            fontSize: nestedRun.fontSize || draft.fontSize || root.editFontSize,
                            color: nestedRun.color || draft.color || root.editTextColor,
                            bold: nestedRun.bold !== undefined ? !!nestedRun.bold : !!draft.bold,
                            italic: nestedRun.italic !== undefined ? !!nestedRun.italic : !!draft.italic,
                            underline: nestedRun.underline !== undefined ? !!nestedRun.underline : !!draft.underline
                        })
                    }
                    continue
                }
                runs.push({
                    text: String(explicitRun.text || ""),
                    rect: runRectFromSource(explicitRun, null, pageSize, paperItem, rotation),
                    fontFamily: explicitRun.fontFamily || draft.fontFamily || "",
                    fontFaceName: explicitRun.fontFaceName || draft.fontFaceName || "",
                    fontResourceName: explicitRun.fontResourceName || draft.fontResourceName || "",
                    fontSize: explicitRun.fontSize || draft.fontSize || root.editFontSize,
                    color: explicitRun.color || draft.color || root.editTextColor,
                    bold: explicitRun.bold !== undefined ? !!explicitRun.bold : !!draft.bold,
                    italic: explicitRun.italic !== undefined ? !!explicitRun.italic : !!draft.italic,
                    underline: explicitRun.underline !== undefined ? !!explicitRun.underline : !!draft.underline
                })
            }
            return runs
        }

        var lines = draft.lines || []
        var editedLines = currentDraftText.split("\n")
        for (var lineIndex = 0; lineIndex < lines.length; ++lineIndex) {
            var line = lines[lineIndex] || {}
            var spans = line.spans || []
            var originalLineText = line.text !== undefined ? String(line.text || "") : lineTextFromSpans(line)
            var editedLineText = lineIndex < editedLines.length ? String(editedLines[lineIndex] || "") : originalLineText

            if (spans.length === 0) {
                runs.push({
                    text: editedLineText,
                    rect: runRectFromSource(line, line, pageSize, paperItem, rotation),
                    fontFamily: line.fontFamily || draft.fontFamily || "",
                    fontFaceName: line.fontFaceName || draft.fontFaceName || "",
                    fontResourceName: line.fontResourceName || draft.fontResourceName || "",
                    fontSize: line.fontSize || draft.fontSize || root.editFontSize,
                    color: line.color || draft.color || root.editTextColor,
                    bold: line.bold !== undefined ? !!line.bold : !!draft.bold,
                    italic: line.italic !== undefined ? !!line.italic : !!draft.italic,
                    underline: line.underline !== undefined ? !!line.underline : !!draft.underline
                })
                continue
            }

            if (editedLineText.length !== originalLineText.length) {
                var firstSpan = spans[0] || {}
                runs.push({
                    text: editedLineText,
                    rect: runRectFromSource(line, line, pageSize, paperItem, rotation),
                    fontFamily: firstSpan.fontFamily || draft.fontFamily || "",
                    fontFaceName: firstSpan.fontFaceName || draft.fontFaceName || "",
                    fontResourceName: firstSpan.fontResourceName || draft.fontResourceName || "",
                    fontSize: firstSpan.fontSize || draft.fontSize || root.editFontSize,
                    color: firstSpan.color || draft.color || root.editTextColor,
                    bold: firstSpan.bold !== undefined ? !!firstSpan.bold : !!draft.bold,
                    italic: firstSpan.italic !== undefined ? !!firstSpan.italic : !!draft.italic,
                    underline: firstSpan.underline !== undefined ? !!firstSpan.underline : !!draft.underline
                })
                continue
            }

            var offset = 0
            for (var spanIndex = 0; spanIndex < spans.length; ++spanIndex) {
                var span = spans[spanIndex] || {}
                var spanText = String(span.text || "")
                var nextText = editedLineText.substr(offset, spanText.length)
                offset += spanText.length
                if (nextText.length === 0 && spanText.length > 0)
                    continue
                runs.push({
                    text: nextText,
                    rect: runRectFromSource(span, line, pageSize, paperItem, rotation),
                    fontFamily: span.fontFamily || draft.fontFamily || "",
                    fontFaceName: span.fontFaceName || draft.fontFaceName || "",
                    fontResourceName: span.fontResourceName || draft.fontResourceName || "",
                    fontSize: span.fontSize || draft.fontSize || root.editFontSize,
                    color: span.color || draft.color || root.editTextColor,
                    bold: span.bold !== undefined ? !!span.bold : !!draft.bold,
                    italic: span.italic !== undefined ? !!span.italic : !!draft.italic,
                    underline: span.underline !== undefined ? !!span.underline : !!draft.underline
                })
            }
        }

        if (runs.length === 0 && String(draft.text || "").length > 0) {
            runs.push({
                text: String(draft.text || ""),
                rect: mapPageRect(draft.rect || { x: 0, y: 0, width: 1, height: 1 }, pageSize, paperItem, rotation),
                fontFamily: draft.fontFamily || "",
                fontFaceName: draft.fontFaceName || "",
                fontResourceName: draft.fontResourceName || "",
                fontSize: draft.fontSize || root.editFontSize,
                color: draft.color || root.editTextColor,
                bold: !!draft.bold,
                italic: !!draft.italic,
                underline: !!draft.underline
            })
        }
        return runs
    }

    function draftTextFromLines(draft) {
        if (!draft)
            return ""

        var lines = draft.lines || []
        if (lines.length === 0)
            return ""

        var parts = []
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i] || {}
            if (line.text !== undefined) {
                parts.push(String(line.text || ""))
                continue
            }

            var spans = line.spans || []
            var lineText = ""
            for (var j = 0; j < spans.length; ++j)
                lineText += String((spans[j] || {}).text || "")
            parts.push(lineText)
        }
        return parts.join("\n")
    }

    function lineForTextPosition(draft, cursorPosition) {
        var lines = draft && draft.lines ? draft.lines : []
        var cursor = Math.max(0, Number(cursorPosition) || 0)
        var offset = 0
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i] || {}
            var text = line.text !== undefined ? String(line.text || "") : lineTextFromSpans(line)
            var end = offset + text.length
            if (cursor <= end || i === lines.length - 1)
                return { line: line, lineIndex: i, start: offset, end: end }
            offset = end + 1
        }
        return { line: null, lineIndex: -1, start: 0, end: 0 }
    }

    function glyphForTextPosition(line, cursorPosition) {
        if (!line)
            return null
        var spans = line.spans || []
        var cursor = Math.max(0, Number(cursorPosition) || 0)
        var previousGlyph = null
        for (var spanIndex = 0; spanIndex < spans.length; ++spanIndex) {
            var glyphs = (spans[spanIndex] || {}).glyphs || []
            for (var glyphIndex = 0; glyphIndex < glyphs.length; ++glyphIndex) {
                var glyph = glyphs[glyphIndex] || {}
                var charStart = Number(glyph.charStart)
                var charEnd = Number(glyph.charEnd)
                if (!isFinite(charStart) || !isFinite(charEnd) || charStart < 0 || charEnd < 0)
                    continue
                if (cursor >= charStart && cursor <= charEnd)
                    return glyph
                if (cursor > charEnd)
                    previousGlyph = glyph
            }
        }
        return previousGlyph
    }

    function textPositionForPoint(draft, point) {
        var layout = editableLayoutForDraft(draft)
        if (layout.lines.length > 0) {
            var bestLayoutLine = layout.lines[0] || {}
            var bestLayoutDistance = Number.MAX_VALUE
            for (var layoutLineIndex = 0; layoutLineIndex < layout.lines.length; ++layoutLineIndex) {
                var candidateLine = layout.lines[layoutLineIndex] || {}
                var candidateRect = candidateLine.fullRect || candidateLine.rect || {}
                var centerY = Number(candidateRect.y || 0) + Math.max(1, Number(candidateRect.height || 1)) / 2
                var distanceY = Math.abs((Number(point.y) || 0) - centerY)
                if (distanceY < bestLayoutDistance) {
                    bestLayoutDistance = distanceY
                    bestLayoutLine = candidateLine
                }
            }

            var insertionPoints = bestLayoutLine.insertionPoints || []
            var bestInsertionIndex = 0
            var bestInsertionDistance = Number.MAX_VALUE
            for (var insertionIndex = 0; insertionIndex < insertionPoints.length; ++insertionIndex) {
                var distanceX = Math.abs((Number(point.x) || 0) - Number(insertionPoints[insertionIndex] || 0))
                if (distanceX < bestInsertionDistance) {
                    bestInsertionDistance = distanceX
                    bestInsertionIndex = insertionIndex
                }
            }
            return Math.max(0, Math.min(String(draft.text || "").length, Number(bestLayoutLine.start || 0) + bestInsertionIndex))
        }

        var anchorLine = lineForTextPosition(draft, draft ? Number(draft.cursorPosition || 0) : 0)
        var lines = draft && draft.lines ? draft.lines : []
        if (!draft || lines.length === 0)
            return 0

        var bestLine = anchorLine.line
        var bestDistance = Number.MAX_VALUE
        for (var lineIndex = 0; lineIndex < lines.length; ++lineIndex) {
            var line = lines[lineIndex] || {}
            var bbox = line.bbox || {}
            var top = Number(bbox.y || 0)
            var height = Math.max(1, Number(bbox.height || 1))
            var centerY = top + height / 2
            var distance = Math.abs((Number(point.y) || 0) - centerY)
            if (distance < bestDistance) {
                bestDistance = distance
                bestLine = line
            }
        }

        var nearestGlyph = glyphForTextPosition(bestLine, Number(draft.cursorPosition || 0))
        var bestPosition = bestLine && bestLine.text !== undefined ? Number((bestLine.spans || [])[0] && ((bestLine.spans || [])[0].start)) || 0 : 0
        if (nearestGlyph && nearestGlyph.charStart !== undefined)
            bestPosition = Number(nearestGlyph.charStart) || bestPosition
        var bestGlyphDistance = Number.MAX_VALUE
        var spans = bestLine ? bestLine.spans || [] : []
        for (var spanIndex = 0; spanIndex < spans.length; ++spanIndex) {
            var glyphs = (spans[spanIndex] || {}).glyphs || []
            for (var glyphIndex = 0; glyphIndex < glyphs.length; ++glyphIndex) {
                var glyph = glyphs[glyphIndex] || {}
                var charStart = Number(glyph.charStart)
                var charEnd = Number(glyph.charEnd)
                var rect = glyph.bbox || (glyph.quad ? rectFromQuadPath(glyph.quad) : null)
                if (!rect || !isFinite(charStart) || !isFinite(charEnd))
                    continue
                var midX = Number(rect.x || 0) + Math.max(1, Number(rect.width || 1)) / 2
                var distanceX = Math.abs((Number(point.x) || 0) - midX)
                if (distanceX < bestGlyphDistance) {
                    bestGlyphDistance = distanceX
                    bestPosition = (Number(point.x) || 0) <= midX ? charStart : charEnd
                }
            }
        }

        return Math.max(0, Math.min(String(draft.text || "").length, bestPosition))
    }

    function caretRectForTextPosition(draft, cursorPosition, pageSize, paperItem, rotation) {
        if (!draft)
            return { x: 0, y: 0, width: 1, height: 12 }

        var layout = editableLayoutForDraft(draft)
        if (layout.lines.length > 0) {
            var cursor = Math.max(0, Number(cursorPosition || 0))
            var caretLine = layout.lines[0] || {}
            for (var layoutLineIndex = 0; layoutLineIndex < layout.lines.length; ++layoutLineIndex) {
                var candidate = layout.lines[layoutLineIndex] || {}
                if (cursor >= Number(candidate.start || 0) && cursor <= Number(candidate.end || 0)) {
                    caretLine = candidate
                    break
                }
                if (layoutLineIndex === layout.lines.length - 1)
                    caretLine = candidate
            }

            var insertionPoints = caretLine.insertionPoints || []
            var localCursor = Math.max(0, Math.min(insertionPoints.length - 1, cursor - Number(caretLine.start || 0)))
            var lineRect = caretLine.fullRect || caretLine.rect || { x: 0, y: 0, width: 1, height: 12 }
            var caretRectFromLayout = {
                x: insertionPoints.length > 0 ? Number(insertionPoints[localCursor] || lineRect.x || 0) : Number(lineRect.x || 0),
                y: Number(lineRect.y || 0),
                width: 1,
                height: Math.max(8, Number(lineRect.height || 12))
            }
            return mapPageRect(caretRectFromLayout, pageSize, paperItem, rotation)
        }

        var lineInfo = lineForTextPosition(draft, cursorPosition)
        var line = lineInfo.line
        var glyph = glyphForTextPosition(line, cursorPosition)
        var lineRect = line && line.bbox ? line.bbox : (draft.rect || { x: 0, y: 0, width: 1, height: 12 })
        var caretRect = { x: Number(lineRect.x || 0), y: Number(lineRect.y || 0), width: 1, height: Math.max(8, Number(lineRect.height || 12)) }

        if (glyph) {
            var glyphRect = glyph.bbox || (glyph.quad ? rectFromQuadPath(glyph.quad) : null)
            if (glyphRect) {
                var charStart = Number(glyph.charStart)
                var charEnd = Number(glyph.charEnd)
                var atEnd = Number(cursorPosition || 0) >= charEnd
                caretRect = {
                    x: Number(glyphRect.x || 0) + (atEnd ? Math.max(1, Number(glyphRect.width || 1)) : 0),
                    y: Number(glyphRect.y || lineRect.y || 0),
                    width: 1,
                    height: Math.max(8, Number(glyphRect.height || lineRect.height || 12))
                }
            }
        } else {
            var text = line && line.text !== undefined ? String(line.text || "") : ""
            var progress = text.length > 0 ? Math.max(0, Math.min(1, (Number(cursorPosition || 0) - lineInfo.start) / text.length)) : 0
            caretRect.x = Number(lineRect.x || 0) + Math.max(1, Number(lineRect.width || 1)) * progress
        }

        return mapPageRect(caretRect, pageSize, paperItem, rotation)
    }

    function selectionRectsForDraft(draft, pageSize, paperItem, rotation) {
        var rects = []
        if (!draft)
            return rects

        var start = Math.min(Number(draft.selectionStart || 0), Number(draft.selectionEnd || 0))
        var end = Math.max(Number(draft.selectionStart || 0), Number(draft.selectionEnd || 0))
        if (start === end)
            return rects

        var layout = editableLayoutForDraft(draft)
        for (var i = 0; i < layout.lines.length; ++i) {
            var line = layout.lines[i] || {}
            var lineStart = Number(line.start || 0)
            var lineEnd = Number(line.end || lineStart)
            var overlapStart = Math.max(start, lineStart)
            var overlapEnd = Math.min(end, lineEnd)
            if (overlapEnd <= overlapStart)
                continue

            var insertionPoints = line.insertionPoints || []
            var first = Math.max(0, Math.min(insertionPoints.length - 1, overlapStart - lineStart))
            var last = Math.max(0, Math.min(insertionPoints.length - 1, overlapEnd - lineStart))
            var sourceRect = line.fullRect || line.rect || { x: 0, y: 0, width: 1, height: 12 }
            var selectionRect = {
                x: Number(insertionPoints[first] || sourceRect.x || 0),
                y: Number(sourceRect.y || 0),
                width: Math.max(1, Number(insertionPoints[last] || sourceRect.x || 0) - Number(insertionPoints[first] || sourceRect.x || 0)),
                height: Math.max(8, Number(sourceRect.height || 12))
            }
            rects.push(mapPageRect(selectionRect, pageSize, paperItem, rotation))
        }

        return rects
    }

    function prepareRichTextDraft(seed) {
        if (!seed)
            return seed

        if (!seed.originalBlockModel)
            seed.originalBlockModel = JSON.parse(JSON.stringify(seed))
        var lineText = draftTextFromLines(seed)
        var seedText = String(seed.text || "")
        var originalSeedText = String(seed.originalText || seedText)
        if (lineText.length > 0
                && (String(seed.type || "") !== "replaceTextBlock" || seedText === originalSeedText))
            seed.text = lineText
        if (!seed.originalText)
            seed.originalText = String(seed.text || "")
        if (!seed.editableDocumentModel) {
            seed.editableDocumentModel = {
                plainText: String(seed.text || ""),
                spans: seed.spans || [],
                lines: seed.lines || [],
                visualRuns: seed.visualRuns || [],
                fidelity: seed.fidelity || {}
            }
        }
        if (!seed.visualDocumentModel) {
            seed.visualDocumentModel = {
                plainText: String(seed.text || ""),
                spans: seed.spans || [],
                lines: seed.lines || [],
                visualRuns: seed.visualRuns || [],
                fidelity: seed.fidelity || {}
            }
        }
        seed.editablePlainText = String(seed.text || "")
        if (!seed.dirtyRanges)
            seed.dirtyRanges = []
        if (!seed.layoutMode)
            seed.layoutMode = "preserve-lines"
        if (seed.cursorPosition === undefined)
            seed.cursorPosition = Math.max(0, Math.min(String(seed.text || "").length, String(seed.text || "").length))
        if (seed.selectionStart === undefined)
            seed.selectionStart = seed.cursorPosition
        if (seed.selectionEnd === undefined)
            seed.selectionEnd = seed.cursorPosition
        seed.styleSyncLocked = true
        seed.geometryFidelity = seed.geometryFidelity || "exact"
        return seed
    }

    function dirtyRangesForText(originalText, nextText) {
        var original = String(originalText || "")
        var next = String(nextText || "")
        if (original === next)
            return []

        var prefix = 0
        while (prefix < original.length
               && prefix < next.length
               && original.charAt(prefix) === next.charAt(prefix)) {
            prefix += 1
        }

        var suffix = 0
        while (suffix < original.length - prefix
               && suffix < next.length - prefix
               && original.charAt(original.length - suffix - 1) === next.charAt(next.length - suffix - 1)) {
            suffix += 1
        }

        return [{
            start: prefix,
            end: Math.max(prefix, next.length - suffix),
            originalEnd: Math.max(prefix, original.length - suffix)
        }]
    }

    function updateActiveDraftText(text) {
        if (!activeTextDraft)
            return

        activeTextDraft.text = text
        activeTextDraft.editablePlainText = text
        if (!activeTextDraft.editableDocumentModel)
            activeTextDraft.editableDocumentModel = {}
        activeTextDraft.editableDocumentModel.plainText = text
        activeTextDraft.editableDocumentModel.spans = activeTextDraft.spans || []
        activeTextDraft.editableDocumentModel.lines = activeTextDraft.lines || []
        activeTextDraft.editableDocumentModel.visualRuns = activeTextDraft.visualRuns || []
        activeTextDraft.editableDocumentModel.fidelity = activeTextDraft.fidelity || {}
        if (!activeTextDraft.visualDocumentModel)
            activeTextDraft.visualDocumentModel = {}
        activeTextDraft.visualDocumentModel.plainText = text
        activeTextDraft.visualDocumentModel.spans = activeTextDraft.spans || []
        activeTextDraft.visualDocumentModel.lines = activeTextDraft.lines || []
        activeTextDraft.visualDocumentModel.visualRuns = activeTextDraft.visualRuns || []
        activeTextDraft.visualDocumentModel.fidelity = activeTextDraft.fidelity || {}
        var originalText = String(activeTextDraft.originalText
                                  || (activeTextDraft.originalBlockModel ? activeTextDraft.originalBlockModel.text : "")
                                  || "")
        activeTextDraft.dirtyRanges = dirtyRangesForText(originalText, text)
        activeTextDraft.editableDocumentModel.dirtyRanges = activeTextDraft.dirtyRanges
        activeTextDraft.visualDocumentModel.dirtyRanges = activeTextDraft.dirtyRanges
        activeTextDraft.cursorPosition = Math.max(0, Math.min(String(text || "").length, activeTextDraft.cursorPosition || 0))
        activeTextDraft.selectionStart = activeTextDraft.cursorPosition
        activeTextDraft.selectionEnd = activeTextDraft.cursorPosition
        activeTextDraft.geometryFidelity = activeTextDraft.dirtyRanges.length > 0 ? "estimated" : "exact"
        activeTextDraft = activeTextDraft
    }

    function setActiveDraftCursorPosition(position) {
        if (!activeTextDraft)
            return

        var cursor = Math.max(0, Math.min(String(activeTextDraft.text || "").length, Number(position) || 0))
        if (Number(activeTextDraft.cursorPosition || 0) === cursor
                && Number(activeTextDraft.selectionStart || 0) === cursor
                && Number(activeTextDraft.selectionEnd || 0) === cursor)
            return

        activeTextDraft.cursorPosition = cursor
        activeTextDraft.selectionStart = cursor
        activeTextDraft.selectionEnd = cursor
        activeTextDraft = activeTextDraft
        if (draftTextArea && draftTextArea.cursorPosition !== cursor)
            draftTextArea.cursorPosition = cursor
    }

    function syncActiveDraftTextSelection(start, end) {
        if (!activeTextDraft)
            return

        var textLength = String(activeTextDraft.text || "").length
        var safeStart = Math.max(0, Math.min(textLength, Number(start || 0)))
        var safeEnd = Math.max(0, Math.min(textLength, Number(end || safeStart)))
        if (Number(activeTextDraft.selectionStart || 0) === safeStart
                && Number(activeTextDraft.selectionEnd || 0) === safeEnd)
            return

        activeTextDraft.selectionStart = safeStart
        activeTextDraft.selectionEnd = safeEnd
        activeTextDraft.cursorPosition = safeEnd
        activeTextDraft = activeTextDraft
    }

    function moveCaretInActiveDraft(point) {
        if (!activeTextDraft)
            return

        setActiveDraftCursorPosition(textPositionForPoint(activeTextDraft, point))
    }

    function startTextEdit(pageIndex, point) {
        if (!textEditSeedAction)
            return

        if (activeTextDraft && pointInsideRect(point, activeTextDraft.rect || activeTextDraft.originalRect || {})) {
            moveCaretInActiveDraft(point)
            return
        }

        if (activeTextDraft)
            commitActiveTextDraft()

        var seed = textEditSeedAction(pageIndex, point)
        if (!seed)
            return

        seed.pageIndex = pageIndex
        if (!seed.rect)
            seed.rect = { x: point.x, y: point.y, width: 180, height: 24 }
        seed = prepareRichTextDraft(seed)
        activeTextDraft = seed
    }

    function activateTextBlock(pageIndex, block) {
        if (!block)
            return

        if (activeTextDraft && String(activeTextDraft.blockKey || "") === String(block.blockKey || "")) {
            return
        }

        if (activeTextDraft)
            commitActiveTextDraft()

        var seed = JSON.parse(JSON.stringify(block))
        seed.pageIndex = pageIndex
        if (!seed.rect)
            seed.rect = seed.originalRect || { x: 72, y: 72, width: 180, height: 24 }
        seed = prepareRichTextDraft(seed)
        activeTextDraft = seed
    }

    function commitActiveTextDraft() {
        if (!activeTextDraft || !commitTextEditAction)
            return

        var originalText = String(activeTextDraft.originalText
                                  || (activeTextDraft.originalBlockModel ? activeTextDraft.originalBlockModel.text : "")
                                  || "")
        var draftText = String(activeTextDraft.text || "")
        var hasDirtyRanges = activeTextDraft.dirtyRanges && activeTextDraft.dirtyRanges.length > 0
        var originalRect = activeTextDraft.originalBlockModel && activeTextDraft.originalBlockModel.rect
                ? activeTextDraft.originalBlockModel.rect
                : (activeTextDraft.originalRect || activeTextDraft.rect || {})
        var rectChanged = JSON.stringify(activeTextDraft.rect || {}) !== JSON.stringify(originalRect || {})
        if (!hasDirtyRanges && draftText === originalText && !rectChanged) {
            activeTextDraft = null
            return
        }

        var draft = JSON.parse(JSON.stringify(activeTextDraft))
        draft.text = activeTextDraft.text || ""
        draft.fontFamily = activeTextDraft.fontFamily || editFontFamily
        draft.fontSize = activeTextDraft.fontSize || editFontSize
        draft.color = activeTextDraft.color || editTextColor
        draft.bold = activeTextDraft.bold !== undefined ? !!activeTextDraft.bold : editBold
        draft.italic = activeTextDraft.italic !== undefined ? !!activeTextDraft.italic : editItalic
        draft.underline = activeTextDraft.underline !== undefined ? !!activeTextDraft.underline : editUnderline
        draft.originalBlockModel = activeTextDraft.originalBlockModel || {}
        draft.editableDocumentModel = activeTextDraft.editableDocumentModel || {
            plainText: draft.text,
            spans: activeTextDraft.spans || [],
            lines: activeTextDraft.lines || [],
            visualRuns: activeTextDraft.visualRuns || [],
            fidelity: activeTextDraft.fidelity || {}
        }
        draft.visualDocumentModel = activeTextDraft.visualDocumentModel || {
            plainText: draft.text,
            spans: activeTextDraft.spans || [],
            lines: activeTextDraft.lines || [],
            visualRuns: activeTextDraft.visualRuns || [],
            fidelity: activeTextDraft.fidelity || {}
        }
        draft.editablePlainText = activeTextDraft.editablePlainText || draft.text
        draft.visualRuns = activeTextDraft.visualRuns || []
        draft.fidelity = activeTextDraft.fidelity || {}
        draft.dirtyRanges = activeTextDraft.dirtyRanges || []
        draft.layoutMode = activeTextDraft.layoutMode || "preserve-lines"
        draft.cursorPosition = activeTextDraft.cursorPosition
        draft.selectionStart = activeTextDraft.selectionStart
        draft.selectionEnd = activeTextDraft.selectionEnd
        draft.geometryFidelity = activeTextDraft.geometryFidelity

        if (commitTextEditAction(draft))
            activeTextDraft = null
    }

    function updateActiveTextDraftStyle(stylePatch) {
        if (!activeTextDraft || !stylePatch)
            return
        if (activeTextDraft.styleSyncLocked && syncingPdfTextStyle)
            return

        var draft = JSON.parse(JSON.stringify(activeTextDraft))
        var keys = Object.keys(stylePatch)
        for (var i = 0; i < keys.length; ++i)
            draft[keys[i]] = stylePatch[keys[i]]
        draft.styleSyncLocked = false
        activeTextDraft = draft
    }

    function clearTextBlockCache() {
        pageTextBlockCache = ({})
    }

    function pageTextBlocks(pageIndex) {
        if (!editModeEnabled || editTool !== "text" || (!textElementsForPageAction && !textBlocksForPageAction))
            return []

        var key = String(pageIndex)
        var cached = pageTextBlockCache[key]
        if (cached && cached.length !== undefined)
            return cached

        var parsed = []
        try {
            parsed = JSON.parse(textElementsForPageAction
                                ? textElementsForPageAction(pageIndex) || "[]"
                                : textBlocksForPageAction(pageIndex) || "[]")
        } catch(e) {
            parsed = []
        }

        var textBlocks = []
        for (var i = 0; i < parsed.length; ++i) {
            var element = parsed[i] || {}
            if (String(element.elementType || "text") === "text" && element.editable !== false)
                textBlocks.push(element)
        }

        pageTextBlockCache[key] = textBlocks
        return textBlocks
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
