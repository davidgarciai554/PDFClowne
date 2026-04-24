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
    property string viewMode: "fitPage"
    property int activePageIndex: 0
    property int activeDocumentIndex: -1
    property string saveMessage: ""
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

    Shortcut { sequence: "Ctrl+O"; onActivated: fileDialog.open() }
    Shortcut { sequence: "Ctrl+S"; enabled: window.activeDocumentHasRotations(); onActivated: window.saveActiveDocumentRotated() }
    Shortcut { sequence: "Ctrl+Shift+S"; enabled: window.activeDocumentHasRotations(); onActivated: saveRotatedDialog.open() }

    function fileNameFromPath(path) {
        var normalized = String(path || "").replace(/\\/g, "/")
        var index = normalized.lastIndexOf("/")
        return index >= 0 ? normalized.slice(index + 1) : normalized
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
        documentModel.setProperty(activeDocumentIndex, "viewMode", viewMode)
        documentModel.setProperty(activeDocumentIndex, "activePageIndex", activePageIndex)
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

    function setActiveDocument(index) {
        if (index < 0 || index >= documentModel.count) {
            activeDocumentIndex = -1
            viewerZoom = 1.0
            activePageIndex = 0
            return
        }

        activeDocumentIndex = index
        var doc = documentModel.get(index)
        viewerZoom = normalizedZoom(doc.zoom)
        viewMode = doc.viewMode || "fitPage"
        activePageIndex = doc.activePageIndex || 0
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

            documentModel.append({
                path: pdfDocument.filePath,
                title: pdfDocument.title,
                previewSource: pdfDocument.previewSource,
                pageSourcesJson: JSON.stringify(sources),
                pageCount: Math.max(sources.length, pdfDocument.pageCount),
                zoom: 1.0,
                viewMode: "fitPage",
                activePageIndex: 0,
                pageRotationsJson: "[]"
            })
            setActiveDocument(documentModel.count - 1)
            addRecentFile(pdfDocument.filePath, pdfDocument.title)
        }
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
        var mode = viewMode

        if (!pdfDocument.load(path))
            return false

        var sources = loadedPageSources()
        documentModel.setProperty(index, "title", pdfDocument.title)
        documentModel.setProperty(index, "previewSource", pdfDocument.previewSource)
        documentModel.setProperty(index, "pageSourcesJson", JSON.stringify(sources))
        documentModel.setProperty(index, "pageCount", Math.max(sources.length, pdfDocument.pageCount))
        documentModel.setProperty(index, "pageRotationsJson", "[]")
        documentModel.setProperty(index, "zoom", zoom)
        documentModel.setProperty(index, "viewMode", mode)
        documentModel.setProperty(index, "activePageIndex", Math.min(page, Math.max(0, sources.length - 1)))
        setActiveDocument(index)
        jumpToPageRequested(activePageIndex)
        return true
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
        jumpToPageRequested(activePageIndex)
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

    function setViewMode(mode) {
        if (mode !== "fitWidth" && mode !== "fitPage")
            return

        viewMode = mode
        viewerZoom = 1.0
        syncActiveDocumentState()
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
                    id: themeButton
                    text: Theme.modeIcon
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 34
                    onClicked: Theme.cycleMode()
                    ToolTip.visible: hovered
                    ToolTip.text: Theme.modeName

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
                pageRotations: window.activeDocumentPageRotations()
                currentPageIndex: window.activePageIndex
                zoom: window.viewerZoom
                viewMode: window.viewMode
                zoomInAction: window.zoomIn
                zoomOutAction: window.zoomOut
                currentPageChangedAction: window.reportActivePage
            }

            Connections {
                target: window
                function onJumpToPageRequested(index) {
                    pdfViewer.jumpToPage(index)
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

                        Button {
                            id: homeDefaultAppButton
                            visible: Qt.platform.os === "windows"
                            text: "Default PDF App"
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 40
                            onClicked: desktopIntegration.openDefaultAppsSettings()

                            contentItem: Text {
                                text: homeDefaultAppButton.text
                                color: Theme.text
                                font.pixelSize: 13
                                font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            background: Rectangle {
                                radius: Theme.radius
                                color: homeDefaultAppButton.down ? Theme.tabActive
                                      : homeDefaultAppButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: homeDefaultAppButton.activeFocus ? Theme.accent : Theme.border
                                border.width: homeDefaultAppButton.activeFocus ? 2 : 1
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
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            visible: window.hasActiveDocument
            color: Theme.surface

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
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: firstPageButton.hovered ? Theme.hover : "transparent"
                        radius: Theme.radius
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
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: previousPageButton.hovered ? Theme.hover : "transparent"
                        radius: Theme.radius
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
                        color: Theme.background
                        border.color: pageField.activeFocus ? Theme.accent : Theme.border
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
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: nextPageButton.hovered ? Theme.hover : "transparent"
                        radius: Theme.radius
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
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: lastPageButton.hovered ? Theme.hover : "transparent"
                        radius: Theme.radius
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 20
                    color: Theme.border
                }

                ComboBox {
                    id: viewModeBox
                    model: [
                        { text: "Ajustar ancho", value: "fitWidth" },
                        { text: "Hoja completa", value: "fitPage" }
                    ]
                    textRole: "text"
                    valueRole: "value"
                    currentIndex: window.viewMode === "fitPage" ? 1 : 0
                    Layout.preferredWidth: 132
                    Layout.preferredHeight: 24
                    font.pixelSize: 11
                    onActivated: window.setViewMode(currentValue)
                    ToolTip.visible: hovered
                    ToolTip.text: "Modo de vista"

                    contentItem: Text {
                        leftPadding: 10
                        rightPadding: 26
                        text: viewModeBox.displayText
                        color: Theme.text
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    indicator: Text {
                        x: viewModeBox.width - width - 9
                        y: (viewModeBox.height - height) / 2
                        text: "⌄"
                        color: Theme.secondaryText
                        font.pixelSize: 14
                    }

                    background: Rectangle {
                        color: viewModeBox.pressed ? Theme.tabActive
                              : viewModeBox.hovered ? Theme.hover
                              : Theme.background
                        border.color: viewModeBox.activeFocus ? Theme.accent : Theme.border
                        border.width: viewModeBox.activeFocus ? 2 : 1
                        radius: Theme.radius
                    }

                    delegate: ItemDelegate {
                        id: viewModeDelegate
                        required property int index
                        required property var modelData

                        width: viewModeBox.width
                        height: 28
                        text: modelData.text
                        highlighted: viewModeBox.highlightedIndex === index

                        contentItem: Text {
                            text: viewModeDelegate.text
                            color: Theme.text
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: Theme.radius
                            color: viewModeDelegate.highlighted ? Theme.tabActive
                                  : viewModeDelegate.hovered ? Theme.hover
                                  : "transparent"
                            border.color: viewModeDelegate.index === viewModeBox.currentIndex ? Theme.accent : "transparent"
                        }
                    }

                    popup: Popup {
                        y: viewModeBox.height + 4
                        width: viewModeBox.width
                        height: Math.min(72, viewModeList.contentHeight + 8)
                        padding: 4

                        contentItem: ListView {
                            id: viewModeList
                            clip: true
                            implicitHeight: contentHeight
                            model: viewModeBox.popup.visible ? viewModeBox.delegateModel : null
                            currentIndex: viewModeBox.highlightedIndex
                        }

                        background: Rectangle {
                            color: Theme.surface
                            border.color: Theme.border
                            radius: Theme.radius
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 20
                    color: Theme.border
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
                        color: Theme.background
                        border.color: zoomField.activeFocus ? Theme.accent : Theme.border
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
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: statusZoomOutButton.hovered ? Theme.hover : "transparent"
                        radius: Theme.radius
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
                        color: Theme.border

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
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: statusZoomInButton.hovered ? Theme.hover : "transparent"
                        radius: Theme.radius
                    }
                }
            }
        }
    }
}
