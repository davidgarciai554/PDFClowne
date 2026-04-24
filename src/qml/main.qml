pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.settings
import PDFClowne
import PDFClowne.Backend

ApplicationWindow {
    id: window
    visible: true
    width: 1100
    height: 780
    minimumWidth: 640
    minimumHeight: 480
    title: hasActiveDocument ? activeDocumentTitle() + " - PDFClowne" : "PDFClowne"
    color: Theme.background
    property real viewerZoom: 1.0
    property string layoutMode: "continuous"
    property string zoomMode: "fitPage"
    property bool navigationPanelVisible: true
    property int activePageIndex: 0
    property int activeDocumentIndex: -1
    property string saveMessage: ""
    property var zoomPresetOptions: [
        { text: "50%", value: 50 },
        { text: "75%", value: 75 },
        { text: "100%", value: 100 },
        { text: "125%", value: 125 },
        { text: "150%", value: 150 },
        { text: "200%", value: 200 },
        { text: "300%", value: 300 },
        { text: "400%", value: 400 },
        { text: "Manual", value: 0 }
    ]
    readonly property int maximumZoomPercent: 450
    readonly property bool hasActiveDocument: activeDocumentIndex >= 0 && activeDocumentIndex < documentModel.count
    signal jumpToPageRequested(int index)

    onVisibleChanged: if (visible) Theme.applyColorScheme()

    PdfDocument {
        id: pdfDocument
    }

    Settings {
        id: recentSettings
        category: "RecentFiles"
        property string filesJson: "[]"
    }

    Settings {
        id: documentViewSettings
        category: "DocumentViewState"
        property string statesJson: "{}"
    }

    ListModel {
        id: recentModel
    }

    ListModel {
        id: documentModel
    }

    Component.onCompleted: loadRecentFiles()

    FileDialog {
        id: fileDialog
        title: "Open PDF"
        nameFilters: ["PDF Files (*.pdf)", "All Files (*)"]
        onAccepted: window.openPdf(selectedFile.toString())
    }

    FileDialog {
        id: saveRotatedDialog
        title: "Guardar como PDF rotado"
        fileMode: FileDialog.SaveFile
        nameFilters: ["PDF Files (*.pdf)", "All Files (*)"]
        onAccepted: window.saveActiveDocumentAsRotated(selectedFile.toString())
    }

    Popup {
        id: openPdfErrorDialog
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(420, window.width - 48)
        x: Math.round((window.width - width) / 2)
        y: Math.round((window.height - height) / 2)
        padding: 0

        property string fileName: ""
        property string reason: ""

        Overlay.modal: Rectangle {
            color: Theme.isDark ? "#AA0F1020" : "#660F1020"
        }

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radius
            border.color: Theme.border
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                Layout.leftMargin: 18
                Layout.rightMargin: 12
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 12
                    color: Theme.danger

                    Text {
                        anchors.centerIn: parent
                        text: "!"
                        color: Theme.accentText
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    text: "No se pudo abrir el PDF"
                    color: Theme.text
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                }

                Button {
                    id: closeErrorIconButton
                    text: "X"
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    onClicked: openPdfErrorDialog.close()
                    ToolTip.visible: hovered
                    ToolTip.text: "Cerrar"

                    contentItem: Text {
                        text: closeErrorIconButton.text
                        color: Theme.secondaryText
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: closeErrorIconButton.down ? Theme.tabActive
                              : closeErrorIconButton.hovered ? Theme.hover
                              : "transparent"
                        radius: Theme.radius
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 22
                Layout.rightMargin: 22
                Layout.topMargin: 18
                Layout.bottomMargin: 18
                spacing: 12

                Text {
                    text: "PDFClowne no puede leer este archivo."
                    color: Theme.text
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: Theme.radius
                    color: Theme.surfaceAlt
                    border.color: Theme.border

                    Text {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: 12
                            rightMargin: 12
                        }
                        text: openPdfErrorDialog.fileName
                        color: Theme.text
                        font.pixelSize: 12
                        elide: Text.ElideMiddle
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    text: openPdfErrorDialog.reason
                    color: Theme.secondaryText
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6

                    Item { Layout.fillWidth: true }

                    Button {
                        id: closeErrorButton
                        text: "Cerrar"
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 34
                        onClicked: openPdfErrorDialog.close()

                        contentItem: Text {
                            text: closeErrorButton.text
                            color: Theme.accentText
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: closeErrorButton.down ? Qt.darker(Theme.accent, 1.12)
                                  : closeErrorButton.hovered ? Qt.lighter(Theme.accent, 1.08)
                                  : Theme.accent
                            radius: Theme.radius
                        }
                    }
                }
            }
        }
    }

    Shortcut { sequence: "Ctrl+O"; onActivated: fileDialog.open() }
    Shortcut { sequence: "Ctrl+S"; enabled: window.activeDocumentHasRotations(); onActivated: window.saveActiveDocumentRotated() }
    Shortcut { sequence: "Ctrl+Shift+S"; enabled: window.activeDocumentHasRotations(); onActivated: saveRotatedDialog.open() }
    Shortcut { sequence: "Ctrl+1"; enabled: window.hasActiveDocument; onActivated: window.setLayoutMode("single") }
    Shortcut { sequence: "Ctrl+2"; enabled: window.hasActiveDocument; onActivated: window.setLayoutMode("continuous") }
    Shortcut { sequence: "Ctrl+3"; enabled: window.hasActiveDocument; onActivated: window.setLayoutMode("twoPage") }
    Shortcut { sequence: "Ctrl+4"; enabled: window.hasActiveDocument; onActivated: window.setLayoutMode("twoPageContinuous") }

    function fileNameFromPath(path) {
        var normalized = String(path || "").replace(/\\/g, "/")
        var index = normalized.lastIndexOf("/")
        return index >= 0 ? normalized.slice(index + 1) : normalized
    }

    function readDocumentViewStates() {
        try {
            var parsed = JSON.parse(documentViewSettings.statesJson || "{}")
            return parsed && typeof parsed === "object" ? parsed : {}
        } catch(e) {
            return {}
        }
    }

    function writeDocumentViewStates(states) {
        documentViewSettings.statesJson = JSON.stringify(states || {})
    }

    function defaultDocumentViewState() {
        return {
            zoom: 1.0,
            layoutMode: "continuous",
            zoomMode: "fitPage"
        }
    }

    function savedViewStateFor(path) {
        var states = readDocumentViewStates()
        var key = String(path || "")
        if (!key || !states[key])
            return defaultDocumentViewState()

        var state = states[key]
        return {
            zoom: normalizedZoom(state.zoom),
            layoutMode: state.layoutMode || "continuous",
            zoomMode: state.zoomMode || "fitPage"
        }
    }

    function persistViewState(path, state) {
        var key = String(path || "")
        if (!key)
            return

        var states = readDocumentViewStates()
        states[key] = {
            zoom: normalizedZoom(state.zoom),
            layoutMode: state.layoutMode || "continuous",
            zoomMode: state.zoomMode || "fitPage"
        }
        writeDocumentViewStates(states)
    }

    function loadRecentFiles() {
        recentModel.clear()

        var files = []
        try {
            files = JSON.parse(recentSettings.filesJson || "[]")
        } catch(e) {
            files = []
        }

        for (var i = 0; i < files.length && recentModel.count < 5; ++i) {
            if (files[i] && files[i].path) {
                recentModel.append({
                    path: files[i].path,
                    name: files[i].name || fileNameFromPath(files[i].path)
                })
            }
        }
    }

    function saveRecentFiles() {
        var files = []
        for (var i = 0; i < recentModel.count; ++i) {
            var item = recentModel.get(i)
            files.push({ path: item.path, name: item.name })
        }
        recentSettings.filesJson = JSON.stringify(files)
    }

    function addRecentFile(path, name) {
        if (!path || path.length === 0)
            return

        for (var i = recentModel.count - 1; i >= 0; --i) {
            if (recentModel.get(i).path === path)
                recentModel.remove(i)
        }

        recentModel.insert(0, {
            path: path,
            name: name && name.length > 0 ? name : fileNameFromPath(path)
        })

        while (recentModel.count > 5)
            recentModel.remove(recentModel.count - 1)

        saveRecentFiles()
    }

    function clearRecentFiles() {
        recentModel.clear()
        saveRecentFiles()
    }

    function removeRecentFile(path) {
        for (var i = recentModel.count - 1; i >= 0; --i) {
            if (recentModel.get(i).path === path)
                recentModel.remove(i)
        }

        saveRecentFiles()
    }

    function loadedPageSources() {
        var sources = []
        try {
            if (pdfDocument.pageSources && pdfDocument.pageSources.length > 0) {
                for (var i = 0; i < pdfDocument.pageSources.length; ++i)
                    sources.push(pdfDocument.pageSources[i])
            }
        } catch(e) {
            sources = []
        }

        if (sources.length === 0 && pdfDocument.previewSource.length > 0)
            sources.push(pdfDocument.previewSource)

        return sources
    }

    function loadedThumbnailSources() {
        var sources = []
        try {
            if (pdfDocument.thumbnailSources && pdfDocument.thumbnailSources.length > 0) {
                for (var i = 0; i < pdfDocument.thumbnailSources.length; ++i)
                    sources.push(pdfDocument.thumbnailSources[i])
            }
        } catch(e) {
            sources = []
        }

        return sources
    }

    function activeDocumentTitle() {
        return hasActiveDocument ? documentModel.get(activeDocumentIndex).title : ""
    }

    function activeDocumentPageCount() {
        return hasActiveDocument ? Math.max(1, documentModel.get(activeDocumentIndex).pageCount || 1) : 0
    }

    function activeDocumentPageSources() {
        if (!hasActiveDocument)
            return []

        var doc = documentModel.get(activeDocumentIndex)
        var sources = []
        try {
            sources = JSON.parse(doc.pageSourcesJson || "[]")
        } catch(e) {
            sources = []
        }

        if (sources.length === 0 && doc.previewSource && doc.previewSource.length > 0)
            sources = [doc.previewSource]

        return sources
    }

    function activeDocumentThumbnailSources() {
        if (!hasActiveDocument)
            return []

        try {
            return JSON.parse(documentModel.get(activeDocumentIndex).thumbnailSourcesJson || "[]")
        } catch(e) {
            return []
        }
    }

    function activeDocumentPageSizesJson() {
        return hasActiveDocument ? documentModel.get(activeDocumentIndex).pageSizesJson || "[]" : "[]"
    }

    function activeDocumentPageRotations() {
        if (!hasActiveDocument)
            return []

        try {
            return JSON.parse(documentModel.get(activeDocumentIndex).pageRotationsJson || "[]")
        } catch(e) {
            return []
        }
    }

    function activeDocumentHasRotations() {
        var rotations = activeDocumentPageRotations()
        for (var i = 0; i < rotations.length; ++i) {
            if ((rotations[i] || 0) !== 0)
                return true
        }

        return false
    }

    function syncActiveDocumentState() {
        if (!hasActiveDocument)
            return

        viewerZoom = normalizedZoom(viewerZoom)
        documentModel.setProperty(activeDocumentIndex, "zoom", viewerZoom)
        documentModel.setProperty(activeDocumentIndex, "layoutMode", layoutMode)
        documentModel.setProperty(activeDocumentIndex, "zoomMode", zoomMode)
        documentModel.setProperty(activeDocumentIndex, "navigationPanelVisible", navigationPanelVisible)
        documentModel.setProperty(activeDocumentIndex, "activePageIndex", activePageIndex)
        persistViewState(documentModel.get(activeDocumentIndex).path, {
            zoom: viewerZoom,
            layoutMode: layoutMode,
            zoomMode: zoomMode
        })
    }

    function normalizedZoom(value) {
        var zoom = Number(value)
        if (!isFinite(zoom) || zoom <= 0)
            return 1.0

        return Math.max(0.05, Math.min(20.0, zoom))
    }

    function currentZoomBaseScale() {
        if (!hasActiveDocument || !pdfViewer)
            return 1.0

        var scale = Number(pdfViewer.currentBaseScale)
        if (!isFinite(scale) || scale <= 0)
            return 1.0

        return scale
    }

    function effectiveZoomPercent() {
        return Math.round(currentZoomBaseScale() * pdfViewer.renderScale * normalizedZoom(viewerZoom) * 100)
    }

    function normalizedZoomPercent(value) {
        var percent = Number(value)
        if (!isFinite(percent) || percent <= 0)
            return effectiveZoomPercent()

        return Math.max(10, Math.min(maximumZoomPercent, Math.round(percent)))
    }

    function zoomPresetIndex() {
        var current = effectiveZoomPercent()
        for (var i = 0; i < zoomPresetOptions.length - 1; ++i) {
            if (zoomPresetOptions[i].value === current)
                return i
        }
        return zoomPresetOptions.length - 1
    }

    function setActiveDocument(index) {
        if (index < 0 || index >= documentModel.count) {
            activeDocumentIndex = -1
            viewerZoom = 1.0
            layoutMode = "continuous"
            zoomMode = "fitPage"
            activePageIndex = 0
            return
        }

        activeDocumentIndex = index
        var doc = documentModel.get(index)
        var savedState = savedViewStateFor(doc.path)
        viewerZoom = normalizedZoom(doc.zoom !== undefined ? doc.zoom : savedState.zoom)
        layoutMode = doc.layoutMode || savedState.layoutMode || "continuous"
        zoomMode = doc.zoomMode || doc.viewMode || savedState.zoomMode || "fitPage"
        navigationPanelVisible = doc.navigationPanelVisible === undefined ? true : doc.navigationPanelVisible
        activePageIndex = doc.activePageIndex || 0

        if (pdfDocument.filePath !== doc.path)
            pdfDocument.load(doc.path)
    }

    function closeActiveDocument() {
        if (!hasActiveDocument)
            return

        documentModel.remove(activeDocumentIndex)
        if (documentModel.count === 0) {
            setActiveDocument(-1)
        } else if (activeDocumentIndex >= documentModel.count) {
            setActiveDocument(documentModel.count - 1)
        } else {
            setActiveDocument(activeDocumentIndex)
        }
    }

    function openPdf(source) {
        if (pdfDocument.load(source)) {
            saveMessage = ""
            window.visibility = Window.Maximized

            for (var i = 0; i < documentModel.count; ++i) {
                if (documentModel.get(i).path === pdfDocument.filePath) {
                    setActiveDocument(i)
                    addRecentFile(pdfDocument.filePath, pdfDocument.title)
                    return
                }
            }

            var sources = loadedPageSources()
            var thumbnails = loadedThumbnailSources()
            var savedState = savedViewStateFor(pdfDocument.filePath)

            documentModel.append({
                path: pdfDocument.filePath,
                title: pdfDocument.title,
                previewSource: pdfDocument.previewSource,
                pageSourcesJson: JSON.stringify(sources),
                thumbnailSourcesJson: JSON.stringify(thumbnails),
                pageSizesJson: pdfDocument.pageSizesJson,
                pageCount: pdfDocument.pageCount,
                zoom: savedState.zoom,
                layoutMode: savedState.layoutMode,
                zoomMode: savedState.zoomMode,
                navigationPanelVisible: true,
                activePageIndex: 0,
                pageRotationsJson: "[]"
            })
            setActiveDocument(documentModel.count - 1)
            addRecentFile(pdfDocument.filePath, pdfDocument.title)
        } else {
            showOpenPdfError(source)
        }
    }

    function showOpenPdfError(source) {
        openPdfErrorDialog.fileName = fileNameFromPath(source)
        openPdfErrorDialog.reason = friendlyOpenPdfError()
        openPdfErrorDialog.open()
    }

    function friendlyOpenPdfError() {
        var raw = String(pdfDocument.errorMessage || "").toLowerCase()

        if (raw.indexOf("password") >= 0 || raw.indexOf("contrasena") >= 0)
            return "El PDF parece protegido con contrasena. Esta version todavia no puede abrir documentos protegidos."

        if (raw.indexOf("valid pdf") >= 0 || raw.indexOf("no objects") >= 0 ||
            raw.indexOf("cannot recognize") >= 0 || raw.indexOf("corrupt") >= 0)
            return "El archivo parece estar corrupto, incompleto o no ser un PDF valido."

        if (raw.indexOf("permission") >= 0 || raw.indexOf("access") >= 0 ||
            raw.indexOf("denied") >= 0)
            return "Windows no permite leer este archivo. Revisa permisos o si otra aplicacion lo tiene bloqueado."

        if (raw.indexOf("path") >= 0 || raw.indexOf("resolved") >= 0)
            return "No se pudo resolver la ruta del archivo. Prueba a moverlo a otra carpeta y abrirlo de nuevo."

        return "Posibles motivos: archivo corrupto, PDF no valido, contrasena, permisos insuficientes o bloqueo por otra aplicacion."
    }

    function saveActiveDocumentAsRotated(target) {
        if (!hasActiveDocument)
            return

        var doc = documentModel.get(activeDocumentIndex)
        if (pdfDocument.saveRotatedCopy(doc.path, target, doc.pageRotationsJson || "[]")) {
            saveMessage = "Guardado: " + fileNameFromPath(target)
        } else {
            saveMessage = ""
        }
    }

    function refreshActiveDocumentFromDisk() {
        if (!hasActiveDocument)
            return false

        var index = activeDocumentIndex
        var path = documentModel.get(index).path
        var page = activePageIndex
        var zoom = viewerZoom
        var layout = layoutMode
        var zoomModeValue = zoomMode

        if (!pdfDocument.load(path))
            return false

        var sources = loadedPageSources()
        var thumbnails = loadedThumbnailSources()
        documentModel.setProperty(index, "title", pdfDocument.title)
        documentModel.setProperty(index, "previewSource", pdfDocument.previewSource)
        documentModel.setProperty(index, "pageSourcesJson", JSON.stringify(sources))
        documentModel.setProperty(index, "thumbnailSourcesJson", JSON.stringify(thumbnails))
        documentModel.setProperty(index, "pageSizesJson", pdfDocument.pageSizesJson)
        documentModel.setProperty(index, "pageCount", pdfDocument.pageCount)
        documentModel.setProperty(index, "pageRotationsJson", "[]")
        documentModel.setProperty(index, "zoom", zoom)
        documentModel.setProperty(index, "layoutMode", layout)
        documentModel.setProperty(index, "zoomMode", zoomModeValue)
        documentModel.setProperty(index, "activePageIndex", Math.min(page, Math.max(0, pdfDocument.pageCount - 1)))
        setActiveDocument(index)
        jumpToPageRequested(activePageIndex)
        return true
    }

    function renderActivePage(pageIndex, scale) {
        if (!hasActiveDocument)
            return ""

        var doc = documentModel.get(activeDocumentIndex)
        if (pdfDocument.filePath !== doc.path && !pdfDocument.load(doc.path))
            return ""

        var rendered = pdfDocument.renderPage(pageIndex, scale)
        if (!rendered || rendered.length === 0)
            return ""

        var sources = activeDocumentPageSources()
        while (sources.length < doc.pageCount)
            sources.push("")
        sources[pageIndex] = rendered
        documentModel.setProperty(activeDocumentIndex, "pageSourcesJson", JSON.stringify(sources))
        return rendered
    }

    function renderActiveThumbnail(pageIndex) {
        if (!hasActiveDocument)
            return ""

        var doc = documentModel.get(activeDocumentIndex)
        if (pdfDocument.filePath !== doc.path && !pdfDocument.load(doc.path))
            return ""

        var rendered = pdfDocument.renderThumbnail(pageIndex)
        if (!rendered || rendered.length === 0)
            return ""

        var sources = activeDocumentThumbnailSources()
        while (sources.length < doc.pageCount)
            sources.push("")
        sources[pageIndex] = rendered
        documentModel.setProperty(activeDocumentIndex, "thumbnailSourcesJson", JSON.stringify(sources))
        return rendered
    }

    function toggleNavigationPanel() {
        navigationPanelVisible = !navigationPanelVisible
        syncActiveDocumentState()
    }

    function saveActiveDocumentRotated() {
        if (!hasActiveDocument)
            return

        var doc = documentModel.get(activeDocumentIndex)
        if (pdfDocument.saveRotatedCopy(doc.path, doc.path, doc.pageRotationsJson || "[]")) {
            saveMessage = "Guardado: " + doc.title
            refreshActiveDocumentFromDisk()
        } else {
            saveMessage = ""
        }
    }

    function zoomIn() {
        setZoomPercent(effectiveZoomPercent() + 10)
    }

    function zoomOut() {
        setZoomPercent(effectiveZoomPercent() - 10)
    }

    function setZoomPercent(percent) {
        var value = Number(percent)
        if (isNaN(value))
            return

        var percent = normalizedZoomPercent(value)
        viewerZoom = normalizedZoom((percent / 100) / (currentZoomBaseScale() * pdfViewer.renderScale))
        syncActiveDocumentState()
    }

    function setActivePage(index) {
        var page = Number(index)
        if (isNaN(page))
            return

        activePageIndex = Math.max(0, Math.min(page, activeDocumentPageCount() - 1))
        syncActiveDocumentState()
        Qt.callLater(function() {
            jumpToPageRequested(activePageIndex)
        })
    }

    function reportActivePage(index) {
        var page = Number(index)
        if (isNaN(page))
            return

        activePageIndex = Math.max(0, Math.min(page, activeDocumentPageCount() - 1))
        syncActiveDocumentState()
    }

    function goToFirstPage() {
        setActivePage(0)
    }

    function goToPreviousPage() {
        setActivePage(activePageIndex - 1)
    }

    function goToNextPage() {
        setActivePage(activePageIndex + 1)
    }

    function goToLastPage() {
        setActivePage(activeDocumentPageCount() - 1)
    }

    function setLayoutMode(mode) {
        if (mode !== "single" && mode !== "continuous" && mode !== "twoPage" && mode !== "twoPageContinuous")
            return

        layoutMode = mode
        syncActiveDocumentState()
        jumpToPageRequested(activePageIndex)
    }

    function setZoomMode(mode) {
        if (mode !== "fitWidth" && mode !== "fitPage" && mode !== "fitHeight" && mode !== "actualSize")
            return

        zoomMode = mode
        viewerZoom = 1.0
        syncActiveDocumentState()
    }

    function layoutModeIndex() {
        if (layoutMode === "single")
            return 0
        if (layoutMode === "twoPage")
            return 2
        if (layoutMode === "twoPageContinuous")
            return 3
        return 1
    }

    function zoomModeIndex() {
        if (zoomMode === "fitWidth")
            return 0
        if (zoomMode === "fitHeight")
            return 2
        if (zoomMode === "actualSize")
            return 3
        return 1
    }

    function rotateCurrentPage(delta) {
        if (!hasActiveDocument)
            return

        var doc = documentModel.get(activeDocumentIndex)
        var rotations = []
        try {
            rotations = JSON.parse(doc.pageRotationsJson || "[]")
        } catch(e) {
            rotations = []
        }

        while (rotations.length < doc.pageCount)
            rotations.push(0)

        var page = Math.max(0, Math.min(activePageIndex, doc.pageCount - 1))
        rotations[page] = (rotations[page] + delta + 360) % 360
        documentModel.setProperty(activeDocumentIndex, "pageRotationsJson", JSON.stringify(rotations))
        renderActivePage(page, pdfViewer ? pdfViewer.renderScale : 4.0)
        renderActiveThumbnail(page)
        saveMessage = ""
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: Theme.surface

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1
                color: Theme.border
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 10

                Button {
                    id: homeToolbarButton
                    visible: documentModel.count > 0
                    text: "⌂"
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 34
                    onClicked: window.setActiveDocument(-1)
                    ToolTip.visible: hovered
                    ToolTip.text: "Inicio"

                    contentItem: Text {
                        text: homeToolbarButton.text
                        color: Theme.text
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    background: Rectangle {
                        color: homeToolbarButton.down ? Theme.tabActive
                              : homeToolbarButton.hovered ? Theme.hover
                              : Theme.surfaceAlt
                        border.color: homeToolbarButton.activeFocus ? Theme.accent : Theme.border
                        border.width: homeToolbarButton.activeFocus ? 2 : 1
                        radius: Theme.radius
                    }
                }

                Label {
                    text: window.hasActiveDocument ? window.activeDocumentTitle() : "PDFClowne"
                    color: Theme.text
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Button {
                    id: navigationPanelButton
                    text: "▦"
                    visible: window.hasActiveDocument
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 34
                    onClicked: window.toggleNavigationPanel()
                    ToolTip.visible: hovered
                    ToolTip.text: window.navigationPanelVisible ? "Ocultar miniaturas" : "Mostrar miniaturas"

                    contentItem: Text {
                        text: navigationPanelButton.text
                        color: Theme.text
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: navigationPanelButton.down ? Theme.tabActive
                              : navigationPanelButton.hovered ? Theme.hover
                              : window.navigationPanelVisible ? Theme.tabActive
                              : Theme.surfaceAlt
                        border.color: navigationPanelButton.activeFocus ? Theme.accent : Theme.border
                        border.width: navigationPanelButton.activeFocus ? 2 : 1
                        radius: Theme.radius
                    }
                }

                Button {
                    id: themeButton
                    text: Theme.modeIcon
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 34
                    onClicked: Theme.cycleMode()
                    ToolTip.visible: hovered
                    ToolTip.text: "Cambiar tema: " + Theme.modeName

                    contentItem: Text {
                        text: themeButton.text
                        color: Theme.text
                        font.pixelSize: 18
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    background: Rectangle {
                        color: themeButton.down ? Theme.tabActive
                              : themeButton.hovered ? Theme.hover
                              : Theme.surfaceAlt
                        border.color: themeButton.activeFocus ? Theme.accent : Theme.border
                        border.width: themeButton.activeFocus ? 2 : 1
                        radius: Theme.radius
                    }
                }

                Button {
                    id: defaultPdfButton
                    visible: Qt.platform.os === "windows"
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 34
                    onClicked: desktopIntegration.openDefaultAppsSettings()
                    ToolTip.visible: hovered
                    ToolTip.text: "Elegir PDFClowne como visor PDF predeterminado"

                    contentItem: Canvas {
                        id: defaultPdfIcon
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        property color strokeColor: Theme.text
                        property color markColor: Theme.accent

                        onStrokeColorChanged: requestPaint()
                        onMarkColorChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.lineCap = "round"
                            ctx.lineJoin = "round"
                            ctx.lineWidth = 1.8
                            ctx.strokeStyle = strokeColor

                            ctx.beginPath()
                            ctx.moveTo(6, 2)
                            ctx.lineTo(13, 2)
                            ctx.lineTo(18, 7)
                            ctx.lineTo(18, 20)
                            ctx.lineTo(5, 20)
                            ctx.lineTo(5, 2)
                            ctx.closePath()
                            ctx.stroke()

                            ctx.beginPath()
                            ctx.moveTo(13, 2)
                            ctx.lineTo(13, 7)
                            ctx.lineTo(18, 7)
                            ctx.stroke()

                            ctx.strokeStyle = markColor
                            ctx.lineWidth = 2.2
                            ctx.beginPath()
                            ctx.moveTo(8, 13)
                            ctx.lineTo(11, 16)
                            ctx.lineTo(16, 10)
                            ctx.stroke()
                        }
                    }

                    background: Rectangle {
                        color: defaultPdfButton.down ? Theme.tabActive
                              : defaultPdfButton.hovered ? Theme.hover
                              : Theme.surfaceAlt
                        border.color: defaultPdfButton.activeFocus ? Theme.accent : Theme.border
                        border.width: defaultPdfButton.activeFocus ? 2 : 1
                        radius: Theme.radius
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            visible: documentModel.count > 0
            color: Theme.surface

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1
                color: Theme.border
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                    topMargin: 4
                    bottomMargin: 0
                }
                spacing: 4

                Repeater {
                    model: documentModel

                    Rectangle {
                        id: documentTab
                        required property int index
                        required property string title

                        Layout.preferredWidth: Math.min(240, Math.max(150, tabTitle.implicitWidth + 48))
                        Layout.fillHeight: true
                        color: window.activeDocumentIndex === index ? Theme.background : Theme.surfaceAlt
                        border.color: window.activeDocumentIndex === index ? Theme.accent : Theme.border
                        border.width: window.activeDocumentIndex === index ? 2 : 1
                        radius: Theme.radius

                        RowLayout {
                            anchors {
                                fill: parent
                                leftMargin: 10
                                rightMargin: 6
                            }
                            spacing: 6

                            Text {
                                id: tabTitle
                                text: documentTab.title
                                color: Theme.text
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                verticalAlignment: Text.AlignVCenter
                            }

                            Button {
                                id: closeTabButton
                                text: "×"
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                onClicked: {
                                    window.setActiveDocument(documentTab.index)
                                    window.closeActiveDocument()
                                }
                                ToolTip.visible: hovered
                                ToolTip.text: "Cerrar"

                                contentItem: Text {
                                    text: closeTabButton.text
                                    color: Theme.secondaryText
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    color: closeTabButton.hovered ? Theme.hover : "transparent"
                                    radius: Theme.radius
                                }
                            }
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: window.setActiveDocument(documentTab.index)
                        }
                    }
                }

                Button {
                    id: newTabButton
                    text: "+"
                    Layout.preferredWidth: 34
                    Layout.fillHeight: true
                    onClicked: fileDialog.open()
                    ToolTip.visible: hovered
                    ToolTip.text: "Abrir PDF"

                    contentItem: Text {
                        text: newTabButton.text
                        color: Theme.text
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: newTabButton.down ? Theme.tabActive
                              : newTabButton.hovered ? Theme.hover
                              : Theme.surfaceAlt
                        border.color: newTabButton.activeFocus ? Theme.accent : Theme.border
                        border.width: newTabButton.activeFocus ? 2 : 1
                        radius: Theme.radius
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 88
            visible: window.hasActiveDocument
            color: Theme.background

            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1
                color: Theme.border
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    color: Theme.surface

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 12
                        }
                        spacing: 4

                        Rectangle {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 28
                            Layout.alignment: Qt.AlignBottom
                            color: Theme.background
                            border.color: Theme.border
                            radius: Theme.radius

                            Text {
                                anchors.centerIn: parent
                                text: "◉"
                                color: Theme.text
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.background

                    RowLayout {
                        anchors {
                            left: parent.left
                            top: parent.top
                            bottom: parent.bottom
                            leftMargin: 12
                            topMargin: 8
                            bottomMargin: 8
                        }
                        spacing: 8

                        Button {
                            id: zoomOutButton
                            text: "-"
                            enabled: window.effectiveZoomPercent() > 10
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 30
                            onClicked: window.zoomOut()
                            ToolTip.visible: hovered
                            ToolTip.text: "Reducir zoom"

                            contentItem: Text {
                                text: zoomOutButton.text
                                color: zoomOutButton.enabled ? Theme.text : Theme.secondaryText
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                color: zoomOutButton.down ? Theme.tabActive
                                      : zoomOutButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: zoomOutButton.activeFocus ? Theme.accent : Theme.border
                                border.width: zoomOutButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                                opacity: zoomOutButton.enabled ? 1.0 : 0.55
                            }
                        }

                        Label {
                            text: window.effectiveZoomPercent() + "%"
                            color: Theme.text
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            Layout.preferredWidth: 44
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Button {
                            id: zoomInButton
                            text: "+"
                            enabled: window.effectiveZoomPercent() < window.maximumZoomPercent
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 30
                            onClicked: window.zoomIn()
                            ToolTip.visible: hovered
                            ToolTip.text: "Aumentar zoom"

                            contentItem: Text {
                                text: zoomInButton.text
                                color: zoomInButton.enabled ? Theme.text : Theme.secondaryText
                                font.pixelSize: 18
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                color: zoomInButton.down ? Theme.tabActive
                                      : zoomInButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: zoomInButton.activeFocus ? Theme.accent : Theme.border
                                border.width: zoomInButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                                opacity: zoomInButton.enabled ? 1.0 : 0.55
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            color: Theme.border
                        }

                        Button {
                            id: rotateLeftButton
                            text: "↺"
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 30
                            onClicked: window.rotateCurrentPage(-90)
                            ToolTip.visible: hovered
                            ToolTip.text: "Rotar a la izquierda"

                            contentItem: Text {
                                text: rotateLeftButton.text
                                color: Theme.text
                                font.pixelSize: 17
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                color: rotateLeftButton.down ? Theme.tabActive
                                      : rotateLeftButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: rotateLeftButton.activeFocus ? Theme.accent : Theme.border
                                border.width: rotateLeftButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                            }
                        }

                        Button {
                            id: rotateRightButton
                            text: "↻"
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 30
                            onClicked: window.rotateCurrentPage(90)
                            ToolTip.visible: hovered
                            ToolTip.text: "Rotar a la derecha"

                            contentItem: Text {
                                text: rotateRightButton.text
                                color: Theme.text
                                font.pixelSize: 17
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                color: rotateRightButton.down ? Theme.tabActive
                                      : rotateRightButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: rotateRightButton.activeFocus ? Theme.accent : Theme.border
                                border.width: rotateRightButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            color: Theme.border
                        }

                        Button {
                            id: saveRotatedButton
                            text: ""
                            enabled: window.activeDocumentHasRotations()
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 30
                            onClicked: window.saveActiveDocumentRotated()
                            ToolTip.visible: hovered
                            ToolTip.text: "Guardar cambios en el PDF original"

                            contentItem: Item {
                                opacity: saveRotatedButton.enabled ? 1.0 : 0.55

                                Rectangle {
                                    width: 15
                                    height: 16
                                    radius: 2
                                    anchors.centerIn: parent
                                    color: "transparent"
                                    border.color: saveRotatedButton.enabled ? Theme.text : Theme.secondaryText
                                    border.width: 1.5

                                    Rectangle {
                                        width: 8
                                        height: 4
                                        anchors {
                                            top: parent.top
                                            right: parent.right
                                            topMargin: 2
                                            rightMargin: 2
                                        }
                                        color: saveRotatedButton.enabled ? Theme.text : Theme.secondaryText
                                    }

                                    Rectangle {
                                        width: 9
                                        height: 5
                                        anchors {
                                            horizontalCenter: parent.horizontalCenter
                                            bottom: parent.bottom
                                            bottomMargin: 2
                                        }
                                        radius: 1
                                        color: "transparent"
                                        border.color: saveRotatedButton.enabled ? Theme.text : Theme.secondaryText
                                        border.width: 1
                                    }
                                }
                            }

                            background: Rectangle {
                                color: saveRotatedButton.down ? Theme.tabActive
                                      : saveRotatedButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: saveRotatedButton.activeFocus ? Theme.accent : Theme.border
                                border.width: saveRotatedButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                                opacity: saveRotatedButton.enabled ? 1.0 : 0.55
                            }
                        }

                        Button {
                            id: saveRotatedAsButton
                            text: ""
                            enabled: window.activeDocumentHasRotations()
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 30
                            onClicked: saveRotatedDialog.open()
                            ToolTip.visible: hovered
                            ToolTip.text: "Guardar copia rotada"

                            contentItem: Item {
                                opacity: saveRotatedAsButton.enabled ? 1.0 : 0.55

                                Rectangle {
                                    id: saveAsFloppyIcon
                                    width: 15
                                    height: 16
                                    radius: 2
                                    anchors {
                                        verticalCenter: parent.verticalCenter
                                        horizontalCenter: parent.horizontalCenter
                                        horizontalCenterOffset: -3
                                    }
                                    color: "transparent"
                                    border.color: saveRotatedAsButton.enabled ? Theme.text : Theme.secondaryText
                                    border.width: 1.5

                                    Rectangle {
                                        width: 8
                                        height: 4
                                        anchors {
                                            top: parent.top
                                            right: parent.right
                                            topMargin: 2
                                            rightMargin: 2
                                        }
                                        color: saveRotatedAsButton.enabled ? Theme.text : Theme.secondaryText
                                    }

                                    Rectangle {
                                        width: 9
                                        height: 5
                                        anchors {
                                            horizontalCenter: parent.horizontalCenter
                                            bottom: parent.bottom
                                            bottomMargin: 2
                                        }
                                        radius: 1
                                        color: "transparent"
                                        border.color: saveRotatedAsButton.enabled ? Theme.text : Theme.secondaryText
                                        border.width: 1
                                    }
                                }

                                Rectangle {
                                    width: 8
                                    height: 2
                                    radius: 1
                                    anchors {
                                        left: saveAsFloppyIcon.right
                                        verticalCenter: saveAsFloppyIcon.verticalCenter
                                        leftMargin: 2
                                    }
                                    color: saveRotatedAsButton.enabled ? Theme.text : Theme.secondaryText
                                }

                                Rectangle {
                                    width: 2
                                    height: 8
                                    radius: 1
                                    anchors {
                                        left: saveAsFloppyIcon.right
                                        verticalCenter: saveAsFloppyIcon.verticalCenter
                                        leftMargin: 5
                                    }
                                    color: saveRotatedAsButton.enabled ? Theme.text : Theme.secondaryText
                                }
                            }

                            background: Rectangle {
                                color: saveRotatedAsButton.down ? Theme.tabActive
                                      : saveRotatedAsButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: saveRotatedAsButton.activeFocus ? Theme.accent : Theme.border
                                border.width: saveRotatedAsButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                                opacity: saveRotatedAsButton.enabled ? 1.0 : 0.55
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            PdfViewer {
                id: pdfViewer
                anchors.fill: parent
                visible: window.hasActiveDocument
                pageSources: window.activeDocumentPageSources()
                thumbnailSources: window.activeDocumentThumbnailSources()
                pageCount: window.activeDocumentPageCount()
                pageSizesJson: window.activeDocumentPageSizesJson()
                pageRotations: window.activeDocumentPageRotations()
                currentPageIndex: window.activePageIndex
                zoom: window.viewerZoom
                layoutMode: window.layoutMode
                zoomMode: window.zoomMode
                sidePanelVisible: window.navigationPanelVisible
                zoomInAction: window.zoomIn
                zoomOutAction: window.zoomOut
                renderPageAction: window.renderActivePage
                renderThumbnailAction: window.renderActiveThumbnail
                currentPageChangedAction: window.reportActivePage
            }

            Connections {
                target: window
                function onJumpToPageRequested(index) {
                    pdfViewer.navigateToPage(index)
                }
            }

            Item {
                anchors.fill: parent
                visible: !window.hasActiveDocument

                Rectangle {
                    anchors.fill: parent
                    color: Theme.background
                }

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 36
                    }
                    spacing: 22

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(136, Math.min(220, parent.height * 0.28))

                        Column {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 10

                            Row {
                                width: parent.width
                                spacing: 14

                                Image {
                                    source: "qrc:/PdfClowne.svg"
                                    width: 44
                                    height: 44
                                    fillMode: Image.PreserveAspectFit
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Label {
                                    text: "PDFClowne"
                                    color: Theme.text
                                    font.pixelSize: 34
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    width: parent.width - 58
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Label {
                                visible: pdfDocument.errorMessage.length > 0
                                text: pdfDocument.errorMessage
                                color: Theme.danger
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                width: Math.min(parent.width, 620)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Button {
                            id: homeOpenButton
                            text: "Open PDF"
                            Layout.preferredWidth: 132
                            Layout.preferredHeight: 40
                            onClicked: fileDialog.open()

                            contentItem: Text {
                                text: homeOpenButton.text
                                color: Theme.accentText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                radius: Theme.radius
                                color: homeOpenButton.down ? Qt.darker(Theme.accent, 1.15)
                                      : homeOpenButton.hovered ? Qt.lighter(Theme.accent, 1.08)
                                      : Theme.accent
                                border.color: homeOpenButton.activeFocus ? Theme.text : "transparent"
                                border.width: homeOpenButton.activeFocus ? 2 : 0
                            }
                        }

                        Label {
                            text: "Ctrl+O"
                            color: Theme.secondaryText
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 180
                        color: Theme.surface
                        radius: Theme.radius
                        border.color: Theme.border

                        ColumnLayout {
                            anchors {
                                fill: parent
                                margins: 16
                            }
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true

                                Label {
                                    text: "Historial"
                                    color: Theme.text
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                }

                                Button {
                                    visible: recentModel.count > 0
                                    text: "Clear"
                                    flat: true
                                    onClicked: window.clearRecentFiles()
                                }
                            }

                            Label {
                                visible: recentModel.count === 0
                                text: "No recent files yet."
                                color: Theme.secondaryText
                                font.pixelSize: 13
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                            }

                            ListView {
                                visible: recentModel.count > 0
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 6
                                model: recentModel

                                delegate: Button {
                                    id: recentButton
                                    required property string path
                                    required property string name

                                    width: ListView.view.width
                                    height: 52
                                    onClicked: window.openPdf(recentButton.path)

                                    contentItem: RowLayout {
                                        spacing: 12

                                        Rectangle {
                                            Layout.preferredWidth: 30
                                            Layout.preferredHeight: 30
                                            radius: Theme.radius
                                            color: Theme.isDark ? "#353552" : "#E5F4F2"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "PDF"
                                                color: Theme.accent
                                                font.pixelSize: 9
                                                font.weight: Font.Bold
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                text: recentButton.name
                                                color: Theme.text
                                                font.pixelSize: 13
                                                font.weight: Font.Medium
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: recentButton.path
                                                color: Theme.secondaryText
                                                font.pixelSize: 11
                                                elide: Text.ElideMiddle
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Button {
                                            id: removeRecentButton
                                            text: "X"
                                            Layout.preferredWidth: 28
                                            Layout.preferredHeight: 28
                                            onClicked: window.removeRecentFile(recentButton.path)
                                            ToolTip.visible: hovered
                                            ToolTip.text: "Quitar del historial"

                                            contentItem: Text {
                                                text: removeRecentButton.text
                                                color: Theme.secondaryText
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            background: Rectangle {
                                                color: removeRecentButton.down ? Theme.tabActive
                                                      : removeRecentButton.hovered ? Theme.hover
                                                      : "transparent"
                                                radius: Theme.radius
                                                border.color: removeRecentButton.activeFocus ? Theme.accent : "transparent"
                                                border.width: removeRecentButton.activeFocus ? 2 : 0
                                            }
                                        }
                                    }

                                    background: Rectangle {
                                        color: recentButton.down ? Theme.tabActive
                                              : recentButton.hovered ? Theme.hover
                                              : Theme.surfaceAlt
                                        radius: Theme.radius
                                        border.color: recentButton.activeFocus ? Theme.accent : Theme.border
                                        border.width: recentButton.activeFocus ? 2 : 1
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: statusBar
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            visible: window.hasActiveDocument
            color: Theme.surface
            readonly property color controlFill: Theme.isDark ? "#1B1D31" : "#FCFCFE"
            readonly property color controlHover: Theme.isDark ? "#252945" : "#EFF3FB"
            readonly property color controlActive: Theme.isDark ? "#2F3557" : "#E3EAF8"
            readonly property color controlBorder: Theme.isDark ? "#41496F" : "#CCD5E8"

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                color: Theme.border
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 8

                Label {
                    text: pdfDocument.errorMessage.length > 0 ? pdfDocument.errorMessage
                          : saveMessage.length > 0 ? saveMessage
                          : "PDF"
                    color: pdfDocument.errorMessage.length > 0 ? Theme.danger : Theme.secondaryText
                    font.pixelSize: 11
                    Layout.preferredWidth: 260
                    elide: Text.ElideRight
                }

                Item { Layout.fillWidth: true }

                Button {
                    id: firstPageButton
                    text: "|‹"
                    enabled: window.activePageIndex > 0
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 24
                    onClicked: window.goToFirstPage()
                    ToolTip.visible: hovered
                    ToolTip.text: "Primera pagina"
                    contentItem: Text {
                        text: firstPageButton.text
                        color: firstPageButton.enabled ? Theme.text : Theme.secondaryText
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: firstPageButton.down ? statusBar.controlActive
                              : firstPageButton.hovered ? statusBar.controlHover
                              : statusBar.controlFill
                        radius: Theme.radius
                        border.color: firstPageButton.activeFocus ? Theme.accent : statusBar.controlBorder
                        border.width: firstPageButton.activeFocus ? 2 : 1
                        opacity: firstPageButton.enabled ? 1.0 : 0.55
                    }
                }

                Button {
                    id: previousPageButton
                    text: "‹"
                    enabled: window.activePageIndex > 0
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 24
                    onClicked: window.goToPreviousPage()
                    ToolTip.visible: hovered
                    ToolTip.text: "Pagina anterior"
                    contentItem: Text {
                        text: previousPageButton.text
                        color: previousPageButton.enabled ? Theme.text : Theme.secondaryText
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: previousPageButton.down ? statusBar.controlActive
                              : previousPageButton.hovered ? statusBar.controlHover
                              : statusBar.controlFill
                        radius: Theme.radius
                        border.color: previousPageButton.activeFocus ? Theme.accent : statusBar.controlBorder
                        border.width: previousPageButton.activeFocus ? 2 : 1
                        opacity: previousPageButton.enabled ? 1.0 : 0.55
                    }
                }

                TextField {
                    id: pageField
                    text: String(window.activePageIndex + 1)
                    validator: IntValidator { bottom: 1; top: Math.max(1, window.activeDocumentPageCount()) }
                    selectByMouse: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 24
                    color: Theme.text
                    font.pixelSize: 11
                    onAccepted: window.setActivePage(parseInt(text) - 1)
                    onEditingFinished: window.setActivePage(parseInt(text) - 1)
                    background: Rectangle {
                        color: statusBar.controlFill
                        border.color: pageField.activeFocus ? Theme.accent : statusBar.controlBorder
                        border.width: pageField.activeFocus ? 2 : 1
                        radius: Theme.radius
                    }
                }

                Label {
                    text: "/ " + window.activeDocumentPageCount()
                    color: Theme.secondaryText
                    font.pixelSize: 11
                    Layout.preferredWidth: 42
                }

                Button {
                    id: nextPageButton
                    text: "›"
                    enabled: window.activePageIndex < window.activeDocumentPageCount() - 1
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 24
                    onClicked: window.goToNextPage()
                    ToolTip.visible: hovered
                    ToolTip.text: "Pagina siguiente"
                    contentItem: Text {
                        text: nextPageButton.text
                        color: nextPageButton.enabled ? Theme.text : Theme.secondaryText
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: nextPageButton.down ? statusBar.controlActive
                              : nextPageButton.hovered ? statusBar.controlHover
                              : statusBar.controlFill
                        radius: Theme.radius
                        border.color: nextPageButton.activeFocus ? Theme.accent : statusBar.controlBorder
                        border.width: nextPageButton.activeFocus ? 2 : 1
                        opacity: nextPageButton.enabled ? 1.0 : 0.55
                    }
                }

                Button {
                    id: lastPageButton
                    text: "›|"
                    enabled: window.activePageIndex < window.activeDocumentPageCount() - 1
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 24
                    onClicked: window.goToLastPage()
                    ToolTip.visible: hovered
                    ToolTip.text: "Ultima pagina"
                    contentItem: Text {
                        text: lastPageButton.text
                        color: lastPageButton.enabled ? Theme.text : Theme.secondaryText
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: lastPageButton.down ? statusBar.controlActive
                              : lastPageButton.hovered ? statusBar.controlHover
                              : statusBar.controlFill
                        radius: Theme.radius
                        border.color: lastPageButton.activeFocus ? Theme.accent : statusBar.controlBorder
                        border.width: lastPageButton.activeFocus ? 2 : 1
                        opacity: lastPageButton.enabled ? 1.0 : 0.55
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 20
                    color: Theme.border
                }

                ComboBox {
                    id: layoutModeBox
                    model: [
                        { text: "Pagina", value: "single" },
                        { text: "Continuo", value: "continuous" },
                        { text: "2 paginas", value: "twoPage" },
                        { text: "2 pag. continuo", value: "twoPageContinuous" }
                    ]
                    textRole: "text"
                    valueRole: "value"
                    currentIndex: window.layoutModeIndex()
                    Layout.preferredWidth: 136
                    Layout.preferredHeight: 24
                    font.pixelSize: 11
                    onActivated: window.setLayoutMode(currentValue)
                    ToolTip.visible: hovered
                    ToolTip.text: "Distribucion de paginas"

                    contentItem: Text {
                        leftPadding: 10
                        rightPadding: 26
                        text: layoutModeBox.displayText
                        color: Theme.text
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    indicator: Text {
                        x: layoutModeBox.width - width - 9
                        y: (layoutModeBox.height - height) / 2
                        text: "⌄"
                        color: Theme.secondaryText
                        font.pixelSize: 14
                    }

                    background: Rectangle {
                        color: layoutModeBox.pressed ? statusBar.controlActive
                              : layoutModeBox.hovered ? statusBar.controlHover
                              : statusBar.controlFill
                        border.color: layoutModeBox.activeFocus ? Theme.accent : statusBar.controlBorder
                        border.width: layoutModeBox.activeFocus ? 2 : 1
                        radius: Theme.radius
                    }

                    delegate: ItemDelegate {
                        id: layoutModeDelegate
                        required property int index
                        required property var modelData

                        width: layoutModeBox.width
                        height: 28
                        text: modelData.text
                        highlighted: layoutModeBox.highlightedIndex === index

                        contentItem: Text {
                            text: layoutModeDelegate.text
                            color: Theme.text
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: Theme.radius
                            color: layoutModeDelegate.highlighted ? statusBar.controlActive
                                  : layoutModeDelegate.hovered ? statusBar.controlHover
                                  : "transparent"
                            border.color: layoutModeDelegate.index === layoutModeBox.currentIndex ? Theme.accent : "transparent"
                        }
                    }

                    popup: Popup {
                        y: layoutModeBox.height + 4
                        width: layoutModeBox.width
                        height: Math.min(120, layoutModeList.contentHeight + 8)
                        padding: 4
                        topInset: -2
                        bottomInset: -4

                        contentItem: ListView {
                            id: layoutModeList
                            clip: true
                            implicitHeight: contentHeight
                            model: layoutModeBox.popup.visible ? layoutModeBox.delegateModel : null
                            currentIndex: layoutModeBox.highlightedIndex
                        }

                        background: Rectangle {
                            color: Theme.surface
                            border.color: statusBar.controlBorder
                            border.width: 1
                            radius: Theme.radiusLg
                        }
                    }
                }

                ComboBox {
                    id: zoomModeBox
                    model: [
                        { text: "Ancho", value: "fitWidth" },
                        { text: "Pagina", value: "fitPage" },
                        { text: "Alto", value: "fitHeight" },
                        { text: "100%", value: "actualSize" }
                    ]
                    textRole: "text"
                    valueRole: "value"
                    currentIndex: window.zoomModeIndex()
                    Layout.preferredWidth: 92
                    Layout.preferredHeight: 24
                    font.pixelSize: 11
                    onActivated: window.setZoomMode(currentValue)
                    ToolTip.visible: hovered
                    ToolTip.text: "Ajuste de zoom"

                    contentItem: Text {
                        leftPadding: 10
                        rightPadding: 24
                        text: zoomModeBox.displayText
                        color: Theme.text
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    indicator: Text {
                        x: zoomModeBox.width - width - 9
                        y: (zoomModeBox.height - height) / 2
                        text: "⌄"
                        color: Theme.secondaryText
                        font.pixelSize: 14
                    }

                    background: Rectangle {
                        color: zoomModeBox.pressed ? statusBar.controlActive
                              : zoomModeBox.hovered ? statusBar.controlHover
                              : statusBar.controlFill
                        border.color: zoomModeBox.activeFocus ? Theme.accent : statusBar.controlBorder
                        border.width: zoomModeBox.activeFocus ? 2 : 1
                        radius: Theme.radius
                    }

                    delegate: ItemDelegate {
                        id: zoomModeDelegate
                        required property int index
                        required property var modelData

                        width: zoomModeBox.width
                        height: 28
                        text: modelData.text
                        highlighted: zoomModeBox.highlightedIndex === index

                        contentItem: Text {
                            text: zoomModeDelegate.text
                            color: Theme.text
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: Theme.radius
                            color: zoomModeDelegate.highlighted ? statusBar.controlActive
                                  : zoomModeDelegate.hovered ? statusBar.controlHover
                                  : "transparent"
                            border.color: zoomModeDelegate.index === zoomModeBox.currentIndex ? Theme.accent : "transparent"
                        }
                    }

                    popup: Popup {
                        y: zoomModeBox.height + 4
                        width: zoomModeBox.width
                        height: Math.min(120, zoomModeList.contentHeight + 8)
                        padding: 4
                        topInset: -2
                        bottomInset: -4

                        contentItem: ListView {
                            id: zoomModeList
                            clip: true
                            implicitHeight: contentHeight
                            model: zoomModeBox.popup.visible ? zoomModeBox.delegateModel : null
                            currentIndex: zoomModeBox.highlightedIndex
                        }

                        background: Rectangle {
                            color: Theme.surface
                            border.color: statusBar.controlBorder
                            border.width: 1
                            radius: Theme.radiusLg
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 20
                    color: Theme.border
                }

                ComboBox {
                    id: zoomPresetBox
                    model: window.zoomPresetOptions
                    textRole: "text"
                    valueRole: "value"
                    currentIndex: window.zoomPresetIndex()
                    Layout.preferredWidth: 84
                    Layout.preferredHeight: 24
                    font.pixelSize: 11
                    onActivated: {
                        if (currentValue > 0)
                            window.setZoomPercent(currentValue)
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: "Presets de zoom"

                    contentItem: Text {
                        leftPadding: 10
                        rightPadding: 24
                        text: zoomPresetBox.displayText
                        color: Theme.text
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    indicator: Text {
                        x: zoomPresetBox.width - width - 9
                        y: (zoomPresetBox.height - height) / 2
                        text: "⌄"
                        color: Theme.secondaryText
                        font.pixelSize: 14
                    }

                    background: Rectangle {
                        color: zoomPresetBox.pressed ? statusBar.controlActive
                              : zoomPresetBox.hovered ? statusBar.controlHover
                              : statusBar.controlFill
                        border.color: zoomPresetBox.activeFocus ? Theme.accent : statusBar.controlBorder
                        border.width: zoomPresetBox.activeFocus ? 2 : 1
                        radius: Theme.radius
                    }

                    delegate: ItemDelegate {
                        id: zoomPresetDelegate
                        required property int index
                        required property var modelData

                        width: zoomPresetBox.width
                        height: 28
                        text: modelData.text
                        highlighted: zoomPresetBox.highlightedIndex === index
                        enabled: modelData.value > 0

                        contentItem: Text {
                            text: zoomPresetDelegate.text
                            color: zoomPresetDelegate.enabled ? Theme.text : Theme.secondaryText
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: Theme.radius
                            color: zoomPresetDelegate.highlighted ? statusBar.controlActive
                                  : zoomPresetDelegate.hovered ? statusBar.controlHover
                                  : "transparent"
                            border.color: zoomPresetDelegate.index === zoomPresetBox.currentIndex ? Theme.accent : "transparent"
                        }
                    }

                    popup: Popup {
                        y: zoomPresetBox.height + 4
                        width: zoomPresetBox.width
                        height: Math.min(220, zoomPresetList.contentHeight + 8)
                        padding: 4
                        topInset: -2
                        bottomInset: -4

                        contentItem: ListView {
                            id: zoomPresetList
                            clip: true
                            implicitHeight: contentHeight
                            model: zoomPresetBox.popup.visible ? zoomPresetBox.delegateModel : null
                            currentIndex: zoomPresetBox.highlightedIndex
                        }

                        background: Rectangle {
                            color: Theme.surface
                            border.color: statusBar.controlBorder
                            border.width: 1
                            radius: Theme.radiusLg
                        }
                    }
                }

                TextField {
                    id: zoomField
                    text: window.effectiveZoomPercent() + "%"
                    selectByMouse: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.preferredWidth: 54
                    Layout.preferredHeight: 24
                    color: Theme.text
                    font.pixelSize: 11
                    onAccepted: window.setZoomPercent(text.replace("%", ""))
                    onEditingFinished: window.setZoomPercent(text.replace("%", ""))
                    background: Rectangle {
                        color: statusBar.controlFill
                        border.color: zoomField.activeFocus ? Theme.accent : statusBar.controlBorder
                        border.width: zoomField.activeFocus ? 2 : 1
                        radius: Theme.radius
                    }
                }

                Button {
                    id: statusZoomOutButton
                    text: "−"
                    enabled: window.effectiveZoomPercent() > 10
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    onClicked: window.zoomOut()
                    ToolTip.visible: hovered
                    ToolTip.text: "Reducir zoom"
                    contentItem: Text {
                        text: statusZoomOutButton.text
                        color: statusZoomOutButton.enabled ? Theme.text : Theme.secondaryText
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: statusZoomOutButton.down ? statusBar.controlActive
                              : statusZoomOutButton.hovered ? statusBar.controlHover
                              : statusBar.controlFill
                        radius: Theme.radius
                        border.color: statusZoomOutButton.activeFocus ? Theme.accent : statusBar.controlBorder
                        border.width: statusZoomOutButton.activeFocus ? 2 : 1
                        opacity: statusZoomOutButton.enabled ? 1.0 : 0.55
                    }
                }

                Slider {
                    id: zoomSlider
                    from: 10
                    to: window.maximumZoomPercent
                    stepSize: 5
                    value: window.effectiveZoomPercent()
                    Layout.preferredWidth: 132
                    Layout.preferredHeight: 24
                    onMoved: window.setZoomPercent(value)
                    ToolTip.visible: hovered
                    ToolTip.text: "Zoom"

                    background: Rectangle {
                        x: zoomSlider.leftPadding
                        y: zoomSlider.topPadding + zoomSlider.availableHeight / 2 - height / 2
                        width: zoomSlider.availableWidth
                        height: 4
                        radius: 2
                        color: statusBar.controlBorder

                        Rectangle {
                            width: zoomSlider.visualPosition * parent.width
                            height: parent.height
                            radius: parent.radius
                            color: Theme.accent
                        }
                    }

                    handle: Rectangle {
                        x: zoomSlider.leftPadding + zoomSlider.visualPosition * (zoomSlider.availableWidth - width)
                        y: zoomSlider.topPadding + zoomSlider.availableHeight / 2 - height / 2
                        width: zoomSlider.pressed ? 18 : 16
                        height: width
                        radius: width / 2
                        color: zoomSlider.pressed ? Theme.accent : Theme.surface
                        border.color: Theme.accent
                        border.width: 2
                    }
                }

                Button {
                    id: statusZoomInButton
                    text: "+"
                    enabled: window.effectiveZoomPercent() < window.maximumZoomPercent
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    onClicked: window.zoomIn()
                    ToolTip.visible: hovered
                    ToolTip.text: "Aumentar zoom"
                    contentItem: Text {
                        text: statusZoomInButton.text
                        color: statusZoomInButton.enabled ? Theme.text : Theme.secondaryText
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: statusZoomInButton.down ? statusBar.controlActive
                              : statusZoomInButton.hovered ? statusZoomInButton.enabled ? statusBar.controlHover : statusBar.controlFill
                              : statusBar.controlFill
                        radius: Theme.radius
                        border.color: statusZoomInButton.activeFocus ? Theme.accent : statusBar.controlBorder
                        border.width: statusZoomInButton.activeFocus ? 2 : 1
                        opacity: statusZoomInButton.enabled ? 1.0 : 0.55
                    }
                }
            }
        }
    }
}
