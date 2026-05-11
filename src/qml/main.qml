pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.settings
import "ShortcutCatalog.js" as ShortcutCatalog
import PDFClowne
import PDFClowne.Backend
import PDFClowne.Editing

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
    property string navigationSidePanelMode: "thumbnails"
    property bool pageSnapEnabled: false
    property int pageSpacing: 18
    property int activePageIndex: 0
    property int activeDocumentIndex: -1
    property var editingController: null
    property string editingControllerFilePath: ""
    property int editingControllerExtractedPage: -1
    property string saveMessage: ""
    property bool pendingEditSaveIncremental: false
    property string pendingEditingSaveTarget: ""
    property var pendingEditingSaveState: null
    property bool readingFullscreenEnabled: false
    property bool presentationModeEnabled: false
    property bool handToolEnabled: false
    property bool reflowModeEnabled: false
    property bool reflowLoading: false
    property string readingPanelText: ""
    property bool readingPanelTextLoading: false
    property string topToolbarMenu: "view"
    // "view" | "edit" | "forms" | "sign" | "annotate" | "ocr"
    property string viewMode: "view"
    onTopToolbarMenuChanged: {
        if (topToolbarMenu === "edit")      viewMode = "edit"
        else if (viewMode === "edit")       viewMode = "view"
    }
    onViewModeChanged: {
        if (viewMode === "forms" && pdfViewer && pdfViewer.pdfDocument
                && pdfViewer.pdfDocument.isLoaded)
            formController.loadForms(pdfViewer.pdfDocument.filePath)
        else if (viewMode !== "forms")
            formController.clear()

        if (viewMode === "edit")
            Qt.callLater(function() { requestEditExtractionForActivePage() })
        else if (editingController)
            editingController.selectBlock("")
    }
    property bool searchOverlayVisible: false
    property bool openInProgress: false
    property string pendingOpenSource: ""
    property string pendingOpenFileName: ""
    property string pendingProtectedSource: ""
    property var pendingSessionDocumentState: null
    property string activeEditTool: "text"
    property string editFontFamily: "Helv"
    property int editFontSize: 12
    property string editTextColor: "#1C1C2E"
    property string editHighlightColor: "#FFE45A"
    property bool editBoldEnabled: false
    property bool editItalicEnabled: false
    property bool editUnderlineEnabled: false
    property bool syncingPdfTextStyle: false
    property int editAnnotationSerial: 0
    readonly property var editTextColorOptions: ["#1C1C2E", "#C83040", "#1F7A4D", "#2463B6", "#7A3E9D"]
    readonly property var editHighlightColorOptions: ["#FFE45A", "#9BFFD0", "#8ED4FF", "#FFB3C7", "#D8B4FE"]
    property var sessionRestoreQueue: []
    property int sessionRestoreTargetIndex: -1
    property bool sessionRestoreInProgress: false
    property bool allowImmediateWindowClose: false
    property var saveInProgressPaths: ({})
    readonly property var shortcutSections: ShortcutCatalog.sections
    readonly property int pageRenderWindowRadius: 8
    readonly property int pageRenderPruneDelayMs: 240
    readonly property int largeJumpThresholdPages: 5
    readonly property real largeJumpPreviewScale: 1.0
    readonly property int heavyPdfPageThreshold: 120
    readonly property real heavyPdfSizeThresholdBytes: 25 * 1024 * 1024
    readonly property real progressivePreviewScale: 0.7
    property var pendingSearchFocusResult: null
    property int searchRequestSerial: 0
    property int renderSessionSerial: 0
    readonly property bool immersiveModeActive: readingFullscreenEnabled || presentationModeEnabled
    property real presentationRestoreZoom: 1.0
    property string presentationRestoreLayoutMode: "continuous"
    property string presentationRestoreZoomMode: "fitPage"
    property bool presentationRestoreNavigationPanelVisible: true
    property string presentationRestoreSidePanelMode: "thumbnails"
    property bool presentationRestoreHandToolEnabled: false
    property bool presentationRestoreReflowModeEnabled: false
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
    signal internalLinkRequested(string uri, int pageIndex)

    onVisibleChanged: if (visible) Theme.applyColorScheme()
    onClosing: function(close) {
        if (allowImmediateWindowClose) {
            allowImmediateWindowClose = false
            close.accepted = true
            return
        }

        if (hasActiveDocument) {
            close.accepted = false
            requestCloseDocumentAt(activeDocumentIndex)
            return
        }
    }
    onActiveDocumentIndexChanged: {
        if (typeof pageSearchField !== "undefined")
            pageSearchField.text = activeDocumentSearchQuery()
        editingControllerExtractedPage = -1
        editingControllerFilePath = ""
        if (editingController)
            editingController.closeDocument()
        if (viewMode === "edit")
            Qt.callLater(function() { requestEditExtractionForActivePage() })
        Qt.callLater(function() { refreshReadingPanelText(false) })
    }
    onActivePageIndexChanged: {
        renderWindowMaintenanceTimer.restart()
        if (viewMode === "edit")
            Qt.callLater(function() { requestEditExtractionForActivePage() })
        if (!reflowModeEnabled)
            Qt.callLater(function() { refreshReadingPanelText(false) })
    }
    onReflowModeEnabledChanged: Qt.callLater(function() { refreshReadingPanelText(false) })
    onHasActiveDocumentChanged: {
        if (!hasActiveDocument) {
            renderWindowMaintenanceTimer.stop()
            readingPanelText = ""
            readingPanelTextLoading = false
            topToolbarMenu = "view"
            activeEditTool = "text"
            searchOverlayVisible = false
            pendingSearchFocusResult = null
            editingControllerExtractedPage = -1
            editingControllerFilePath = ""
            if (editingController)
                editingController.closeDocument()
        }
    }

    PdfDocument {
        id: pdfDocument
    }

    PdfEditSession {
        id: pdfEditSession
        onJournalJsonChanged: pdfDocument.pendingEditJournalJson = journalJson
    }

    PdfAnnotationController {
        id: pdfAnnotationController
    }

    OcrService {
        id: ocrService
    }

    PdfFormController {
        id: formController
        onLoadFailed: function(error) { console.warn("PdfFormController:", error) }
    }

    Connections {
        target: window.editingController
        ignoreUnknownSignals: true

        function onBusyChanged() {
            if (window.viewMode === "edit"
                    && window.editingController
                    && !window.editingController.busy)
                Qt.callLater(function() { window.requestEditExtractionForActivePage() })
        }

        function onExtractionError(message) {
            window.saveMessage = message
        }

        function onEditWarning(message) {
            window.saveMessage = message
        }

        function onOcrSuggested(message) {
            window.saveMessage = message
        }

        function onSaveCompleted(outputPath) {
            window.completeEditingControllerSave(outputPath)
        }

        function onSaveError(message) {
            window.pendingEditingSaveTarget = ""
            window.pendingEditingSaveState = null
            window.saveMessage = message
        }
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

    Settings {
        id: sessionRestoreSettings
        category: "SessionRestore"
        property string sessionJson: "{\"activeDocumentIndex\":-1,\"documents\":[]}"
    }

    Timer {
        id: searchDebounceTimer
        interval: 180
        repeat: false
        onTriggered: window.performSearchRequest()
    }

    Timer {
        id: openPdfTimer
        interval: 0
        repeat: false
        onTriggered: window.finishOpenPdf()
    }

    Timer {
        id: renderWindowMaintenanceTimer
        interval: window.pageRenderPruneDelayMs
        repeat: false
        onTriggered: window.maintainActiveDocumentRenderWindow(true)
    }

    ListModel {
        id: recentModel
    }

    ListModel {
        id: documentModel
    }

    Component.onCompleted: {
        loadRecentFiles()
        restorePreviousSession()
    }

    FileDialog {
        id: fileDialog
        title: "Open PDF"
        nameFilters: ["PDF Files (*.pdf)", "All Files (*)"]
        onAccepted: window.openPdf(selectedFile.toString())
    }

    FileDialog {
        id: saveRotatedDialog
        title: "Guardar como PDF editado"
        fileMode: FileDialog.SaveFile
        nameFilters: ["PDF Files (*.pdf)", "All Files (*)"]
        onAccepted: window.saveActiveDocumentAsRotated(selectedFile.toString())
    }

    Popup {
        id: pendingEditsDialog
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        width: Math.min(440, window.width - 48)
        x: Math.round((window.width - width) / 2)
        y: Math.round((window.height - height) / 2)
        padding: 0

        property string closeMode: ""
        property int documentIndex: -1

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
                    color: Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: "?"
                        color: Theme.accentText
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: pendingEditsDialog.closeMode === "application"
                          ? "Hay cambios pendientes"
                          : "Guardar cambios pendientes"
                    color: Theme.text
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 18
                Layout.rightMargin: 18
                Layout.topMargin: 16
                Layout.bottomMargin: 18
                spacing: 14

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Theme.secondaryText
                    text: pendingEditsDialog.closeMode === "application"
                          ? "Hay PDFs con cambios sin guardar. Puedes guardar antes de salir, salir sin guardar o cancelar."
                          : "Este PDF tiene cambios pendientes. Puedes guardarlos antes de cerrar la pestana, salir sin guardar o cancelar."
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Item { Layout.fillWidth: true }

                    Button {
                        id: cancelPendingEditsButton
                        text: "Cancelar"
                        onClicked: pendingEditsDialog.close()

                        contentItem: Text {
                            text: cancelPendingEditsButton.text
                            color: Theme.text
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: cancelPendingEditsButton.down ? Theme.tabActive
                                  : cancelPendingEditsButton.hovered ? Theme.hover
                                  : Theme.surfaceAlt
                            radius: Theme.radius
                            border.color: cancelPendingEditsButton.activeFocus ? Theme.accent : Theme.border
                            border.width: cancelPendingEditsButton.activeFocus ? 2 : 1
                        }
                    }

                    Button {
                        id: discardPendingEditsButton
                        text: "Salir sin guardar"
                        onClicked: {
                            var closeMode = pendingEditsDialog.closeMode
                            var closeIndex = pendingEditsDialog.documentIndex
                            pendingEditsDialog.close()
                            if (closeMode === "application") {
                                allowImmediateWindowClose = true
                                Qt.quit()
                            } else {
                                performCloseDocumentAt(closeIndex)
                            }
                        }

                        contentItem: Text {
                            text: discardPendingEditsButton.text
                            color: Theme.text
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: discardPendingEditsButton.down ? Qt.darker(Theme.surfaceAlt, 1.08)
                                  : discardPendingEditsButton.hovered ? Theme.hover
                                  : Theme.surface
                            radius: Theme.radius
                            border.color: discardPendingEditsButton.activeFocus ? Theme.accent : Theme.border
                            border.width: discardPendingEditsButton.activeFocus ? 2 : 1
                        }
                    }

                    Button {
                        id: savePendingEditsButton
                        text: "Guardar"
                        onClicked: {
                            var closeMode = pendingEditsDialog.closeMode
                            var closeIndex = pendingEditsDialog.documentIndex
                            pendingEditsDialog.close()
                            if (closeMode === "application") {
                                var allSaved = true
                                for (var i = 0; i < documentModel.count; ++i) {
                                    if (documentHasPendingChanges(i) && !saveDocumentChanges(i, documentModel.get(i).path, false)) {
                                        allSaved = false
                                        break
                                    }
                                }
                                if (allSaved) {
                                    allowImmediateWindowClose = true
                                    Qt.quit()
                                }
                            } else if (saveDocumentChanges(closeIndex,
                                                            documentModel.get(closeIndex).path,
                                                            false)) {
                                performCloseDocumentAt(closeIndex)
                            }
                        }

                        contentItem: Text {
                            text: savePendingEditsButton.text
                            color: Theme.accentText
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: savePendingEditsButton.down ? Qt.darker(Theme.accent, 1.12)
                                  : savePendingEditsButton.hovered ? Qt.lighter(Theme.accent, 1.08)
                                  : Theme.accent
                            radius: Theme.radius
                            border.color: savePendingEditsButton.activeFocus ? Theme.text : Theme.accent
                            border.width: savePendingEditsButton.activeFocus ? 2 : 1
                        }
                    }
                }
            }
        }
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

    Popup {
        id: passwordDialog
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        width: Math.min(420, window.width - 48)
        x: Math.round((window.width - width) / 2)
        y: Math.round((window.height - height) / 2)
        padding: 0

        property string source: ""
        property string fileName: ""
        property string passwordValue: ""
        property string inlineError: ""

        Overlay.modal: Rectangle {
            color: Theme.isDark ? "#AA0F1020" : "#660F1020"
        }

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radius
            border.color: Theme.border
            border.width: 1
        }

        onOpened: {
            passwordField.forceActiveFocus()
            passwordField.selectAll()
        }
        onClosed: window.handlePasswordDialogClosed()

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
                    color: Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: "•"
                        color: Theme.accentText
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                    }
                }

                Text {
                    text: "Introducir contrasena"
                    color: Theme.text
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                }

                Button {
                    id: closePasswordIconButton
                    text: "X"
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    onClicked: passwordDialog.close()
                    ToolTip.visible: hovered
                    ToolTip.text: "Cerrar"

                    contentItem: Text {
                        text: closePasswordIconButton.text
                        color: Theme.secondaryText
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: closePasswordIconButton.down ? Theme.tabActive
                              : closePasswordIconButton.hovered ? Theme.hover
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
                    text: "Este PDF esta protegido. Introduce la contrasena para desbloquearlo."
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
                        text: passwordDialog.fileName
                        color: Theme.text
                        font.pixelSize: 12
                        elide: Text.ElideMiddle
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                TextField {
                    id: passwordField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    text: passwordDialog.passwordValue
                    echoMode: TextInput.Password
                    placeholderText: "Contrasena"
                    color: Theme.text
                    selectByMouse: true
                    onTextChanged: passwordDialog.passwordValue = text
                    onAccepted: window.openProtectedPdf(passwordDialog.source)

                    background: Rectangle {
                        color: Theme.surfaceAlt
                        radius: Theme.radius
                        border.color: passwordField.activeFocus ? Theme.accent : Theme.border
                        border.width: passwordField.activeFocus ? 2 : 1
                    }
                }

                Text {
                    visible: passwordDialog.inlineError.length > 0
                    text: passwordDialog.inlineError
                    color: Theme.danger
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6

                    Item { Layout.fillWidth: true }

                    Button {
                        id: cancelPasswordButton
                        text: "Cancelar"
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 34
                        onClicked: passwordDialog.close()

                        contentItem: Text {
                            text: cancelPasswordButton.text
                            color: Theme.text
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: cancelPasswordButton.down ? Theme.tabActive
                                  : cancelPasswordButton.hovered ? Theme.hover
                                  : Theme.surfaceAlt
                            radius: Theme.radius
                            border.color: Theme.border
                        }
                    }

                    Button {
                        id: unlockPasswordButton
                        text: "Abrir"
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 34
                        onClicked: window.openProtectedPdf(passwordDialog.source)

                        contentItem: Text {
                            text: unlockPasswordButton.text
                            color: Theme.accentText
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            color: unlockPasswordButton.down ? Qt.darker(Theme.accent, 1.12)
                                  : unlockPasswordButton.hovered ? Qt.lighter(Theme.accent, 1.08)
                                  : Theme.accent
                            radius: Theme.radius
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: shortcutsPopup
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(560, window.width - 32)
        height: Math.min(520, window.height - 32)
        x: Math.max(16, Math.round(window.width - width - 12))
        y: Math.max(16, Math.round(themeButton.y + themeButton.height + 8))
        padding: 0

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusLg
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

                Text {
                    text: "Atajos y gestos"
                    color: Theme.text
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                }

                Button {
                    id: closeShortcutsButton
                    text: "X"
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    onClicked: shortcutsPopup.close()
                    ToolTip.visible: hovered
                    ToolTip.text: "Cerrar"

                    contentItem: Text {
                        text: closeShortcutsButton.text
                        color: Theme.secondaryText
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: closeShortcutsButton.down ? Theme.tabActive
                              : closeShortcutsButton.hovered ? Theme.hover
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

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                padding: 0

                Column {
                    width: shortcutsPopup.width
                    spacing: 14
                    padding: 16

                    Repeater {
                        model: window.shortcutSections

                        Column {
                            required property var modelData
                            width: parent.width - 32
                            spacing: 8

                            Text {
                                text: modelData.title
                                color: Theme.text
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            Repeater {
                                model: modelData.entries

                                Rectangle {
                                    required property var modelData
                                    width: parent.width
                                    radius: Theme.radius
                                    color: Theme.surfaceAlt
                                    border.color: Theme.border
                                    border.width: 1
                                    implicitHeight: shortcutRow.implicitHeight + 16

                                    RowLayout {
                                        id: shortcutRow
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 10

                                        Rectangle {
                                            Layout.alignment: Qt.AlignTop
                                            Layout.preferredWidth: 110
                                            radius: Theme.radius
                                            color: Theme.background
                                            border.color: Theme.border
                                            border.width: 1
                                            implicitHeight: triggerLabel.implicitHeight + 10

                                            Text {
                                                id: triggerLabel
                                                anchors.centerIn: parent
                                                text: modelData.trigger
                                                color: Theme.text
                                                font.pixelSize: 11
                                                font.weight: Font.DemiBold
                                                horizontalAlignment: Text.AlignHCenter
                                                wrapMode: Text.Wrap
                                                width: parent.width - 12
                                            }
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                width: parent.width
                                                text: modelData.description
                                                color: Theme.text
                                                font.pixelSize: 12
                                                wrapMode: Text.Wrap
                                            }

                                            Text {
                                                width: parent.width
                                                text: modelData.availability
                                                color: Theme.secondaryText
                                                font.pixelSize: 11
                                                wrapMode: Text.Wrap
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Shortcut { sequence: "Ctrl+O"; onActivated: fileDialog.open() }
    Shortcut { sequence: "Ctrl+S"; enabled: window.activeDocumentHasPendingChanges(); onActivated: window.saveActiveDocumentRotated() }
    Shortcut { sequence: "Ctrl+Shift+S"; enabled: window.activeDocumentHasPendingChanges(); onActivated: saveRotatedDialog.open() }
    Shortcut { sequence: "Ctrl+R"; enabled: window.hasActiveDocument; onActivated: window.refreshActiveDocumentFromDisk() }
    Shortcut { sequence: "Ctrl+H"; onActivated: window.openHomeScreen() }
    Shortcut { sequence: "Ctrl+1"; enabled: window.hasActiveDocument; onActivated: window.setLayoutMode("single") }
    Shortcut { sequence: "Ctrl+2"; enabled: window.hasActiveDocument; onActivated: window.setLayoutMode("continuous") }
    Shortcut { sequence: "Ctrl+3"; enabled: window.hasActiveDocument; onActivated: window.setLayoutMode("twoPage") }
    Shortcut { sequence: "Ctrl+4"; enabled: window.hasActiveDocument; onActivated: window.setLayoutMode("twoPageContinuous") }
    Shortcut { sequence: "Ctrl+F"; enabled: window.hasActiveDocument; onActivated: window.focusSearchField() }
    Shortcut { sequence: "F3"; enabled: window.hasActiveDocument && window.activeDocumentSearchResultCount() > 0; onActivated: window.goToNextSearchResult() }
    Shortcut { sequence: "Shift+F3"; enabled: window.hasActiveDocument && window.activeDocumentSearchResultCount() > 0; onActivated: window.goToPreviousSearchResult() }
    Shortcut { sequence: "Ctrl+L"; enabled: window.hasActiveDocument; onActivated: window.toggleSearchPanel() }
    Shortcut { sequence: "Ctrl+Shift+F"; enabled: window.hasActiveDocument && window.activeDocumentSearchQuery().trim().length > 0; onActivated: window.clearSearch() }
    Shortcut { sequence: "F11"; enabled: window.hasActiveDocument; onActivated: window.toggleReadingFullscreen() }
    Shortcut { sequence: "F5"; enabled: window.hasActiveDocument; onActivated: window.togglePresentationMode() }
    Shortcut { sequence: "H"; enabled: window.hasActiveDocument && !window.reflowModeEnabled; onActivated: window.setHandToolEnabled(!window.handToolEnabled) }
    Shortcut { sequence: "Ctrl+Shift+R"; enabled: window.hasActiveDocument; onActivated: window.toggleReflowMode() }
    Shortcut { sequence: "Alt+Left"; enabled: window.hasActiveDocument && window.activeDocumentHistoryBack().length > 0; onActivated: window.goBackInDocument() }
    Shortcut { sequence: "Alt+Right"; enabled: window.hasActiveDocument && window.activeDocumentHistoryForward().length > 0; onActivated: window.goForwardInDocument() }
    Shortcut { sequence: "F6"; onActivated: window.cyclePaneFocus(1) }
    Shortcut { sequence: "Shift+F6"; onActivated: window.cyclePaneFocus(-1) }
    Shortcut { sequence: StandardKey.Copy; context: Qt.ApplicationShortcut; enabled: window.hasActiveDocument && pdfViewer && String(pdfViewer.selectedText || "").trim().length > 0; onActivated: window.copySelectedText() }
    Shortcut { sequence: "Ctrl+C"; context: Qt.ApplicationShortcut; enabled: window.hasActiveDocument && pdfViewer && String(pdfViewer.selectedText || "").trim().length > 0; onActivated: window.copySelectedText() }
    Shortcut { sequence: "Ctrl+Shift+C"; enabled: window.hasActiveDocument; onActivated: window.copyVisibleText() }
    Shortcut { sequence: "Ctrl+Z"; enabled: (!pdfViewer || !pdfViewer.inlineTextEditingActive) && window.activeDocumentCanUndoEdits(); onActivated: window.undoActiveDocumentEdit() }
    Shortcut { sequence: "Ctrl+Y"; enabled: (!pdfViewer || !pdfViewer.inlineTextEditingActive) && window.activeDocumentCanRedoEdits(); onActivated: window.redoActiveDocumentEdit() }
    Shortcut { sequence: "Escape"; enabled: window.readingFullscreenEnabled || window.presentationModeEnabled; onActivated: window.exitImmersiveModes() }
    Shortcut { sequence: "Right"; enabled: window.hasActiveDocument && (window.readingFullscreenEnabled || window.presentationModeEnabled); onActivated: window.goToNextPage() }
    Shortcut { sequence: "Left"; enabled: window.hasActiveDocument && (window.readingFullscreenEnabled || window.presentationModeEnabled); onActivated: window.goToPreviousPage() }
    Shortcut { sequence: "Space"; enabled: window.hasActiveDocument && (window.readingFullscreenEnabled || window.presentationModeEnabled); onActivated: window.goToNextPage() }
    Shortcut { sequence: "Backspace"; enabled: window.hasActiveDocument && (window.readingFullscreenEnabled || window.presentationModeEnabled); onActivated: window.goToPreviousPage() }

    function fileNameFromPath(path) {
        var normalized = String(path || "").replace(/\\/g, "/")
        var index = normalized.lastIndexOf("/")
        return index >= 0 ? normalized.slice(index + 1) : normalized
    }

    function pathToFileUrl(path) {
        var normalized = String(path || "").replace(/\\/g, "/")
        if (normalized.length === 0)
            return ""
        if (normalized.indexOf("file:/") === 0)
            return normalized

        var drivePrefix = ""
        if (/^[A-Za-z]:\//.test(normalized)) {
            drivePrefix = normalized.slice(0, 2)
            normalized = normalized.slice(2)
        }

        var parts = normalized.split("/")
        for (var i = 0; i < parts.length; ++i) {
            if (parts[i].length > 0)
                parts[i] = encodeURIComponent(parts[i])
        }

        return drivePrefix.length > 0
             ? "file:///" + drivePrefix + parts.join("/")
             : "file:///" + parts.join("/")
    }

    function isSameFilePath(left, right) {
        var normalizedLeft = pathToFileUrl(left)
        var normalizedRight = pathToFileUrl(right)
        return normalizedLeft.length > 0 && normalizedLeft === normalizedRight
    }

    function localPathFromUrl(value) {
        var text = String(value || "")
        if (text.indexOf("file:///") === 0) {
            var local = text.substring(8)
            if (/^[A-Za-z]:/.test(local))
                return decodeURIComponent(local)
            return decodeURIComponent("/" + local)
        }
        if (text.indexOf("file://") === 0)
            return decodeURIComponent(text.substring(7))
        return text
    }

    function ensureEditingController() {
        if (editingController)
            return editingController

        try {
            editingController = Qt.createQmlObject(
                        'import PDFClowne.Editing; PdfEditSessionController {}',
                        window,
                        "PdfEditSessionController")
        } catch (e) {
            console.warn("PdfEditSessionController unavailable:", e)
            editingController = null
        }

        return editingController
    }

    function requestEditExtractionForActivePage() {
        if (viewMode !== "edit" || !hasActiveDocument || !pdfDocument.isLoaded)
            return

        var controller = ensureEditingController()
        if (!controller)
            return

        var filePath = String(pdfDocument.filePath || "")
        if (filePath.length === 0)
            return

        if (editingControllerFilePath !== filePath || !controller.ready) {
            editingControllerExtractedPage = -1
            if (!controller.loadDocumentWithPassword(pdfDocument.filePath, pdfDocument.password || ""))
                return
            editingControllerFilePath = filePath
        }

        var sourcePage = sourcePageForActivePage(activePageIndex)
        if (sourcePage < 0)
            return
        if (editingControllerExtractedPage === sourcePage)
            return
        if (controller.busy)
            return

        editingControllerExtractedPage = sourcePage
        controller.extractBlocksForPage(sourcePage)
    }

    function isDocumentSaveInProgress(path) {
        var key = pathToFileUrl(path)
        return key.length > 0 && !!saveInProgressPaths[key]
    }

    function setDocumentSaveInProgress(path, inProgress) {
        var key = pathToFileUrl(path)
        if (key.length === 0)
            return

        var next = {}
        for (var existing in saveInProgressPaths)
            next[existing] = saveInProgressPaths[existing]

        if (inProgress)
            next[key] = true
        else
            delete next[key]

        saveInProgressPaths = next
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

    function readSavedSession() {
        try {
            var parsed = JSON.parse(sessionRestoreSettings.sessionJson || "{\"activeDocumentIndex\":-1,\"documents\":[]}")
            if (!parsed || typeof parsed !== "object")
                return { activeDocumentIndex: -1, documents: [] }
            if (!Array.isArray(parsed.documents))
                parsed.documents = []
            return parsed
        } catch(e) {
            return { activeDocumentIndex: -1, documents: [] }
        }
    }

    function writeSavedSession(sessionState) {
        var normalized = sessionState && typeof sessionState === "object" ? sessionState : {}
        if (!Array.isArray(normalized.documents))
            normalized.documents = []
        if (!isFinite(Number(normalized.activeDocumentIndex)))
            normalized.activeDocumentIndex = -1
        sessionRestoreSettings.sessionJson = JSON.stringify(normalized)
    }

    function parseHistoryEntries(value) {
        try {
            var parsed = JSON.parse(String(value || "[]"))
            return Array.isArray(parsed) ? parsed : []
        } catch(e) {
            return []
        }
    }

    function serializeDocumentSessionState(doc) {
        var pageSpacing = Number(doc.pageSpacing)
        if (!isFinite(pageSpacing))
            pageSpacing = 18

        return {
            path: String(doc.path || ""),
            title: String(doc.title || ""),
            zoom: normalizedZoom(doc.zoom),
            layoutMode: doc.layoutMode || "continuous",
            zoomMode: doc.zoomMode || "fitPage",
            navigationPanelVisible: doc.navigationPanelVisible === undefined ? true : !!doc.navigationPanelVisible,
            sidePanelMode: doc.sidePanelMode || "thumbnails",
            snapToPage: doc.snapToPage === undefined ? false : !!doc.snapToPage,
            pageSpacing: Math.max(0, Math.min(48, pageSpacing)),
            activePageIndex: Math.max(0, Number(doc.activePageIndex) || 0),
            searchQuery: String(doc.searchQuery || ""),
            historyBack: trimHistoryEntries(parseHistoryEntries(doc.historyBackJson)),
            historyForward: trimHistoryEntries(parseHistoryEntries(doc.historyForwardJson))
        }
    }

    function normalizedRestoredDocumentState(state, fallbackViewState) {
        var fallback = fallbackViewState || defaultDocumentViewState()
        var restored = state && typeof state === "object" ? state : {}
        var sidePanelMode = restored.sidePanelMode || "thumbnails"
        if (sidePanelMode !== "thumbnails" && sidePanelMode !== "outline" && sidePanelMode !== "search")
            sidePanelMode = "thumbnails"

        return {
            zoom: normalizedZoom(restored.zoom !== undefined ? restored.zoom : fallback.zoom),
            layoutMode: restored.layoutMode || fallback.layoutMode || "continuous",
            zoomMode: restored.zoomMode || fallback.zoomMode || "fitPage",
            navigationPanelVisible: restored.navigationPanelVisible === undefined ? true : !!restored.navigationPanelVisible,
            sidePanelMode: sidePanelMode,
            snapToPage: restored.snapToPage === undefined ? false : !!restored.snapToPage,
            pageSpacing: Math.max(0, Math.min(48, Number(restored.pageSpacing !== undefined ? restored.pageSpacing : 18))) || 18,
            activePageIndex: Math.max(0, Number(restored.activePageIndex) || 0),
            searchQuery: String(restored.searchQuery || ""),
            historyBack: trimHistoryEntries(Array.isArray(restored.historyBack) ? restored.historyBack : []),
            historyForward: trimHistoryEntries(Array.isArray(restored.historyForward) ? restored.historyForward : [])
        }
    }

    function saveCurrentSession(skipSync) {
        if (!skipSync && hasActiveDocument)
            syncActiveDocumentState(true)

        var documents = []
        for (var i = 0; i < documentModel.count; ++i)
            documents.push(serializeDocumentSessionState(documentModel.get(i)))

        writeSavedSession({
            activeDocumentIndex: documentModel.count > 0 && activeDocumentIndex >= 0
                ? Math.min(activeDocumentIndex, documentModel.count - 1)
                : -1,
            documents: documents
        })
    }

    function restorePreviousSession() {
        if (documentModel.count > 0 || sessionRestoreInProgress)
            return

        var sessionState = readSavedSession()
        if (!sessionState.documents || sessionState.documents.length === 0)
            return

        sessionRestoreQueue = sessionState.documents.slice()
        sessionRestoreTargetIndex = Number(sessionState.activeDocumentIndex)
        sessionRestoreInProgress = true
        restoreNextSessionDocument()
    }

    function restoreNextSessionDocument() {
        if (!sessionRestoreInProgress)
            return

        while (sessionRestoreQueue.length > 0) {
            var entry = sessionRestoreQueue.shift()
            if (!entry || String(entry.path || "").trim().length === 0)
                continue

            pendingSessionDocumentState = entry
            if (pdfDocument.load(entry.path)) {
                completeOpenedPdf(entry)
                return
            }

            if (pdfDocument.passwordRequired) {
                showPasswordDialog(entry.path, false)
                return
            }

            pendingSessionDocumentState = null
        }

        finishSessionRestore()
    }

    function finishSessionRestore() {
        sessionRestoreInProgress = false
        sessionRestoreQueue = []
        pendingSessionDocumentState = null

        if (documentModel.count <= 0) {
            sessionRestoreTargetIndex = -1
            saveCurrentSession(true)
            return
        }

        var targetIndex = Number(sessionRestoreTargetIndex)
        sessionRestoreTargetIndex = -1
        if (isFinite(targetIndex) && targetIndex >= 0) {
            setActiveDocument(Math.min(targetIndex, documentModel.count - 1))
            Qt.callLater(function() {
                if (hasActiveDocument)
                    jumpToPageRequested(activePageIndex)
            })
        } else {
            setActiveDocument(-1)
        }
        saveCurrentSession(true)
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

    function findDocumentIndexByPath(path) {
        var target = String(path || "")
        if (!target)
            return -1

        for (var i = 0; i < documentModel.count; ++i) {
            if (String(documentModel.get(i).path || "") === target)
                return i
        }

        return -1
    }

    function parseJsonArray(raw, fallback) {
        try {
            var parsed = JSON.parse(raw || JSON.stringify(fallback || []))
            return parsed && parsed.length !== undefined ? parsed : (fallback || [])
        } catch(e) {
            return fallback || []
        }
    }

    function parseJsonObject(raw, fallback) {
        try {
            var parsed = JSON.parse(raw || JSON.stringify(fallback || {}))
            return parsed && typeof parsed === "object" ? parsed : (fallback || {})
        } catch(e) {
            return fallback || {}
        }
    }

    function identityPageOrder(pageCount) {
        var order = []
        for (var page = 0; page < Math.max(0, Number(pageCount) || 0); ++page)
            order.push(page)
        return order
    }

    function normalizedDocumentPageOrder(doc) {
        if (!doc)
            return []

        var totalPages = Math.max(0, Number(doc.pageCount) || 0)
        var raw = parseJsonArray(doc.pageOrderJson || "[]", [])
        if (raw.length === 0)
            return identityPageOrder(totalPages)

        var normalized = []
        var seen = {}
        for (var i = 0; i < raw.length; ++i) {
            var page = Number(raw[i])
            if (!isFinite(page) || page < 0 || page >= totalPages || seen[page])
                continue
            seen[page] = true
            normalized.push(page)
        }

        return normalized
    }

    function sourcePageForDocumentIndex(doc, visiblePageIndex) {
        var order = normalizedDocumentPageOrder(doc)
        var target = Number(visiblePageIndex)
        if (!isFinite(target) || target < 0 || target >= order.length)
            return -1
        return Number(order[target])
    }

    function sourcePageForActivePage(visiblePageIndex) {
        if (!hasActiveDocument)
            return -1
        return sourcePageForDocumentIndex(documentModel.get(activeDocumentIndex), visiblePageIndex)
    }

    function visibleIndexForSourcePage(doc, sourcePageIndex) {
        var target = Number(sourcePageIndex)
        if (!isFinite(target) || !doc)
            return -1

        var order = normalizedDocumentPageOrder(doc)
        for (var i = 0; i < order.length; ++i) {
            if (Number(order[i]) === target)
                return i
        }

        return -1
    }

    function remapArrayByDocumentOrder(doc, sourceItems) {
        var order = normalizedDocumentPageOrder(doc)
        var remapped = []
        for (var i = 0; i < order.length; ++i) {
            var sourcePage = Number(order[i])
            remapped.push(sourcePage >= 0 && sourcePage < sourceItems.length ? sourceItems[sourcePage] : "")
        }
        return remapped
    }

    function activeDocumentPageCount() {
        if (!hasActiveDocument)
            return 0

        var doc = documentModel.get(activeDocumentIndex)
        return Math.max(0, normalizedDocumentPageOrder(doc).length)
    }

    function activeDocumentUsesProgressiveRendering() {
        if (!hasActiveDocument)
            return false

        var doc = documentModel.get(activeDocumentIndex)
        var fileSize = Number(doc.fileSizeBytes || 0)
        var pages = Number(doc.pageCount || 0)
        return fileSize >= heavyPdfSizeThresholdBytes || pages >= heavyPdfPageThreshold
    }

    function formatBytes(bytes) {
        var value = Number(bytes || 0)
        if (!isFinite(value) || value <= 0)
            return "0 B"
        if (value >= 1024 * 1024)
            return (value / (1024 * 1024)).toFixed(value >= 100 * 1024 * 1024 ? 0 : 1) + " MB"
        if (value >= 1024)
            return Math.round(value / 1024) + " KB"
        return Math.round(value) + " B"
    }

    function activeDocumentFirstPageVisibleMs() {
        return hasActiveDocument ? Number(documentModel.get(activeDocumentIndex).firstPageVisibleMs || -1) : -1
    }

    function activeDocumentRenderCacheBytes() {
        return hasActiveDocument ? Number(documentModel.get(activeDocumentIndex).renderCacheBytes || 0) : 0
    }

    function activeDocumentProcessMemoryBytes() {
        return hasActiveDocument ? Number(documentModel.get(activeDocumentIndex).processMemoryBytes || 0) : 0
    }

    function activeDocumentPeakProcessMemoryBytes() {
        return hasActiveDocument ? Number(documentModel.get(activeDocumentIndex).peakProcessMemoryBytes || 0) : 0
    }

    function activeDocumentPendingRenderCount() {
        return hasActiveDocument ? Number(documentModel.get(activeDocumentIndex).pendingRenderCount || 0) : 0
    }

    function activeDocumentHasRenderedCurrentPage() {
        if (!hasActiveDocument)
            return false

        var sources = activeDocumentPageSources()
        if (!sources || sources.length <= 0)
            return false

        var pageIndex = Math.max(0, Math.min(activePageIndex, sources.length - 1))
        return String(sources[pageIndex] || "").length > 0
    }

    function shouldShowDocumentLoadingOverlay() {
        if (openInProgress)
            return true
        if (!hasActiveDocument || reflowModeEnabled)
            return false
        if (pdfViewer && (pdfViewer.largeJumpMode || pdfViewer.pageTransitionActive))
            return true
        if (activeDocumentHasRenderedCurrentPage())
            return false
        return activeDocumentPageCount() > 0
    }

    function documentViewerOpacity() {
        if (!hasActiveDocument || reflowModeEnabled)
            return 1
        if (!shouldShowDocumentLoadingOverlay())
            return 1
        if (pdfViewer && pdfViewer.pageTransitionHasPreview)
            return 1
        return activeDocumentHasRenderedCurrentPage() ? 1 : 0
    }

    function loadingOverlayTitle() {
        if (openInProgress)
            return pendingOpenFileName.length > 0 ? "Abriendo " + pendingOpenFileName : "Abriendo PDF"
        if (hasActiveDocument)
            return "Preparando " + activeDocumentTitle()
        return "Abriendo PDF"
    }

    function loadingOverlaySubtitle() {
        if (openInProgress)
            return "Analizando paginas y preparando la primera vista..."
        if (pdfViewer && pdfViewer.largeJumpMode)
            return "Mostrando una vista previa rapida mientras terminamos de afinar la pagina..."
        if (pdfViewer && pdfViewer.pageTransitionActive)
            return "Cargando la pagina seleccionada y dejando preparada la navegacion cercana..."

        var pending = activeDocumentPendingRenderCount()
        if (pending > 0)
            return pending > 1
                ? "Renderizando las primeras paginas para que el visor entre suave."
                : "Renderizando la primera pagina..."

        return "Cargando el documento..."
    }

    function isLargePageJump(targetPage) {
        if (!hasActiveDocument)
            return false

        var target = Number(targetPage)
        if (!isFinite(target))
            return false

        return Math.abs(target - activePageIndex) > largeJumpThresholdPages
    }

    function prunePageSourceWindow(sources, centerPage, radius) {
        var kept = []
        var minimumPage = Math.max(0, Number(centerPage) - Math.max(0, Number(radius)))
        var maximumPage = Math.max(minimumPage, Number(centerPage) + Math.max(0, Number(radius)))

        for (var i = 0; i < sources.length; ++i) {
            if (i >= minimumPage && i <= maximumPage)
                kept.push(sources[i] || "")
            else
                kept.push("")
        }

        return kept
    }

    function shouldDelayRenderWindowPrune() {
        if (!pdfViewer)
            return false

        return pdfViewer.largeJumpMode || pdfViewer.pageTransitionActive || pdfViewer.viewportInteracting
    }

    function maintainActiveDocumentRenderWindow(allowPrune) {
        if (!hasActiveDocument)
            return

        if (allowPrune === false || shouldDelayRenderWindowPrune()) {
            renderWindowMaintenanceTimer.restart()
            return
        }

        var doc = documentModel.get(activeDocumentIndex)
        var sources = activeDocumentPageSources()
        if (!sources || sources.length <= 0)
            return

        var pruned = prunePageSourceWindow(sources, activePageIndex, pageRenderWindowRadius)
        var changed = false
        for (var i = 0; i < sources.length; ++i) {
            if (String(sources[i] || "") !== String(pruned[i] || "")) {
                changed = true
                break
            }
        }

        var order = normalizedDocumentPageOrder(doc)
        var orderIsIdentity = order.length === Number(doc.pageCount || 0)
        if (orderIsIdentity) {
            for (var orderIndex = 0; orderIndex < order.length; ++orderIndex) {
                if (Number(order[orderIndex]) !== orderIndex) {
                    orderIsIdentity = false
                    break
                }
            }
        }

        if (changed && orderIsIdentity)
            documentModel.setProperty(activeDocumentIndex, "pageSourcesJson", JSON.stringify(pruned))

        var sourcePage = sourcePageForDocumentIndex(doc, activePageIndex)
        if (sourcePage < 0)
            sourcePage = 0

        documentRenderController.prunePageCache(doc.path,
                                                sourcePage,
                                                pageRenderWindowRadius,
                                                Number(doc.renderSessionId || 0))
    }

    function activeDocumentPerformanceText() {
        if (!hasActiveDocument)
            return ""

        var parts = []
        var firstPageMs = activeDocumentFirstPageVisibleMs()
        if (firstPageMs >= 0)
            parts.push("Primera pagina " + String(firstPageMs) + " ms")

        parts.push("Cache " + formatBytes(activeDocumentRenderCacheBytes()))
        parts.push("RAM " + formatBytes(activeDocumentProcessMemoryBytes()))

        var pending = activeDocumentPendingRenderCount()
        if (pending > 0)
            parts.push("Cola " + String(pending))

        return parts.join(" · ")
    }

    function updateDocumentRenderMetrics(index, firstPageVisibleMs, cacheBytes, processBytes, peakBytes, pendingCount) {
        if (index < 0 || index >= documentModel.count)
            return

        if (firstPageVisibleMs >= 0)
            documentModel.setProperty(index, "firstPageVisibleMs", firstPageVisibleMs)
        documentModel.setProperty(index, "renderCacheBytes", cacheBytes)
        documentModel.setProperty(index, "processMemoryBytes", processBytes)
        documentModel.setProperty(index, "peakProcessMemoryBytes", peakBytes)
        documentModel.setProperty(index, "pendingRenderCount", pendingCount)
    }

    function activeDocumentPageSources() {
        if (!hasActiveDocument)
            return []

        var doc = documentModel.get(activeDocumentIndex)
        var sources = parseJsonArray(doc.pageSourcesJson || "[]", [])

        if (sources.length === 0 && doc.previewSource && doc.previewSource.length > 0)
            sources = [doc.previewSource]

        return remapArrayByDocumentOrder(doc, sources)
    }

    function activeDocumentThumbnailSources() {
        if (!hasActiveDocument)
            return []

        var doc = documentModel.get(activeDocumentIndex)
        return remapArrayByDocumentOrder(doc, parseJsonArray(doc.thumbnailSourcesJson || "[]", []))
    }

    function activeDocumentPageSizesJson() {
        if (!hasActiveDocument)
            return "[]"

        var doc = documentModel.get(activeDocumentIndex)
        var pageSizes = parseJsonArray(doc.pageSizesJson || "[]", [])
        return JSON.stringify(remapArrayByDocumentOrder(doc, pageSizes))
    }

    function activeDocumentPageRotations() {
        if (!hasActiveDocument)
            return []

        var doc = documentModel.get(activeDocumentIndex)
        var rotations = parseJsonArray(doc.pageRotationsJson || "[]", [])
        while (rotations.length < Number(doc.pageCount || 0))
            rotations.push(0)

        var order = normalizedDocumentPageOrder(doc)
        var visibleRotations = []
        for (var i = 0; i < order.length; ++i) {
            var sourcePage = Number(order[i])
            visibleRotations.push(sourcePage >= 0 && sourcePage < rotations.length ? Number(rotations[sourcePage] || 0) : 0)
        }

        return visibleRotations
    }

    function activeDocumentEditAnnotations() {
        if (!hasActiveDocument)
            return []

        var doc = documentModel.get(activeDocumentIndex)
        var annotations = parseJsonArray(doc.editAnnotationsJson || "[]", [])
        var visibleAnnotations = []
        for (var i = 0; i < annotations.length; ++i) {
            var sourcePage = Number(annotations[i].pageIndex)
            var visiblePage = visibleIndexForSourcePage(doc, sourcePage)
            if (visiblePage < 0)
                continue

            var item = JSON.parse(JSON.stringify(annotations[i]))
            item.sourcePageIndex = sourcePage
            item.pageIndex = visiblePage
            visibleAnnotations.push(item)
        }

        return visibleAnnotations
    }

    function activeDocumentOutlineEntries() {
        if (!hasActiveDocument)
            return []

        var doc = documentModel.get(activeDocumentIndex)
        var raw = parseJsonArray(doc.outlineJson || "[]", [])

        var flattened = []

        function visit(items, depth) {
            if (!items || items.length === undefined)
                return

            for (var i = 0; i < items.length; ++i) {
                var item = items[i] || {}
                var mappedPageIndex = item.pageIndex !== undefined ? visibleIndexForSourcePage(doc, item.pageIndex) : -1
                flattened.push({
                    title: item.title || ("Bookmark " + String(flattened.length + 1)),
                    pageIndex: mappedPageIndex,
                    uri: item.uri || "",
                    depth: depth,
                    isOpen: item.isOpen === undefined ? true : item.isOpen
                })
                visit(item.children || [], depth + 1)
            }
        }

        visit(raw, 0)
        return flattened
    }

    function activeDocumentLinksByPage() {
        if (!hasActiveDocument)
            return []

        var doc = documentModel.get(activeDocumentIndex)
        var sourcePages = parseJsonArray(doc.pageLinksJson || "[]", [])
        var order = normalizedDocumentPageOrder(doc)
        var remappedPages = []

        for (var i = 0; i < order.length; ++i) {
            var sourcePage = Number(order[i])
            var sourceLinks = sourcePage >= 0 && sourcePage < sourcePages.length ? sourcePages[sourcePage] : []
            var targetLinks = []
            if (sourceLinks && sourceLinks.length !== undefined) {
                for (var linkIndex = 0; linkIndex < sourceLinks.length; ++linkIndex) {
                    var link = sourceLinks[linkIndex] || {}
                    var targetPage = link.pageIndex !== undefined ? visibleIndexForSourcePage(doc, link.pageIndex) : -1
                    var mappedLink = {
                        uri: link.uri || "",
                        external: !!link.external,
                        pageIndex: targetPage,
                        targetX: link.targetX !== undefined ? link.targetX : 0,
                        targetY: link.targetY !== undefined ? link.targetY : 0,
                        rect: link.rect || {}
                    }
                    targetLinks.push(mappedLink)
                }
            }
            remappedPages.push(targetLinks)
        }

        return remappedPages
    }

    function activeDocumentSearchResults() {
        if (!hasActiveDocument)
            return []

        try {
            return JSON.parse(documentModel.get(activeDocumentIndex).searchResultsJson || "[]")
        } catch(e) {
            return []
        }
    }

    function remapSearchResultsForDocument(index, resultsJson) {
        if (index < 0 || index >= documentModel.count)
            return "[]"

        var doc = documentModel.get(index)
        var parsed = parseJsonArray(resultsJson || "[]", [])
        var mapped = []
        for (var i = 0; i < parsed.length; ++i) {
            var item = parsed[i] || {}
            var visiblePage = visibleIndexForSourcePage(doc, item.pageIndex)
            if (visiblePage < 0)
                continue

            var mappedItem = {
                pageIndex: visiblePage,
                rect: item.rect || {},
                text: item.text || ""
            }
            mapped.push(mappedItem)
        }

        return JSON.stringify(mapped)
    }

    function activeDocumentSearchResultCount() {
        return activeDocumentSearchResults().length
    }

    function activeDocumentSearchResultIndex() {
        if (!hasActiveDocument)
            return -1

        var value = Number(documentModel.get(activeDocumentIndex).activeSearchResultIndex)
        return isNaN(value) ? -1 : value
    }

    function activeDocumentSearchResult(index) {
        var results = activeDocumentSearchResults()
        if (index < 0 || index >= results.length)
            return null
        return results[index]
    }

    function activeDocumentSearchPending() {
        if (!hasActiveDocument)
            return false
        return !!documentModel.get(activeDocumentIndex).searchInProgress
    }

    function activeDocumentSearchQuery() {
        return hasActiveDocument ? String(documentModel.get(activeDocumentIndex).searchQuery || "") : ""
    }

    function activeDocumentReflowText() {
        return hasActiveDocument ? String(documentModel.get(activeDocumentIndex).reflowText || "") : ""
    }

    function readActiveDocumentPageTextCache() {
        if (!hasActiveDocument)
            return {}

        try {
            var parsed = JSON.parse(documentModel.get(activeDocumentIndex).pageTextCacheJson || "{}")
            return parsed && typeof parsed === "object" ? parsed : {}
        } catch(e) {
            return {}
        }
    }

    function writeActiveDocumentPageTextCache(cache) {
        if (!hasActiveDocument)
            return

        documentModel.setProperty(activeDocumentIndex, "pageTextCacheJson", JSON.stringify(cache || {}))
    }

    function activeDocumentHistoryBack() {
        if (!hasActiveDocument)
            return []

        try {
            return JSON.parse(documentModel.get(activeDocumentIndex).historyBackJson || "[]")
        } catch(e) {
            return []
        }
    }

    function activeDocumentHistoryForward() {
        if (!hasActiveDocument)
            return []

        try {
            return JSON.parse(documentModel.get(activeDocumentIndex).historyForwardJson || "[]")
        } catch(e) {
            return []
        }
    }

    function trimHistoryEntries(entries) {
        var copy = entries.slice()
        while (copy.length > 100)
            copy.shift()
        return copy
    }

    function captureDocumentEditState(doc) {
        return {
            pageOrder: normalizedDocumentPageOrder(doc),
            pageRotations: parseJsonArray(doc.pageRotationsJson || "[]", []),
            editAnnotations: parseJsonArray(doc.editAnnotationsJson || "[]", [])
        }
    }

    function documentEditStateSignature(state) {
        return JSON.stringify({
            pageOrder: state && state.pageOrder ? state.pageOrder : [],
            pageRotations: state && state.pageRotations ? state.pageRotations : [],
            editAnnotations: state && state.editAnnotations ? state.editAnnotations : []
        })
    }

    function documentHasPendingChanges(index) {
        if (index < 0 || index >= documentModel.count)
            return false

        var doc = documentModel.get(index)
        var order = normalizedDocumentPageOrder(doc)
        if (order.length !== Number(doc.pageCount || 0))
            return true

        for (var page = 0; page < order.length; ++page) {
            if (Number(order[page]) !== page)
                return true
        }

        var rotations = parseJsonArray(doc.pageRotationsJson || "[]", [])
        for (var i = 0; i < rotations.length; ++i) {
            if ((Number(rotations[i]) || 0) !== 0)
                return true
        }

        if (parseJsonArray(doc.editAnnotationsJson || "[]", []).length > 0)
            return true

        if (index === activeDocumentIndex
                && editingController
                && editingController.hasPendingEdits)
            return true

        return false
    }

    function activeDocumentHasPendingChanges() {
        return documentHasPendingChanges(activeDocumentIndex)
    }

    function activeDocumentCanUndoEdits() {
        if (!hasActiveDocument)
            return false
        return parseJsonArray(documentModel.get(activeDocumentIndex).editUndoJson || "[]", []).length > 0
    }

    function activeDocumentCanRedoEdits() {
        if (!hasActiveDocument)
            return false
        return parseJsonArray(documentModel.get(activeDocumentIndex).editRedoJson || "[]", []).length > 0
    }

    function activeDocumentHasRotations() {
        return activeDocumentHasPendingChanges()
    }

    function syncActiveDocumentState(skipSessionSave) {
        if (!hasActiveDocument)
            return

        viewerZoom = normalizedZoom(viewerZoom)
        documentModel.setProperty(activeDocumentIndex, "zoom", viewerZoom)
        documentModel.setProperty(activeDocumentIndex, "layoutMode", layoutMode)
        documentModel.setProperty(activeDocumentIndex, "zoomMode", zoomMode)
        documentModel.setProperty(activeDocumentIndex, "navigationPanelVisible", navigationPanelVisible)
        documentModel.setProperty(activeDocumentIndex, "sidePanelMode", navigationSidePanelMode)
        documentModel.setProperty(activeDocumentIndex, "snapToPage", pageSnapEnabled)
        documentModel.setProperty(activeDocumentIndex, "pageSpacing", pageSpacing)
        documentModel.setProperty(activeDocumentIndex, "activePageIndex", activePageIndex)
        persistViewState(documentModel.get(activeDocumentIndex).path, {
            zoom: viewerZoom,
            layoutMode: layoutMode,
            zoomMode: zoomMode
        })
        if (!skipSessionSave)
            saveCurrentSession(true)
    }

    function applyDocumentEditState(index, state, preferredSourcePage) {
        if (index < 0 || index >= documentModel.count || !state)
            return false

        var doc = documentModel.get(index)
        var nextOrder = state.pageOrder && state.pageOrder.length !== undefined
            ? state.pageOrder.slice()
            : identityPageOrder(doc.pageCount)
        var nextRotations = state.pageRotations && state.pageRotations.length !== undefined
            ? state.pageRotations.slice()
            : []
        var nextAnnotations = state.editAnnotations && state.editAnnotations.length !== undefined
            ? state.editAnnotations.slice()
            : []

        documentModel.setProperty(index, "pageOrderJson", JSON.stringify(nextOrder))
        documentModel.setProperty(index, "pageRotationsJson", JSON.stringify(nextRotations))
        documentModel.setProperty(index, "editAnnotationsJson", JSON.stringify(nextAnnotations))
        documentModel.setProperty(index, "pageTextCacheJson", "{}")
        documentModel.setProperty(index, "searchResultsJson", "[]")
        documentModel.setProperty(index, "activeSearchResultIndex", -1)
        documentModel.setProperty(index, "searchInProgress", false)

        var sourcePage = Number(preferredSourcePage)
        if (!isFinite(sourcePage))
            sourcePage = sourcePageForDocumentIndex(doc, Number(doc.activePageIndex || 0))

        var refreshedDoc = documentModel.get(index)
        var nextVisiblePage = visibleIndexForSourcePage(refreshedDoc, sourcePage)
        if (nextVisiblePage < 0)
            nextVisiblePage = Math.max(0, Math.min(Number(doc.activePageIndex || 0), Math.max(0, nextOrder.length - 1)))

        documentModel.setProperty(index, "activePageIndex", nextVisiblePage)
        if (index === activeDocumentIndex) {
            activePageIndex = nextVisiblePage
            pdfDocument.clearSelection()
            syncActiveDocumentState()
            Qt.callLater(function() {
                jumpToPageRequested(activePageIndex)
            })
        }

        saveMessage = ""
        return true
    }

    function commitDocumentEdit(index, nextState, preferredSourcePage) {
        if (index < 0 || index >= documentModel.count || !nextState)
            return false

        var doc = documentModel.get(index)
        var currentState = captureDocumentEditState(doc)
        if (documentEditStateSignature(currentState) === documentEditStateSignature(nextState))
            return false

        var undoStack = parseJsonArray(doc.editUndoJson || "[]", [])
        undoStack.push(currentState)
        if (undoStack.length > 100)
            undoStack.shift()

        documentModel.setProperty(index, "editUndoJson", JSON.stringify(undoStack))
        documentModel.setProperty(index, "editRedoJson", "[]")
        return applyDocumentEditState(index, nextState, preferredSourcePage)
    }

    function undoActiveDocumentEdit() {
        if (!hasActiveDocument)
            return

        var doc = documentModel.get(activeDocumentIndex)
        var undoStack = parseJsonArray(doc.editUndoJson || "[]", [])
        if (undoStack.length <= 0)
            return

        var previousState = undoStack.pop()
        var redoStack = parseJsonArray(doc.editRedoJson || "[]", [])
        redoStack.push(captureDocumentEditState(doc))
        documentModel.setProperty(activeDocumentIndex, "editUndoJson", JSON.stringify(undoStack))
        documentModel.setProperty(activeDocumentIndex, "editRedoJson", JSON.stringify(redoStack))
        applyDocumentEditState(activeDocumentIndex, previousState, sourcePageForActivePage(activePageIndex))
    }

    function redoActiveDocumentEdit() {
        if (!hasActiveDocument)
            return

        var doc = documentModel.get(activeDocumentIndex)
        var redoStack = parseJsonArray(doc.editRedoJson || "[]", [])
        if (redoStack.length <= 0)
            return

        var nextState = redoStack.pop()
        var undoStack = parseJsonArray(doc.editUndoJson || "[]", [])
        undoStack.push(captureDocumentEditState(doc))
        documentModel.setProperty(activeDocumentIndex, "editUndoJson", JSON.stringify(undoStack))
        documentModel.setProperty(activeDocumentIndex, "editRedoJson", JSON.stringify(redoStack))
        applyDocumentEditState(activeDocumentIndex, nextState, sourcePageForActivePage(activePageIndex))
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
            reflowModeEnabled = false
            saveCurrentSession(true)
            return
        }

        activeDocumentIndex = index
        var doc = documentModel.get(index)
        var savedState = savedViewStateFor(doc.path)
        viewerZoom = normalizedZoom(doc.zoom !== undefined ? doc.zoom : savedState.zoom)
        layoutMode = doc.layoutMode || savedState.layoutMode || "continuous"
        zoomMode = doc.zoomMode || doc.viewMode || savedState.zoomMode || "fitPage"
        navigationPanelVisible = doc.navigationPanelVisible === undefined ? true : doc.navigationPanelVisible
        navigationSidePanelMode = doc.sidePanelMode || "thumbnails"
        pageSnapEnabled = doc.snapToPage === undefined ? false : doc.snapToPage
        pageSpacing = doc.pageSpacing === undefined ? 18 : doc.pageSpacing
        activePageIndex = doc.activePageIndex || 0

        if (pdfDocument.filePath !== doc.path)
            loadPdfWithPasswordPrompt(doc.path, doc.password || "")

        updateActiveSearchResults()
        if (reflowModeEnabled && activeDocumentReflowText().length === 0)
            Qt.callLater(function() { ensureActiveDocumentReflowText(false) })
        saveCurrentSession(true)
    }

    function closeActiveDocument() {
        closeDocumentAt(activeDocumentIndex)
    }

    function openHomeScreen() {
        setActiveDocument(-1)
        Qt.callLater(function() {
            if (homeOpenButton)
                homeOpenButton.forceActiveFocus()
        })
    }

    function performCloseDocumentAt(index) {
        if (index < 0 || index >= documentModel.count)
            return

        var closingDoc = documentModel.get(index)
        if (closingDoc && closingDoc.path)
            documentRenderController.releaseDocument(closingDoc.path, closingDoc.renderSessionId || 0)

        var nextActiveIndex = activeDocumentIndex
        if (index === activeDocumentIndex) {
            if (documentModel.count === 1)
                nextActiveIndex = -1
            else if (index === documentModel.count - 1)
                nextActiveIndex = index - 1
            else
                nextActiveIndex = index
        } else if (index < activeDocumentIndex) {
            nextActiveIndex = activeDocumentIndex - 1
        }

        documentModel.remove(index)
        if (documentModel.count === 0 || nextActiveIndex < 0) {
            setActiveDocument(-1)
        } else {
            setActiveDocument(Math.max(0, Math.min(nextActiveIndex, documentModel.count - 1)))
        }
        saveCurrentSession(true)
    }

    function requestCloseDocumentAt(index) {
        if (index < 0 || index >= documentModel.count)
            return

        if (!documentHasPendingChanges(index)) {
            performCloseDocumentAt(index)
            return
        }

        pendingEditsDialog.closeMode = "document"
        pendingEditsDialog.documentIndex = index
        pendingEditsDialog.open()
    }

    function closeDocumentAt(index) {
        requestCloseDocumentAt(index)
    }

    function openPdf(source) {
        if (String(source || "").trim().length === 0)
            return

        pendingOpenSource = source
        pendingOpenFileName = fileNameFromPath(source)
        pendingProtectedSource = ""
        pendingSessionDocumentState = null
        openInProgress = true
        saveMessage = ""
        openPdfErrorDialog.close()
        passwordDialog.close()
        openPdfTimer.start()
    }

    function showPasswordDialog(source, preserveInput) {
        pendingProtectedSource = source
        passwordDialog.source = source
        passwordDialog.fileName = fileNameFromPath(source)
        if (!preserveInput)
            passwordDialog.passwordValue = ""
        passwordDialog.inlineError = ""
        passwordDialog.open()
        Qt.callLater(function() {
            passwordField.forceActiveFocus()
            if (preserveInput)
                passwordField.selectAll()
        })
    }

    function loadPdfWithPasswordPrompt(source, password) {
        if (pdfDocument.load(source, password || ""))
            return true

        if (pdfDocument.passwordRequired) {
            showPasswordDialog(source, false)
            return false
        }

        return false
    }

    function completeOpenedPdf(restoredSessionState) {
        saveMessage = ""
        window.visibility = Window.Maximized

        for (var i = 0; i < documentModel.count; ++i) {
            if (documentModel.get(i).path === pdfDocument.filePath) {
                documentModel.setProperty(i, "password", pdfDocument.password)
                setActiveDocument(i)
                addRecentFile(pdfDocument.filePath, pdfDocument.title)
                if (sessionRestoreInProgress)
                    restoreNextSessionDocument()
                return
            }
        }

        var sources = loadedPageSources()
        var thumbnails = loadedThumbnailSources()
        var savedState = savedViewStateFor(pdfDocument.filePath)
        var restoredState = normalizedRestoredDocumentState(restoredSessionState, savedState)
        var restoredPageIndex = Math.max(0, Math.min(restoredState.activePageIndex, Math.max(0, pdfDocument.pageCount - 1)))

        documentModel.append({
            path: pdfDocument.filePath,
            title: pdfDocument.title,
            password: pdfDocument.password,
            previewSource: pdfDocument.previewSource,
            pageSourcesJson: JSON.stringify(sources),
            thumbnailSourcesJson: JSON.stringify(thumbnails),
            pageSizesJson: pdfDocument.pageSizesJson,
            outlineJson: pdfDocument.outlineJson,
            pageLinksJson: pdfDocument.pageLinksJson,
            pageCount: pdfDocument.pageCount,
            fileSizeBytes: pdfDocument.fileSizeBytes,
            zoom: restoredState.zoom,
            layoutMode: restoredState.layoutMode,
            zoomMode: restoredState.zoomMode,
            navigationPanelVisible: restoredState.navigationPanelVisible,
            sidePanelMode: restoredState.sidePanelMode,
            snapToPage: restoredState.snapToPage,
            pageSpacing: restoredState.pageSpacing,
            activePageIndex: restoredPageIndex,
            pageOrderJson: "[]",
            pageRotationsJson: "[]",
            editAnnotationsJson: "[]",
            editUndoJson: "[]",
            editRedoJson: "[]",
            searchQuery: restoredState.searchQuery,
            searchResultsJson: "[]",
            activeSearchResultIndex: -1,
            searchRequestId: 0,
            searchInProgress: false,
            reflowText: "",
            pageTextCacheJson: "{}",
            historyBackJson: JSON.stringify(restoredState.historyBack),
            historyForwardJson: JSON.stringify(restoredState.historyForward),
            renderSessionId: ++renderSessionSerial,
            firstPageVisibleMs: -1,
            renderCacheBytes: 0,
            processMemoryBytes: 0,
            peakProcessMemoryBytes: 0,
            pendingRenderCount: 0
        })
        documentRenderController.markDocumentOpened(pdfDocument.filePath, renderSessionSerial, pdfDocument.password)
        setActiveDocument(documentModel.count - 1)
        addRecentFile(pdfDocument.filePath, pdfDocument.title)
        saveCurrentSession(true)
        pendingSessionDocumentState = null
        if (sessionRestoreInProgress)
            restoreNextSessionDocument()
    }

    function finishOpenPdf() {
        var source = pendingOpenSource
        pendingOpenSource = ""
        var opened = pdfDocument.load(source)
        openInProgress = false
        pendingOpenFileName = ""

        if (opened) {
            completeOpenedPdf(pendingSessionDocumentState)
            return
        }

        if (pdfDocument.passwordRequired) {
            showPasswordDialog(source, false)
            return
        }

        showOpenPdfError(source)
    }

    function openProtectedPdf(source) {
        var targetSource = String(source || pendingProtectedSource || "").trim()
        if (targetSource.length === 0)
            return

        passwordDialog.inlineError = ""
        if (pdfDocument.retryWithPassword(passwordDialog.passwordValue)) {
            pendingProtectedSource = ""
            var restoredSessionState = pendingSessionDocumentState
            pendingSessionDocumentState = null
            passwordDialog.close()
            completeOpenedPdf(restoredSessionState)
            return
        }

        if (pdfDocument.passwordRequired) {
            passwordDialog.inlineError = "La contrasena no es correcta. Prueba de nuevo."
            passwordDialog.open()
            passwordField.forceActiveFocus()
            passwordField.selectAll()
            return
        }

        pendingProtectedSource = ""
        passwordDialog.close()
        showOpenPdfError(targetSource)
    }

    function handlePasswordDialogClosed() {
        if (!sessionRestoreInProgress || !pendingSessionDocumentState)
            return

        pendingProtectedSource = ""
        pendingSessionDocumentState = null
        restoreNextSessionDocument()
    }

    function showOpenPdfError(source) {
        openPdfErrorDialog.fileName = fileNameFromPath(source)
        openPdfErrorDialog.reason = friendlyOpenPdfError()
        openPdfErrorDialog.open()
    }

    function friendlyOpenPdfError() {
        var raw = String(pdfDocument.errorMessage || "").toLowerCase()

        if (raw.indexOf("password") >= 0 || raw.indexOf("contrasena") >= 0)
            return "No se pudo desbloquear el PDF con la contrasena indicada."

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

    function shouldShowGlobalPdfError() {
        if (pdfDocument.passwordRequired)
            return false

        var raw = String(pdfDocument.errorMessage || "").toLowerCase()
        if (raw.indexOf("password") >= 0 || raw.indexOf("contrasena") >= 0)
            return false

        return pdfDocument.errorMessage.length > 0
    }

    function performDocumentSaveTransaction(index, target, refreshAfterSave) {
        if (index < 0 || index >= documentModel.count)
            return false

        var doc = documentModel.get(index)
        var overwriteCurrent = isSameFilePath(doc.path, target)
        var sessionId = Number(doc.renderSessionId || 0)
        var password = doc.password || ""
        var saved = false

        documentSearchController.cancelSearchSync()
        if (overwriteCurrent) {
            setDocumentSaveInProgress(doc.path, true)
            documentRenderController.releaseDocumentSync(doc.path, sessionId)
        }

        try {
            saved = pdfDocument.saveEditedCopy(doc.path,
                                               target,
                                               doc.pageOrderJson || "[]",
                                               doc.pageRotationsJson || "[]",
                                               password,
                                               doc.editAnnotationsJson || "[]")
        } finally {
            if (overwriteCurrent)
                setDocumentSaveInProgress(doc.path, false)
        }

        if (saved) {
            saveMessage = "Guardado: " + fileNameFromPath(target)
            if (overwriteCurrent && refreshAfterSave && index === activeDocumentIndex) {
                if (!refreshActiveDocumentFromDisk()) {
                    restoreDocumentAfterFailedSave(index, password, sessionId)
                    saveMessage = ""
                    return false
                }
            }
            return true
        }

        if (overwriteCurrent)
            restoreDocumentAfterFailedSave(index, password, sessionId)
        saveMessage = ""
        return false
    }

    function captureActiveViewerStateForEditingSave(targetPath) {
        if (!hasActiveDocument)
            return null

        return {
            oldPath: String(documentModel.get(activeDocumentIndex).path || ""),
            targetPath: String(targetPath || ""),
            activePageIndex: activePageIndex,
            zoom: viewerZoom,
            layoutMode: layoutMode,
            zoomMode: zoomMode,
            navigationPanelVisible: navigationPanelVisible,
            sidePanelMode: navigationSidePanelMode,
            snapToPage: pageSnapEnabled,
            pageSpacing: pageSpacing,
            viewMode: viewMode,
            topToolbarMenu: topToolbarMenu,
            selectedBlockId: editingController ? String(editingController.selectedBlockId || "") : ""
        }
    }

    function completeEditingControllerSave(outputPath) {
        var target = localPathFromUrl(outputPath || pendingEditingSaveTarget)
        var state = pendingEditingSaveState || captureActiveViewerStateForEditingSave(target)
        pendingEditingSaveTarget = ""
        pendingEditingSaveState = null

        if (!hasActiveDocument || target.length === 0)
            return

        var index = activeDocumentIndex
        var oldPath = state ? String(state.oldPath || documentModel.get(index).path || "") : String(documentModel.get(index).path || "")
        var oldSessionId = Number(documentModel.get(index).renderSessionId || 0)
        documentSearchController.cancelSearchSync()
        if (oldPath.length > 0)
            documentRenderController.releaseDocumentSync(oldPath, oldSessionId)

        if (!loadPdfWithPasswordPrompt(target, documentModel.get(index).password || "")) {
            saveMessage = qsTr("El PDF se guardó, pero no se pudo reabrir la copia.")
            return
        }

        var sources = loadedPageSources()
        var thumbnails = loadedThumbnailSources()
        var sessionId = ++renderSessionSerial
        documentModel.setProperty(index, "path", pdfDocument.filePath)
        documentModel.setProperty(index, "title", pdfDocument.title)
        documentModel.setProperty(index, "password", pdfDocument.password)
        documentModel.setProperty(index, "previewSource", pdfDocument.previewSource)
        documentModel.setProperty(index, "pageSourcesJson", JSON.stringify(sources))
        documentModel.setProperty(index, "thumbnailSourcesJson", JSON.stringify(thumbnails))
        documentModel.setProperty(index, "pageSizesJson", pdfDocument.pageSizesJson)
        documentModel.setProperty(index, "outlineJson", pdfDocument.outlineJson)
        documentModel.setProperty(index, "pageLinksJson", pdfDocument.pageLinksJson)
        documentModel.setProperty(index, "pageCount", pdfDocument.pageCount)
        documentModel.setProperty(index, "fileSizeBytes", pdfDocument.fileSizeBytes)
        documentModel.setProperty(index, "pageOrderJson", "[]")
        documentModel.setProperty(index, "pageRotationsJson", "[]")
        documentModel.setProperty(index, "editAnnotationsJson", "[]")
        documentModel.setProperty(index, "editUndoJson", "[]")
        documentModel.setProperty(index, "editRedoJson", "[]")
        documentModel.setProperty(index, "zoom", state ? state.zoom : viewerZoom)
        documentModel.setProperty(index, "layoutMode", state ? state.layoutMode : layoutMode)
        documentModel.setProperty(index, "zoomMode", state ? state.zoomMode : zoomMode)
        documentModel.setProperty(index, "navigationPanelVisible", state ? state.navigationPanelVisible : navigationPanelVisible)
        documentModel.setProperty(index, "sidePanelMode", state ? state.sidePanelMode : navigationSidePanelMode)
        documentModel.setProperty(index, "snapToPage", state ? state.snapToPage : pageSnapEnabled)
        documentModel.setProperty(index, "pageSpacing", state ? state.pageSpacing : pageSpacing)
        documentModel.setProperty(index, "activePageIndex", Math.min(state ? state.activePageIndex : activePageIndex,
                                                                     Math.max(0, pdfDocument.pageCount - 1)))
        documentModel.setProperty(index, "renderSessionId", sessionId)
        documentModel.setProperty(index, "pageTextCacheJson", "{}")
        documentModel.setProperty(index, "searchResultsJson", "[]")
        documentModel.setProperty(index, "activeSearchResultIndex", -1)
        documentModel.setProperty(index, "searchInProgress", false)
        documentRenderController.markDocumentOpened(pdfDocument.filePath, sessionId, pdfDocument.password)
        editingControllerExtractedPage = -1
        editingControllerFilePath = ""
        if (editingController)
            editingController.closeDocument()
        setActiveDocument(index)
        if (state) {
            topToolbarMenu = state.topToolbarMenu || topToolbarMenu
            viewMode = state.viewMode || viewMode
        }
        jumpToPageRequested(activePageIndex)
        if (viewMode === "edit")
            Qt.callLater(function() { requestEditExtractionForActivePage() })
        saveMessage = qsTr("Guardado: ") + fileNameFromPath(target)
        saveCurrentSession(true)
    }

    function saveDocumentChanges(index, target, refreshAfterSave) {
        return performDocumentSaveTransaction(index, target, refreshAfterSave)
    }

    function saveActiveDocumentAsRotated(target) {
        if (!hasActiveDocument)
            return

        var targetPath = localPathFromUrl(target)
        if (editingController
                && editingController.ready
                && editingController.hasPendingEdits) {
            pendingEditingSaveTarget = targetPath
            pendingEditingSaveState = captureActiveViewerStateForEditingSave(targetPath)
            if (!editingController.saveDocument(targetPath, pendingEditSaveIncremental)) {
                pendingEditingSaveTarget = ""
                pendingEditingSaveState = null
            }
            return
        }

        saveDocumentChanges(activeDocumentIndex, targetPath, isSameFilePath(documentModel.get(activeDocumentIndex).path, targetPath))
    }

    function refreshActiveDocumentFromDisk() {
        if (!hasActiveDocument)
            return false

        var index = activeDocumentIndex
        var path = documentModel.get(index).path
        var oldSessionId = Number(documentModel.get(index).renderSessionId || 0)
        var page = activePageIndex
        var zoom = viewerZoom
        var layout = layoutMode
        var zoomModeValue = zoomMode

        if (!loadPdfWithPasswordPrompt(path, documentModel.get(index).password || ""))
            return false

        var sources = loadedPageSources()
        var thumbnails = loadedThumbnailSources()
        var sessionId = ++renderSessionSerial
        documentModel.setProperty(index, "title", pdfDocument.title)
        documentModel.setProperty(index, "previewSource", pdfDocument.previewSource)
        documentModel.setProperty(index, "pageSourcesJson", JSON.stringify(sources))
        documentModel.setProperty(index, "thumbnailSourcesJson", JSON.stringify(thumbnails))
        documentModel.setProperty(index, "pageSizesJson", pdfDocument.pageSizesJson)
        documentModel.setProperty(index, "outlineJson", pdfDocument.outlineJson)
        documentModel.setProperty(index, "pageLinksJson", pdfDocument.pageLinksJson)
        documentModel.setProperty(index, "pageCount", pdfDocument.pageCount)
        documentModel.setProperty(index, "fileSizeBytes", pdfDocument.fileSizeBytes)
        documentModel.setProperty(index, "pageOrderJson", "[]")
        documentModel.setProperty(index, "pageRotationsJson", "[]")
        documentModel.setProperty(index, "editAnnotationsJson", "[]")
        documentModel.setProperty(index, "editUndoJson", "[]")
        documentModel.setProperty(index, "editRedoJson", "[]")
        documentModel.setProperty(index, "zoom", zoom)
        documentModel.setProperty(index, "layoutMode", layout)
        documentModel.setProperty(index, "zoomMode", zoomModeValue)
        documentModel.setProperty(index, "activePageIndex", Math.min(page, Math.max(0, pdfDocument.pageCount - 1)))
        documentModel.setProperty(index, "renderSessionId", sessionId)
        documentModel.setProperty(index, "firstPageVisibleMs", -1)
        documentModel.setProperty(index, "renderCacheBytes", 0)
        documentModel.setProperty(index, "processMemoryBytes", 0)
        documentModel.setProperty(index, "peakProcessMemoryBytes", 0)
        documentModel.setProperty(index, "pendingRenderCount", 0)
        documentRenderController.releaseDocument(path, oldSessionId)
        documentModel.setProperty(index, "password", pdfDocument.password)
        documentRenderController.markDocumentOpened(path, sessionId, pdfDocument.password)
        setActiveDocument(index)
        jumpToPageRequested(activePageIndex)
        return true
    }

    function restoreDocumentAfterFailedSave(index, password, sessionId) {
        if (index < 0 || index >= documentModel.count)
            return

        var doc = documentModel.get(index)
        documentRenderController.markDocumentOpened(doc.path, sessionId, password)

        if (index !== activeDocumentIndex)
            return

        var restoredPage = Math.max(0, Math.min(activePageIndex, Math.max(0, activeDocumentPageCount() - 1)))
        if (!loadPdfWithPasswordPrompt(doc.path, password))
            return

        documentModel.setProperty(index, "password", pdfDocument.password)
        documentModel.setProperty(index, "activePageIndex", restoredPage)
        activePageIndex = restoredPage
        pdfDocument.clearSelection()
        Qt.callLater(function() {
            jumpToPageRequested(activePageIndex)
        })
    }

    function requestActivePageRender(pageIndex, scale) {
        if (!hasActiveDocument)
            return

        var doc = documentModel.get(activeDocumentIndex)
        if (isDocumentSaveInProgress(doc.path))
            return
        var sourcePage = sourcePageForDocumentIndex(doc, pageIndex)
        if (sourcePage < 0)
            return
        documentRenderController.requestPageRender(doc.path, sourcePage, scale, doc.renderSessionId || 0)
    }

    function requestActiveThumbnailRender(pageIndex) {
        if (!hasActiveDocument)
            return

        var doc = documentModel.get(activeDocumentIndex)
        if (isDocumentSaveInProgress(doc.path))
            return
        var sourcePage = sourcePageForDocumentIndex(doc, pageIndex)
        if (sourcePage < 0)
            return
        documentRenderController.requestThumbnailRender(doc.path, sourcePage, doc.renderSessionId || 0)
    }

    function updateActiveSearchResults() {
        if (!hasActiveDocument)
            return

        var query = activeDocumentSearchQuery().trim()
        if (query.length === 0) {
            searchDebounceTimer.stop()
            documentModel.setProperty(activeDocumentIndex, "searchResultsJson", "[]")
            documentModel.setProperty(activeDocumentIndex, "activeSearchResultIndex", -1)
            documentModel.setProperty(activeDocumentIndex, "searchInProgress", false)
            if (navigationSidePanelMode === "search")
                navigationSidePanelMode = "thumbnails"
            saveMessage = ""
            syncActiveDocumentState()
            return
        }

        documentModel.setProperty(activeDocumentIndex, "searchInProgress", true)
        saveMessage = "Buscando..."
        syncActiveDocumentState()
        searchDebounceTimer.restart()
    }

    function performSearchRequest() {
        if (!hasActiveDocument)
            return

        var query = activeDocumentSearchQuery().trim()
        if (query.length === 0) {
            documentModel.setProperty(activeDocumentIndex, "searchInProgress", false)
            saveMessage = ""
            return
        }

        var doc = documentModel.get(activeDocumentIndex)
        var requestId = ++searchRequestSerial
        documentModel.setProperty(activeDocumentIndex, "searchRequestId", requestId)
        documentModel.setProperty(activeDocumentIndex, "searchInProgress", true)
        documentSearchController.searchDocument(doc.path, query, requestId, doc.password || "")
    }

    function ensureActiveDocumentBackendLoaded() {
        if (!hasActiveDocument)
            return false

        var doc = documentModel.get(activeDocumentIndex)
        if (pdfDocument.filePath !== doc.path && !loadPdfWithPasswordPrompt(doc.path, doc.password || ""))
            return false

        return true
    }

    function activeSelectionVisualPageIndex() {
        if (!hasActiveDocument)
            return -1
        return visibleIndexForSourcePage(documentModel.get(activeDocumentIndex), pdfDocument.selectionPage)
    }

    function normalizeEditFontFamily(fontFamily) {
        var value = String(fontFamily || "").toLowerCase()
        if (value.indexOf("cour") >= 0)
            return "Cour"
        if (value.indexOf("times") >= 0 || value.indexOf("tiro") >= 0 || value.indexOf("serif") >= 0)
            return "TiRo"
        return "Helv"
    }

    function displayEditFontFamily(fontFamily) {
        var value = normalizeEditFontFamily(fontFamily)
        if (value === "Cour")
            return "Courier New"
        if (value === "TiRo")
            return "Times New Roman"
        return "Arial"
    }

    function nextPaletteColor(current, palette) {
        if (!palette || palette.length <= 0)
            return current

        var normalized = String(current || "").toUpperCase()
        for (var i = 0; i < palette.length; ++i) {
            if (String(palette[i]).toUpperCase() === normalized)
                return palette[(i + 1) % palette.length]
        }

        return palette[0]
    }

    function nextEditAnnotationId(prefix) {
        editAnnotationSerial += 1
        return String(prefix || "edit") + "-" + String(Date.now()) + "-" + String(editAnnotationSerial)
    }

    function activeTextBlocksForPage(pageIndex) {
        if (!hasActiveDocument || topToolbarMenu !== "edit" || activeEditTool !== "text")
            return "[]"

        var sourcePage = sourcePageForActivePage(pageIndex)
        if (sourcePage < 0)
            return "[]"

        return pdfDocument.textBlocksForPage(sourcePage)
    }

    function activeTextElementsForPage(pageIndex) {
        if (!hasActiveDocument || topToolbarMenu !== "edit" || activeEditTool !== "text")
            return "[]"

        var sourcePage = sourcePageForActivePage(pageIndex)
        if (sourcePage < 0)
            return "[]"

        return pdfDocument.textElementsForPage(sourcePage)
    }

    function prepareActiveTextEdit(pageIndex, point) {
        if (!hasActiveDocument || topToolbarMenu !== "edit" || (activeEditTool !== "text" && activeEditTool !== "freeText"))
            return null

        var sourcePage = sourcePageForActivePage(pageIndex)
        if (sourcePage < 0)
            return null

        var seed = {}
        if (activeEditTool === "freeText") {
            seed = {
                found: false,
                type: "freeText",
                text: "Texto",
                originalText: "",
                rect: { x: point.x, y: point.y, width: 180, height: 32 },
                originalRect: { x: point.x, y: point.y, width: 180, height: 32 },
                fontFamily: editFontFamily,
                fontSize: editFontSize,
                color: editTextColor,
                bold: editBoldEnabled,
                italic: editItalicEnabled,
                underline: editUnderlineEnabled
            }
        } else {
            try {
                seed = JSON.parse(pdfDocument.textEditAt(sourcePage, point) || "{}")
            } catch(e) {
                seed = {}
            }
        }

        syncingPdfTextStyle = true
        seed.pdfFontFamily = String(seed.fontFaceName || seed.fontFamily || "")
        editFontFamily = normalizeEditFontFamily(seed.fontFamily || editFontFamily)
        editFontSize = Math.max(6, Math.min(144, Math.round(Number(seed.fontSize || editFontSize || 12))))
        editTextColor = seed.color || editTextColor
        editBoldEnabled = !!seed.bold
        editItalicEnabled = !!seed.italic
        editUnderlineEnabled = !!seed.underline
        syncingPdfTextStyle = false

        seed.id = nextEditAnnotationId("text")
        seed.pageIndex = pageIndex
        seed.sourcePageIndex = sourcePage
        seed.blockKey = seed.blockKey || String(sourcePage) + ":" + JSON.stringify(seed.originalRect || seed.rect || {})
        if (!seed.fontFamily)
            seed.fontFamily = editFontFamily
        if (!seed.fontSize)
            seed.fontSize = editFontSize
        if (!seed.color)
            seed.color = editTextColor
        if (seed.bold === undefined)
            seed.bold = editBoldEnabled
        if (seed.italic === undefined)
            seed.italic = editItalicEnabled
        if (seed.underline === undefined)
            seed.underline = editUnderlineEnabled
        if (!seed.rect)
            seed.rect = { x: point.x, y: point.y, width: 180, height: 24 }
        if (!seed.originalBlockModel)
            seed.originalBlockModel = JSON.parse(JSON.stringify(seed))
        if (!seed.editableDocumentModel) {
            seed.editableDocumentModel = {
                plainText: String(seed.text || ""),
                spans: seed.spans || [],
                lines: seed.lines || []
            }
        }
        if (!seed.dirtyRanges)
            seed.dirtyRanges = []
        if (!seed.layoutMode)
            seed.layoutMode = "preserve-lines"
        seed.styleSyncLocked = true
        seed.geometryFidelity = seed.geometryFidelity || "exact"
        return seed
    }

    function commitActiveTextEdit(draft) {
        if (!hasActiveDocument || !draft)
            return false

        var text = String(draft.text || "")
        if (text.trim().length === 0)
            return false

        var doc = documentModel.get(activeDocumentIndex)
        var annotations = parseJsonArray(doc.editAnnotationsJson || "[]", [])
        var sourcePage = Number(draft.sourcePageIndex)
        if (!isFinite(sourcePage) || sourcePage < 0)
            sourcePage = sourcePageForActivePage(Number(draft.pageIndex || 0))
        if (sourcePage < 0)
            return false

        var replacement = {
            id: draft.id || nextEditAnnotationId("text"),
            type: (draft.type === "freeText" || draft.found === false) ? "freeText" : "replaceTextBlock",
            pageIndex: sourcePage,
            rect: draft.rect || { x: 72, y: 72, width: 180, height: 24 },
            originalRect: draft.originalRect || draft.rect || { x: 72, y: 72, width: 180, height: 24 },
            blockKey: draft.blockKey || String(sourcePage) + ":" + JSON.stringify(draft.originalRect || draft.rect || {}),
            originalText: String(draft.originalText || ""),
            text: text,
            fontFamily: String(draft.fontFamily || editFontFamily || "Helvetica"),
            fontSize: Math.max(6, Math.min(144, Number(draft.fontSize || editFontSize) || 12)),
            color: draft.color || editTextColor,
            bold: draft.bold !== undefined ? !!draft.bold : editBoldEnabled,
            italic: draft.italic !== undefined ? !!draft.italic : editItalicEnabled,
            underline: draft.underline !== undefined ? !!draft.underline : editUnderlineEnabled,
            opacity: 1.0,
            spans: (draft.editableDocumentModel && draft.editableDocumentModel.spans) || draft.spans || [],
            lines: draft.lines || [],
            writingMode: draft.writingMode !== undefined ? Number(draft.writingMode) : 0,
            paragraphDirection: draft.paragraphDirection || [1, 0],
            fontFaceName: String(draft.fontFaceName || ""),
            fontSubsetPrefix: String(draft.fontSubsetPrefix || ""),
            fontResourceName: String(draft.fontResourceName || ""),
            lineCount: Number(draft.lineCount || 0),
            glyphCount: Number(draft.glyphCount || 0),
            originalBlockModel: draft.originalBlockModel || {},
            editableDocumentModel: draft.editableDocumentModel || {
                plainText: text,
                spans: draft.spans || [],
                lines: draft.lines || [],
                visualRuns: draft.visualRuns || [],
                fidelity: draft.fidelity || {}
            },
            visualDocumentModel: draft.visualDocumentModel || {
                plainText: text,
                spans: draft.spans || [],
                lines: draft.lines || [],
                visualRuns: draft.visualRuns || [],
                fidelity: draft.fidelity || {}
            },
            editablePlainText: String(draft.editablePlainText || text),
            visualRuns: draft.visualRuns || [],
            fidelity: draft.fidelity || {},
            dirtyRanges: draft.dirtyRanges || [],
            layoutMode: draft.layoutMode || "preserve-lines",
            cursorPosition: Number(draft.cursorPosition || 0),
            selectionStart: Number(draft.selectionStart || draft.cursorPosition || 0),
            selectionEnd: Number(draft.selectionEnd || draft.cursorPosition || 0),
            geometryFidelity: String(draft.geometryFidelity || "exact")
        }

        var replaced = false
        for (var i = 0; i < annotations.length; ++i) {
            if (String(annotations[i].type || "") === "replaceTextBlock"
                    && String(annotations[i].blockKey || "") === String(replacement.blockKey || "")) {
                annotations[i] = replacement
                replaced = true
                break
            }
        }
        if (!replaced)
            annotations.push(replacement)

        var nextState = captureDocumentEditState(doc)
        nextState.editAnnotations = annotations
        return commitDocumentEdit(activeDocumentIndex, nextState, sourcePage)
    }

    function commitActiveHighlightFromSelection() {
        if (!hasActiveDocument
                || topToolbarMenu !== "edit"
                || (activeEditTool !== "highlight"
                    && activeEditTool !== "underline"
                    && activeEditTool !== "strikeout"))
            return false

        if (pdfDocument.selectionPage < 0 || String(pdfDocument.selectionText || "").trim().length === 0)
            return false

        var quads = parseJsonArray(pdfDocument.selectionGeometryJson || "[]", [])
        if (quads.length === 0)
            return false

        var doc = documentModel.get(activeDocumentIndex)
        var annotations = parseJsonArray(doc.editAnnotationsJson || "[]", [])
        annotations.push({
            id: nextEditAnnotationId(activeEditTool),
            type: activeEditTool,
            pageIndex: pdfDocument.selectionPage,
            quads: quads,
            color: activeEditTool === "highlight" ? editHighlightColor : editTextColor,
            opacity: activeEditTool === "highlight" ? 0.42 : 0.85,
            text: pdfDocument.selectionText || ""
        })

        var nextState = captureDocumentEditState(doc)
        nextState.editAnnotations = annotations
        var committed = commitDocumentEdit(activeDocumentIndex, nextState, pdfDocument.selectionPage)
        if (committed)
            pdfDocument.clearSelection()
        return committed
    }

    function createActiveEditAnnotation(pageIndex, tool, point, points) {
        if (!hasActiveDocument || topToolbarMenu !== "edit")
            return false

        var sourcePage = sourcePageForActivePage(pageIndex)
        if (sourcePage < 0)
            return false

        var px = Number(point.x || 0)
        var py = Number(point.y || 0)
        var rect = { x: px, y: py, width: 96, height: 48 }
        var annotation = {
            id: nextEditAnnotationId(tool),
            type: tool,
            pageIndex: sourcePage,
            rect: rect,
            color: editTextColor,
            opacity: 1.0
        }

        if (tool === "stickyNote") {
            annotation.text = "Nota"
            annotation.color = editHighlightColor
            annotation.rect = { x: px, y: py, width: 24, height: 24 }
        } else if (tool === "rect" || tool === "circle") {
            annotation.borderWidth = 1.5
            annotation.rect = { x: px, y: py, width: 120, height: 72 }
        } else if (tool === "ink") {
            annotation.points = points || []
            annotation.borderWidth = 1.8
        } else if (tool === "freeText") {
            annotation.text = "Texto"
            annotation.fontFamily = editFontFamily
            annotation.fontSize = editFontSize
            annotation.bold = editBoldEnabled
            annotation.italic = editItalicEnabled
            annotation.underline = editUnderlineEnabled
            annotation.rect = { x: px, y: py, width: 180, height: 32 }
        } else {
            return false
        }

        var doc = documentModel.get(activeDocumentIndex)
        var annotations = parseJsonArray(doc.editAnnotationsJson || "[]", [])
        annotations.push(annotation)

        var nextState = captureDocumentEditState(doc)
        nextState.editAnnotations = annotations
        return commitDocumentEdit(activeDocumentIndex, nextState, sourcePage)
    }

    function eraseActiveEditAnnotation(annotationId) {
        if (!hasActiveDocument || !annotationId)
            return false

        var doc = documentModel.get(activeDocumentIndex)
        var annotations = parseJsonArray(doc.editAnnotationsJson || "[]", [])
        var nextAnnotations = []
        var removedSourcePage = -1
        for (var i = 0; i < annotations.length; ++i) {
            if (String(annotations[i].id || "") === String(annotationId)) {
                removedSourcePage = Number(annotations[i].pageIndex)
                continue
            }
            nextAnnotations.push(annotations[i])
        }

        if (nextAnnotations.length === annotations.length)
            return false

        var nextState = captureDocumentEditState(doc)
        nextState.editAnnotations = nextAnnotations
        return commitDocumentEdit(activeDocumentIndex, nextState, removedSourcePage)
    }

    function beginActiveSelection(pageIndex, point) {
        pdfDocument.beginSelection(sourcePageForActivePage(pageIndex), point)
    }

    function updateActiveSelection(pageIndex, point) {
        pdfDocument.updateSelection(sourcePageForActivePage(pageIndex), point)
    }

    function ensureActiveDocumentReflowText(forceRefresh) {
        if (!hasActiveDocument)
            return ""

        if (!forceRefresh) {
            var cached = activeDocumentReflowText()
            if (cached.length > 0)
                return cached
        }

        if (!ensureActiveDocumentBackendLoaded())
            return ""

        reflowLoading = true
        var extracted = String(pdfDocument.extractDocumentText() || "")
        reflowLoading = false
        documentModel.setProperty(activeDocumentIndex, "reflowText", extracted)
        return extracted
    }

    function activePageText(forceRefresh) {
        if (!hasActiveDocument)
            return ""

        if (!forceRefresh) {
            var cache = readActiveDocumentPageTextCache()
            var cached = String(cache[String(activePageIndex)] || "")
            if (cached.length > 0)
                return cached
        }

        if (!ensureActiveDocumentBackendLoaded())
            return ""

        var sourcePage = sourcePageForActivePage(activePageIndex)
        if (sourcePage < 0)
            return ""

        var extracted = String(pdfDocument.extractPageText(sourcePage) || "")
        var nextCache = readActiveDocumentPageTextCache()
        nextCache[String(activePageIndex)] = extracted
        writeActiveDocumentPageTextCache(nextCache)
        return extracted
    }

    function refreshReadingPanelText(forceRefresh) {
        if (!hasActiveDocument) {
            readingPanelText = ""
            readingPanelTextLoading = false
            return ""
        }

        readingPanelTextLoading = true
        var nextText = reflowModeEnabled
                     ? ensureActiveDocumentReflowText(forceRefresh)
                     : activePageText(forceRefresh)
        readingPanelText = String(nextText || "")
        readingPanelTextLoading = false
        return readingPanelText
    }

    function copyTextToClipboard(text, successMessage, emptyMessage) {
        var plain = String(text || "").trim()
        if (plain.length === 0) {
            saveMessage = emptyMessage || "No hay texto extraible en este PDF."
            return
        }

        if (desktopIntegration.setClipboardText(plain))
            saveMessage = successMessage
        else
            saveMessage = "No se pudo copiar el texto."
    }

    function copySelectedText() {
        copyTextToClipboard(pdfViewer ? pdfViewer.selectedText : "", "Texto seleccionado copiado.", "No hay texto seleccionado.")
    }

    function copyVisibleText() {
        if (reflowModeEnabled)
            copyTextToClipboard(ensureActiveDocumentReflowText(false), "Texto del documento copiado.", "Este PDF no tiene texto extraible para reflow.")
        else if (pdfViewer && String(pdfViewer.selectedText || "").trim().length > 0)
            copySelectedText()
        else
            copyTextToClipboard(activePageText(false), "Texto de la pagina copiado.", "La pagina actual no tiene texto extraible.")
    }

    function setHandToolEnabled(enabled) {
        handToolEnabled = !!enabled
        if (handToolEnabled)
            reflowModeEnabled = false
    }

    function toggleReadingFullscreen() {
        if (!hasActiveDocument)
            return

        if (presentationModeEnabled)
            togglePresentationMode()

        readingFullscreenEnabled = !readingFullscreenEnabled
        if (readingFullscreenEnabled)
            visibility = Window.FullScreen
        else if (visibility === Window.FullScreen)
            visibility = Window.Maximized
    }

    function exitImmersiveModes() {
        if (presentationModeEnabled) {
            togglePresentationMode()
            return
        }

        if (readingFullscreenEnabled)
            toggleReadingFullscreen()
    }

    function togglePresentationMode() {
        if (!hasActiveDocument)
            return

        if (!presentationModeEnabled) {
            presentationRestoreZoom = viewerZoom
            presentationRestoreLayoutMode = layoutMode
            presentationRestoreZoomMode = zoomMode
            presentationRestoreNavigationPanelVisible = navigationPanelVisible
            presentationRestoreSidePanelMode = navigationSidePanelMode
            presentationRestoreHandToolEnabled = handToolEnabled
            presentationRestoreReflowModeEnabled = reflowModeEnabled

            presentationModeEnabled = true
            readingFullscreenEnabled = true
            reflowModeEnabled = false
            handToolEnabled = false
            navigationPanelVisible = false
            layoutMode = "single"
            zoomMode = "fitPage"
            viewerZoom = 1.0
            syncActiveDocumentState()
            visibility = Window.FullScreen
            jumpToPageRequested(activePageIndex)
            return
        }

        presentationModeEnabled = false
        readingFullscreenEnabled = false
        layoutMode = presentationRestoreLayoutMode
        zoomMode = presentationRestoreZoomMode
        viewerZoom = normalizedZoom(presentationRestoreZoom)
        navigationPanelVisible = presentationRestoreNavigationPanelVisible
        navigationSidePanelMode = presentationRestoreSidePanelMode
        handToolEnabled = presentationRestoreHandToolEnabled
        reflowModeEnabled = presentationRestoreReflowModeEnabled
        syncActiveDocumentState()
        if (visibility === Window.FullScreen)
            visibility = Window.Maximized
        jumpToPageRequested(activePageIndex)
    }

    function toggleReflowMode() {
        if (!hasActiveDocument)
            return

        if (reflowModeEnabled) {
            reflowModeEnabled = false
            refreshReadingPanelText(false)
            return
        }

        var text = ensureActiveDocumentReflowText(false)
        if (text.trim().length === 0) {
            saveMessage = "Este PDF no tiene texto extraible para reflow."
            return
        }

        reflowModeEnabled = true
        handToolEnabled = false
        refreshReadingPanelText(false)
    }

    function setSearchQuery(query) {
        if (!hasActiveDocument)
            return

        documentModel.setProperty(activeDocumentIndex, "searchQuery", String(query || ""))
        updateActiveSearchResults()
    }

    function clearSearch() {
        if (!hasActiveDocument)
            return

        documentModel.setProperty(activeDocumentIndex, "searchQuery", "")
        documentModel.setProperty(activeDocumentIndex, "searchResultsJson", "[]")
        documentModel.setProperty(activeDocumentIndex, "activeSearchResultIndex", -1)
        documentModel.setProperty(activeDocumentIndex, "searchInProgress", false)
        if (navigationSidePanelMode === "search")
            navigationSidePanelMode = "thumbnails"
        saveMessage = ""
        syncActiveDocumentState()

        if (typeof pageSearchField !== "undefined") {
            pageSearchField.text = ""
            pageSearchField.forceActiveFocus()
        }
    }

    function closeSearchOverlay(clearQuery) {
        searchOverlayVisible = false
        if (clearQuery)
            clearSearch()
    }

    function focusSearchField() {
        if (typeof pageSearchField === "undefined")
            return

        searchOverlayVisible = true
        pageSearchField.forceActiveFocus()
        pageSearchField.selectAll()
    }

    function activateSearchResult(index, addHistory) {
        if (!hasActiveDocument)
            return

        var targetIndex = Number(index)
        var result = activeDocumentSearchResult(targetIndex)
        if (!result)
            return

        documentModel.setProperty(activeDocumentIndex, "activeSearchResultIndex", targetIndex)
        navigationPanelVisible = true
        navigationSidePanelMode = "search"
        pendingSearchFocusResult = result
        syncActiveDocumentState()
        navigateToDocumentPage(Number(result.pageIndex), !!addHistory)
    }

    function goToNextSearchResult() {
        var count = activeDocumentSearchResultCount()
        if (count <= 0)
            return

        var next = activeDocumentSearchResultIndex() + 1
        if (next >= count)
            next = 0
        activateSearchResult(next, true)
    }

    function goToPreviousSearchResult() {
        var count = activeDocumentSearchResultCount()
        if (count <= 0)
            return

        var previous = activeDocumentSearchResultIndex() - 1
        if (previous < 0)
            previous = count - 1
        activateSearchResult(previous, true)
    }

    function toggleSearchPanel() {
        if (!hasActiveDocument)
            return

        if (!navigationPanelVisible) {
            navigationPanelVisible = true
            navigationSidePanelMode = "search"
            syncActiveDocumentState()
            return
        }

        if (navigationSidePanelMode !== "search") {
            navigationSidePanelMode = "search"
            syncActiveDocumentState()
            return
        }

        navigationPanelVisible = false
        syncActiveDocumentState()
    }

    function setSidePanelMode(mode) {
        if (mode !== "thumbnails" && mode !== "outline" && mode !== "search")
            return

        navigationSidePanelMode = mode
        syncActiveDocumentState()
    }

    function setPageSnapEnabled(enabled) {
        pageSnapEnabled = !!enabled
        syncActiveDocumentState()
    }

    function setPageSpacing(value) {
        var spacing = Math.max(0, Math.min(48, Number(value)))
        if (isNaN(spacing))
            return

        pageSpacing = Math.round(spacing)
        syncActiveDocumentState()
    }

    function navigateToDocumentPage(index, addHistory) {
        if (!hasActiveDocument)
            return

        var target = Math.max(0, Math.min(Number(index), activeDocumentPageCount() - 1))
        if (isNaN(target))
            return
        var shouldUseLargeJumpRoute = isLargePageJump(target)

        if (addHistory && target !== activePageIndex) {
            var back = activeDocumentHistoryBack()
            back.push(activePageIndex)
            documentModel.setProperty(activeDocumentIndex, "historyBackJson", JSON.stringify(trimHistoryEntries(back)))
            documentModel.setProperty(activeDocumentIndex, "historyForwardJson", "[]")
        }

        if (shouldUseLargeJumpRoute && pdfViewer)
            pdfViewer.beginLargeJump(target, largeJumpPreviewScale)

        activePageIndex = target
        syncActiveDocumentState()
        Qt.callLater(function() {
            jumpToPageRequested(activePageIndex)
        })
    }

    function goBackInDocument() {
        if (!hasActiveDocument)
            return

        var back = activeDocumentHistoryBack()
        if (back.length === 0)
            return

        var forward = activeDocumentHistoryForward()
        forward.push(activePageIndex)
        var target = back.pop()
        documentModel.setProperty(activeDocumentIndex, "historyBackJson", JSON.stringify(trimHistoryEntries(back)))
        documentModel.setProperty(activeDocumentIndex, "historyForwardJson", JSON.stringify(trimHistoryEntries(forward)))
        activePageIndex = Math.max(0, Math.min(target, activeDocumentPageCount() - 1))
        syncActiveDocumentState()
        Qt.callLater(function() {
            jumpToPageRequested(activePageIndex)
        })
    }

    function goForwardInDocument() {
        if (!hasActiveDocument)
            return

        var forward = activeDocumentHistoryForward()
        if (forward.length === 0)
            return

        var back = activeDocumentHistoryBack()
        back.push(activePageIndex)
        var target = forward.pop()
        documentModel.setProperty(activeDocumentIndex, "historyBackJson", JSON.stringify(trimHistoryEntries(back)))
        documentModel.setProperty(activeDocumentIndex, "historyForwardJson", JSON.stringify(trimHistoryEntries(forward)))
        activePageIndex = Math.max(0, Math.min(target, activeDocumentPageCount() - 1))
        syncActiveDocumentState()
        Qt.callLater(function() {
            jumpToPageRequested(activePageIndex)
        })
    }

    function activateLinkTarget(uri, pageIndex) {
        var targetUri = String(uri || "")
        var targetPage = Number(pageIndex)

        if (targetPage >= 0) {
            navigateToDocumentPage(targetPage, true)
            return
        }

        if (targetUri.length === 0)
            return

        if (targetUri.indexOf(":") >= 0) {
            Qt.openUrlExternally(targetUri)
            return
        }

        var doc = documentModel.get(activeDocumentIndex)
        if (pdfDocument.filePath !== doc.path && !loadPdfWithPasswordPrompt(doc.path, doc.password || ""))
            return

        var resolvedPage = pdfDocument.resolveLinkPage(targetUri)
        if (resolvedPage >= 0) {
            var visiblePage = visibleIndexForSourcePage(doc, resolvedPage)
            if (visiblePage >= 0)
                navigateToDocumentPage(visiblePage, true)
        }
    }

    function moveDocument(from, to) {
        var count = documentModel.count
        if (count <= 1 || from < 0 || from >= count || to < 0 || to > count)
            return

        var insertIndex = Math.max(0, Math.min(Number(to), count))
        if (!isFinite(insertIndex))
            return

        if (insertIndex > from)
            insertIndex -= 1

        if (insertIndex === from)
            return

        var activePath = hasActiveDocument ? String(documentModel.get(activeDocumentIndex).path || "") : ""
        documentModel.move(from, insertIndex, 1)

        var nextActiveIndex = findDocumentIndexByPath(activePath)
        if (nextActiveIndex < 0)
            nextActiveIndex = Math.max(0, Math.min(insertIndex, documentModel.count - 1))

        if (nextActiveIndex >= 0 && nextActiveIndex < documentModel.count) {
            activeDocumentIndex = nextActiveIndex

            if (pdfDocument.filePath !== activePath)
                setActiveDocument(nextActiveIndex)
        }
    }

    function toggleNavigationPanel() {
        navigationPanelVisible = !navigationPanelVisible
        syncActiveDocumentState()
    }

    function itemContainsFocus(item) {
        if (!item)
            return false

        var current = window.activeFocusItem
        while (current) {
            if (current === item)
                return true
            current = current.parent
        }
        return false
    }

    function tabsPaneHasFocus() {
        if (itemContainsFocus(newTabButton))
            return true

        var tabChildren = tabsRow && tabsRow.children ? tabsRow.children : []
        for (var i = 0; i < tabChildren.length; ++i) {
            var child = tabChildren[i]
            if (child && child.objectName === "documentTab" && itemContainsFocus(child))
                return true
        }

        return false
    }

    function currentPaneFocusKey() {
        if (!hasActiveDocument)
            return itemContainsFocus(homeOpenButton) ? "home" : "toolbar"

        if (itemContainsFocus(homeToolbarButton)
                || itemContainsFocus(navigationPanelButton)
                || itemContainsFocus(shortcutsButton)
                || itemContainsFocus(themeButton)
                || itemContainsFocus(defaultPdfButton)) {
            return "toolbar"
        }

        if (tabsPaneHasFocus())
            return "tabs"

        if (itemContainsFocus(thumbnailsModeButton)
                || itemContainsFocus(outlineModeButton)
                || itemContainsFocus(pageSearchField)) {
            return "side"
        }

        if (itemContainsFocus(pdfViewer) || itemContainsFocus(reflowTextArea))
            return "viewer"

        return "toolbar"
    }

    function paneFocusOrder() {
        if (!hasActiveDocument)
            return ["toolbar", "home"]

        var order = ["toolbar", "tabs"]
        if (navigationPanelVisible)
            order.push("side")
        order.push("viewer")
        return order
    }

    function focusPaneByKey(key) {
        if (key === "home") {
            if (!hasActiveDocument && homeOpenButton) {
                homeOpenButton.forceActiveFocus()
                return true
            }
            return false
        }

        if (key === "toolbar") {
            if (homeToolbarButton && homeToolbarButton.visible) {
                homeToolbarButton.forceActiveFocus()
                return true
            }
            if (navigationPanelButton && navigationPanelButton.visible) {
                navigationPanelButton.forceActiveFocus()
                return true
            }
            if (shortcutsButton) {
                shortcutsButton.forceActiveFocus()
                return true
            }
            return false
        }

        if (key === "tabs") {
            if (hasActiveDocument && newTabButton) {
                newTabButton.forceActiveFocus()
                return true
            }
            return false
        }

        if (key === "side") {
            if (!hasActiveDocument || !navigationPanelVisible)
                return false

            if (searchOverlayVisible && pageSearchField) {
                pageSearchField.forceActiveFocus()
                pageSearchField.selectAll()
                return true
            }

            if (navigationSidePanelMode === "outline" && outlineModeButton) {
                outlineModeButton.forceActiveFocus()
                return true
            }

            if (thumbnailsModeButton) {
                thumbnailsModeButton.forceActiveFocus()
                return true
            }

            return false
        }

        if (key === "viewer") {
            if (hasActiveDocument && reflowModeEnabled && reflowTextArea) {
                reflowTextArea.forceActiveFocus()
                return true
            }

            if (hasActiveDocument && pdfViewer) {
                pdfViewer.forceActiveFocus()
                return true
            }

            return false
        }

        return false
    }

    function cyclePaneFocus(step) {
        var order = paneFocusOrder()
        if (order.length === 0)
            return

        var currentKey = currentPaneFocusKey()
        var currentIndex = order.indexOf(currentKey)
        if (currentIndex < 0)
            currentIndex = 0

        var direction = step < 0 ? -1 : 1
        for (var offset = 1; offset <= order.length; ++offset) {
            var nextIndex = (currentIndex + direction * offset + order.length) % order.length
            if (focusPaneByKey(order[nextIndex]))
                return
        }

        focusPaneByKey(order[0])
    }

    function saveActiveDocumentRotated() {
        if (!hasActiveDocument)
            return

        saveDocumentChanges(activeDocumentIndex, documentModel.get(activeDocumentIndex).path, true)
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
        navigateToDocumentPage(index, true)
    }

    function reportActivePage(index) {
        var page = Number(index)
        if (isNaN(page))
            return

        var target = Math.max(0, Math.min(page, activeDocumentPageCount() - 1))
        if (target === activePageIndex)
            return

        activePageIndex = target
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

    function rotateDocumentPage(pageIndex, delta) {
        if (!hasActiveDocument || delta === 0)
            return

        var doc = documentModel.get(activeDocumentIndex)
        var rotations = parseJsonArray(doc.pageRotationsJson || "[]", [])
        while (rotations.length < Number(doc.pageCount || 0))
            rotations.push(0)

        var sourcePage = sourcePageForDocumentIndex(doc, pageIndex)
        if (sourcePage < 0)
            return

        var nextState = captureDocumentEditState(doc)
        while (nextState.pageRotations.length < Number(doc.pageCount || 0))
            nextState.pageRotations.push(0)
        nextState.pageRotations[sourcePage] = (Number(nextState.pageRotations[sourcePage] || 0) + delta + 360) % 360

        if (!commitDocumentEdit(activeDocumentIndex, nextState, sourcePage))
            return

        requestActivePageRender(pageIndex, pdfViewer ? pdfViewer.renderScale : 2.5)
        requestActiveThumbnailRender(pageIndex)
    }

    function rotateCurrentPage(delta) {
        rotateDocumentPage(activePageIndex, delta)
    }

    function moveActiveDocumentPage(fromIndex, toIndex) {
        if (!hasActiveDocument)
            return

        var doc = documentModel.get(activeDocumentIndex)
        var order = normalizedDocumentPageOrder(doc)
        var from = Math.max(0, Math.min(Number(fromIndex), order.length - 1))
        var to = Math.max(0, Math.min(Number(toIndex), order.length - 1))
        if (!isFinite(from) || !isFinite(to) || from === to)
            return

        var sourcePage = Number(order[from])
        order.splice(from, 1)
        order.splice(to, 0, sourcePage)

        var nextState = captureDocumentEditState(doc)
        nextState.pageOrder = order
        commitDocumentEdit(activeDocumentIndex, nextState, sourcePage)
    }

    function deleteActiveDocumentPage(pageIndex) {
        if (!hasActiveDocument)
            return

        var doc = documentModel.get(activeDocumentIndex)
        var order = normalizedDocumentPageOrder(doc)
        if (order.length <= 1)
            return

        var target = Math.max(0, Math.min(Number(pageIndex), order.length - 1))
        if (!isFinite(target))
            return

        order.splice(target, 1)
        var nextState = captureDocumentEditState(doc)
        nextState.pageOrder = order
        commitDocumentEdit(activeDocumentIndex, nextState, sourcePageForDocumentIndex(doc, pageIndex))
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            visible: !window.readingFullscreenEnabled && !window.presentationModeEnabled
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
                    id: shortcutsButton
                    text: "⌨"
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 34
                    onClicked: shortcutsPopup.visible ? shortcutsPopup.close() : shortcutsPopup.open()
                    ToolTip.visible: hovered
                    ToolTip.text: "Ver atajos y gestos"

                    contentItem: Text {
                        text: shortcutsButton.text
                        color: Theme.text
                        font.pixelSize: 17
                        font.weight: Font.Medium
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    background: Rectangle {
                        color: shortcutsButton.down ? Theme.tabActive
                              : shortcutsButton.hovered ? Theme.hover
                              : Theme.surfaceAlt
                        border.color: shortcutsButton.activeFocus ? Theme.accent : Theme.border
                        border.width: shortcutsButton.activeFocus ? 2 : 1
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
            visible: documentModel.count > 0 && !window.readingFullscreenEnabled && !window.presentationModeEnabled
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

                Flickable {
                    id: tabsFlickable
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: tabsRow.width
                    contentHeight: height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: tabsRow
                        spacing: 4
                        height: tabsFlickable.height

                        Repeater {
                            model: documentModel

                            Rectangle {
                                id: documentTab
                                required property int index
                                required property string title
                                property real lastDragCenterX: 0

                                objectName: "documentTab"
                                width: Math.min(240, Math.max(150, tabTitle.implicitWidth + 48))
                                height: tabsFlickable.height
                                color: window.activeDocumentIndex === index ? Theme.background : Theme.surfaceAlt
                                border.color: window.activeDocumentIndex === index ? Theme.accent : Theme.border
                                border.width: window.activeDocumentIndex === index ? 2 : 1
                                radius: Theme.radius
                                z: tabDragHandler.active ? 10 : 1
                                transform: Translate {
                                    x: tabDragHandler.active ? tabDragHandler.translation.x : 0
                                }

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
                                        onClicked: window.closeDocumentAt(documentTab.index)
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

                                TapHandler {
                                    acceptedButtons: Qt.MiddleButton
                                    onTapped: window.closeDocumentAt(documentTab.index)
                                }

                                DragHandler {
                                    id: tabDragHandler
                                    target: null
                                    xAxis.enabled: true
                                    yAxis.enabled: false
                                    onActiveChanged: {
                                        if (active) {
                                            documentTab.lastDragCenterX = documentTab.x + documentTab.width / 2
                                        } else {
                                            documentTab.lastDragCenterX = 0
                                        }
                                    }
                                    onTranslationChanged: {
                                        var dragDistance = Math.abs(tabDragHandler.translation.x)
                                        if (dragDistance < 18)
                                            return

                                        var centerX = documentTab.x + tabDragHandler.translation.x + documentTab.width / 2
                                        if (Math.abs(centerX - documentTab.lastDragCenterX) < 6)
                                            return

                                        var targetIndex = documentTab.index
                                        for (var i = 0; i < tabsRow.children.length; ++i) {
                                            var child = tabsRow.children[i]
                                            if (!child || child === documentTab || child.objectName !== "documentTab" || child.width === undefined)
                                                continue

                                            var childCenter = child.x + child.width / 2
                                            if (centerX < childCenter) {
                                                targetIndex = child.index
                                                break
                                            }

                                            targetIndex = child.index + 1
                                        }

                                        documentTab.lastDragCenterX = centerX
                                        window.moveDocument(documentTab.index, targetIndex)
                                    }
                                }
                            }
                        }

                        Button {
                            id: newTabButton
                            width: 34
                            height: tabsFlickable.height
                            text: "+"
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
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 88
            visible: window.hasActiveDocument && !window.readingFullscreenEnabled && !window.presentationModeEnabled
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

                        Row {
                            Layout.alignment: Qt.AlignBottom
                            spacing: 4

                            Button {
                                id: viewTabButton
                                text: "Vista"
                                width: 58
                                height: 28
                                onClicked: window.topToolbarMenu = "view"

                                contentItem: Text {
                                    text: viewTabButton.text
                                    color: window.topToolbarMenu === "view" ? Theme.accentText : Theme.text
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    color: window.topToolbarMenu === "view" ? Theme.accent
                                          : viewTabButton.down ? Theme.tabActive
                                          : viewTabButton.hovered ? Theme.hover
                                          : Theme.background
                                    border.color: viewTabButton.activeFocus ? Theme.accent : Theme.border
                                    border.width: viewTabButton.activeFocus ? 2 : 1
                                    radius: Theme.radius
                                }
                            }

                            Button {
                                id: editTabButton
                                text: "Editar"
                                width: 64
                                height: 28
                                onClicked: window.topToolbarMenu = "edit"
                                ToolTip.visible: hovered
                                ToolTip.text: "Espacio reservado para futuras herramientas de edicion"

                                contentItem: Text {
                                    text: editTabButton.text
                                    color: window.topToolbarMenu === "edit" ? Theme.accentText : Theme.text
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                background: Rectangle {
                                    color: window.topToolbarMenu === "edit" ? Theme.accent
                                          : editTabButton.down ? Theme.tabActive
                                          : editTabButton.hovered ? Theme.hover
                                          : Theme.background
                                    border.color: editTabButton.activeFocus ? Theme.accent : Theme.border
                                    border.width: editTabButton.activeFocus ? 2 : 1
                                    radius: Theme.radius
                                }
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
                        visible: window.topToolbarMenu === "view"
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 12
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
                            enabled: window.activeDocumentHasPendingChanges()
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
                            enabled: window.activeDocumentHasPendingChanges()
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 30
                            onClicked: saveRotatedDialog.open()
                            ToolTip.visible: hovered
                            ToolTip.text: "Guardar copia editada"

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

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            color: Theme.border
                        }

                        Button {
                            id: searchViewButton
                            text: ""
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 30
                            onClicked: window.focusSearchField()
                            ToolTip.visible: hovered
                            ToolTip.text: "Buscar en documento (Ctrl+F)"

                            contentItem: Canvas {
                                id: searchViewIcon
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                property color strokeColor: Theme.text
                                function repaintIfReady() {
                                    if (available && visible && width > 0 && height > 0)
                                        requestPaint()
                                }

                                onStrokeColorChanged: requestPaint()
                                onAvailableChanged: repaintIfReady()
                                onVisibleChanged: repaintIfReady()
                                onWidthChanged: repaintIfReady()
                                onHeightChanged: repaintIfReady()
                                Component.onCompleted: repaintIfReady()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.strokeStyle = strokeColor
                                    ctx.lineWidth = 1.7

                                    ctx.beginPath()
                                    ctx.arc(7.5, 7.5, 4.2, 0, Math.PI * 2)
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.moveTo(10.8, 10.8)
                                    ctx.lineTo(15, 15)
                                    ctx.stroke()
                                }
                            }

                            background: Rectangle {
                                color: searchViewButton.down ? Theme.tabActive
                                      : searchViewButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: searchViewButton.activeFocus ? Theme.accent : Theme.border
                                border.width: searchViewButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            color: Theme.border
                        }

                        Button {
                            id: copyTextButton
                            text: "Txt"
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 30
                            onClicked: window.copyVisibleText()
                            ToolTip.visible: hovered
                            ToolTip.text: "Copia texto seleccionado o, si no hay seleccion, el texto visible del PDF."

                            contentItem: Canvas {
                                id: copyTextIcon
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                property color strokeColor: copyTextButton.enabled ? Theme.text : Theme.secondaryText
                                function repaintIfReady() {
                                    if (available && visible && width > 0 && height > 0)
                                        requestPaint()
                                }

                                onStrokeColorChanged: requestPaint()
                                onAvailableChanged: repaintIfReady()
                                onVisibleChanged: repaintIfReady()
                                onWidthChanged: repaintIfReady()
                                onHeightChanged: repaintIfReady()
                                Component.onCompleted: repaintIfReady()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.strokeStyle = strokeColor
                                    ctx.lineWidth = 1.5

                                    ctx.beginPath()
                                    ctx.moveTo(5, 4)
                                    ctx.lineTo(12, 4)
                                    ctx.lineTo(15, 7)
                                    ctx.lineTo(15, 15)
                                    ctx.lineTo(5, 15)
                                    ctx.closePath()
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.moveTo(3, 2.5)
                                    ctx.lineTo(10, 2.5)
                                    ctx.lineTo(10, 4.5)
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.moveTo(7, 8)
                                    ctx.lineTo(12, 8)
                                    ctx.moveTo(7, 10.5)
                                    ctx.lineTo(12, 10.5)
                                    ctx.moveTo(7, 13)
                                    ctx.lineTo(10.5, 13)
                                    ctx.stroke()
                                }
                            }

                            background: Rectangle {
                                color: copyTextButton.down ? Theme.tabActive
                                      : copyTextButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: copyTextButton.activeFocus ? Theme.accent : Theme.border
                                border.width: copyTextButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                            }
                        }

                        Button {
                            id: reflowToggleButton
                            text: "Reflow"
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 30
                            onClicked: window.toggleReflowMode()
                            ToolTip.visible: hovered
                            ToolTip.text: "Recompone el texto en lectura continua para leer mejor en pantalla."

                            contentItem: Canvas {
                                id: reflowIcon
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                property color strokeColor: window.reflowModeEnabled ? Theme.accentText : Theme.text
                                function repaintIfReady() {
                                    if (available && visible && width > 0 && height > 0)
                                        requestPaint()
                                }

                                onStrokeColorChanged: requestPaint()
                                onAvailableChanged: repaintIfReady()
                                onVisibleChanged: repaintIfReady()
                                onWidthChanged: repaintIfReady()
                                onHeightChanged: repaintIfReady()
                                Component.onCompleted: repaintIfReady()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.strokeStyle = strokeColor
                                    ctx.lineWidth = 1.7

                                    ctx.beginPath()
                                    ctx.moveTo(3, 5)
                                    ctx.lineTo(13, 5)
                                    ctx.moveTo(3, 9)
                                    ctx.lineTo(10, 9)
                                    ctx.moveTo(3, 13)
                                    ctx.lineTo(13, 13)
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.moveTo(12, 7)
                                    ctx.lineTo(15, 9)
                                    ctx.lineTo(12, 11)
                                    ctx.stroke()
                                }
                            }

                            background: Rectangle {
                                color: window.reflowModeEnabled ? Theme.accent
                                      : reflowToggleButton.down ? Theme.tabActive
                                      : reflowToggleButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: reflowToggleButton.activeFocus ? Theme.accent : Theme.border
                                border.width: reflowToggleButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                            }
                        }

                        Button {
                            id: handToolButton
                            text: "Mano"
                            enabled: !window.reflowModeEnabled
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 30
                            onClicked: window.setHandToolEnabled(!window.handToolEnabled)
                            ToolTip.visible: hovered
                            ToolTip.text: "Activa arrastre manual del PDF y mantiene cursor de mano para mover paginas."

                            contentItem: Canvas {
                                id: handToolIcon
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                property color strokeColor: handToolButton.enabled
                                                            ? (window.handToolEnabled ? Theme.accentText : Theme.text)
                                                            : Theme.secondaryText
                                function repaintIfReady() {
                                    if (available && visible && width > 0 && height > 0)
                                        requestPaint()
                                }

                                onStrokeColorChanged: requestPaint()
                                onAvailableChanged: repaintIfReady()
                                onVisibleChanged: repaintIfReady()
                                onWidthChanged: repaintIfReady()
                                onHeightChanged: repaintIfReady()
                                Component.onCompleted: repaintIfReady()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.strokeStyle = strokeColor
                                    ctx.lineWidth = 1.5

                                    ctx.beginPath()
                                    ctx.moveTo(6, 15)
                                    ctx.lineTo(6, 6)
                                    ctx.moveTo(9, 15)
                                    ctx.lineTo(9, 4.5)
                                    ctx.moveTo(12, 15)
                                    ctx.lineTo(12, 5)
                                    ctx.moveTo(15, 14)
                                    ctx.lineTo(15, 7)
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.moveTo(4, 10)
                                    ctx.lineTo(4, 15)
                                    ctx.quadraticCurveTo(4.5, 16.5, 6.2, 16.5)
                                    ctx.lineTo(13.8, 16.5)
                                    ctx.quadraticCurveTo(16.2, 16.5, 16.2, 14)
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.moveTo(6, 11.5)
                                    ctx.lineTo(2.8, 9.8)
                                    ctx.lineTo(2.2, 12.3)
                                    ctx.lineTo(4, 13.8)
                                    ctx.stroke()
                                }
                            }

                            background: Rectangle {
                                color: window.handToolEnabled ? Theme.accent
                                      : handToolButton.down ? Theme.tabActive
                                      : handToolButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: handToolButton.activeFocus ? Theme.accent : Theme.border
                                border.width: handToolButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                                opacity: handToolButton.enabled ? 1.0 : 0.55
                            }
                        }

                        Button {
                            id: readingFullscreenButton
                            text: "Leer"
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 30
                            onClicked: window.toggleReadingFullscreen()
                            ToolTip.visible: hovered
                            ToolTip.text: "Abre modo lectura sin distracciones para concentrarte en el documento."

                            contentItem: Canvas {
                                id: readingFullscreenIcon
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                property color strokeColor: window.readingFullscreenEnabled ? Theme.accentText : Theme.text
                                function repaintIfReady() {
                                    if (available && visible && width > 0 && height > 0)
                                        requestPaint()
                                }

                                onStrokeColorChanged: requestPaint()
                                onAvailableChanged: repaintIfReady()
                                onVisibleChanged: repaintIfReady()
                                onWidthChanged: repaintIfReady()
                                onHeightChanged: repaintIfReady()
                                Component.onCompleted: repaintIfReady()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.strokeStyle = strokeColor
                                    ctx.lineWidth = 1.5

                                    ctx.beginPath()
                                    ctx.moveTo(3, 4)
                                    ctx.quadraticCurveTo(5.5, 3, 8, 4.2)
                                    ctx.lineTo(8, 14.5)
                                    ctx.quadraticCurveTo(5.5, 13.3, 3, 14.3)
                                    ctx.closePath()
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.moveTo(15, 4)
                                    ctx.quadraticCurveTo(12.5, 3, 10, 4.2)
                                    ctx.lineTo(10, 14.5)
                                    ctx.quadraticCurveTo(12.5, 13.3, 15, 14.3)
                                    ctx.closePath()
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.moveTo(9, 4)
                                    ctx.lineTo(9, 14.5)
                                    ctx.stroke()
                                }
                            }

                            background: Rectangle {
                                color: window.readingFullscreenEnabled ? Theme.accent
                                      : readingFullscreenButton.down ? Theme.tabActive
                                      : readingFullscreenButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: readingFullscreenButton.activeFocus ? Theme.accent : Theme.border
                                border.width: readingFullscreenButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                            }
                        }

                        Button {
                            id: presentationButton
                            text: "Show"
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 30
                            onClicked: window.togglePresentationMode()
                            ToolTip.visible: hovered
                            ToolTip.text: "Activa modo presentacion para enseñar el PDF con interfaz minima."

                            contentItem: Canvas {
                                id: presentationIcon
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                property color strokeColor: window.presentationModeEnabled ? Theme.accentText : Theme.text
                                function repaintIfReady() {
                                    if (available && visible && width > 0 && height > 0)
                                        requestPaint()
                                }

                                onStrokeColorChanged: requestPaint()
                                onAvailableChanged: repaintIfReady()
                                onVisibleChanged: repaintIfReady()
                                onWidthChanged: repaintIfReady()
                                onHeightChanged: repaintIfReady()
                                Component.onCompleted: repaintIfReady()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.lineCap = "round"
                                    ctx.lineJoin = "round"
                                    ctx.strokeStyle = strokeColor
                                    ctx.lineWidth = 1.5

                                    ctx.beginPath()
                                    ctx.moveTo(3, 4)
                                    ctx.lineTo(15, 4)
                                    ctx.lineTo(15, 12)
                                    ctx.lineTo(3, 12)
                                    ctx.closePath()
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.moveTo(9, 12)
                                    ctx.lineTo(9, 15.5)
                                    ctx.moveTo(6.5, 15.5)
                                    ctx.lineTo(11.5, 15.5)
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.moveTo(7, 6.8)
                                    ctx.lineTo(11, 8)
                                    ctx.lineTo(7, 9.2)
                                    ctx.closePath()
                                    ctx.stroke()
                                }
                            }

                            background: Rectangle {
                                color: window.presentationModeEnabled ? Theme.accent
                                      : presentationButton.down ? Theme.tabActive
                                      : presentationButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: presentationButton.activeFocus ? Theme.accent : Theme.border
                                border.width: presentationButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }

                    RowLayout {
                        visible: window.topToolbarMenu === "edit"
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 12
                            topMargin: 8
                            bottomMargin: 8
                        }
                        spacing: 8

                        EditToolbar {
                            currentTool: window.activeEditTool
                            canUndo: window.activeDocumentCanUndoEdits()
                            canRedo: window.activeDocumentCanRedoEdits()
                            Layout.preferredWidth: Math.min(540, implicitWidth)
                            Layout.preferredHeight: 30
                            onUndoRequested: window.undoActiveDocumentEdit()
                            onRedoRequested: window.redoActiveDocumentEdit()
                            onToolSelected: function(toolName) {
                                window.activeEditTool = toolName
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            color: Theme.border
                        }

                        Button {
                            id: editTextToolButton
                            text: "T"
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 30
                            onClicked: window.activeEditTool = "text"
                            ToolTip.visible: hovered
                            ToolTip.text: "Editar texto"
                            contentItem: Text {
                                text: editTextToolButton.text
                                color: window.activeEditTool === "text" ? Theme.accentText : Theme.text
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: window.activeEditTool === "text" ? Theme.accent
                                      : editTextToolButton.down ? Theme.tabActive
                                      : editTextToolButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: editTextToolButton.activeFocus ? Theme.accent : Theme.border
                                border.width: editTextToolButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                            }
                        }

                        Button {
                            id: editHighlightToolButton
                            text: ""
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 30
                            onClicked: window.activeEditTool = "highlight"
                            ToolTip.visible: hovered
                            ToolTip.text: "Rotulador"
                            contentItem: Canvas {
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.strokeStyle = window.activeEditTool === "highlight" ? Theme.accentText : Theme.text
                                    ctx.fillStyle = window.editHighlightColor
                                    ctx.lineWidth = 2
                                    ctx.fillRect(8, 17, 18, 5)
                                    ctx.beginPath()
                                    ctx.moveTo(10, 10)
                                    ctx.lineTo(20, 20)
                                    ctx.lineTo(24, 16)
                                    ctx.lineTo(14, 6)
                                    ctx.closePath()
                                    ctx.stroke()
                                }
                                Connections {
                                    target: window
                                    function onActiveEditToolChanged() { parent.requestPaint() }
                                    function onEditHighlightColorChanged() { parent.requestPaint() }
                                }
                            }
                            background: Rectangle {
                                color: window.activeEditTool === "highlight" ? Theme.accent
                                      : editHighlightToolButton.down ? Theme.tabActive
                                      : editHighlightToolButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: editHighlightToolButton.activeFocus ? Theme.accent : Theme.border
                                border.width: editHighlightToolButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                            }
                        }

                        Button {
                            id: editEraseToolButton
                            text: ""
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 30
                            onClicked: window.activeEditTool = "erase"
                            ToolTip.visible: hovered
                            ToolTip.text: "Borrar anotacion"
                            contentItem: Canvas {
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.strokeStyle = window.activeEditTool === "erase" ? Theme.accentText : Theme.text
                                    ctx.lineWidth = 2
                                    ctx.beginPath()
                                    ctx.moveTo(11, 19)
                                    ctx.lineTo(20, 10)
                                    ctx.lineTo(25, 15)
                                    ctx.lineTo(16, 24)
                                    ctx.lineTo(9, 24)
                                    ctx.lineTo(11, 19)
                                    ctx.stroke()
                                }
                                Connections {
                                    target: window
                                    function onActiveEditToolChanged() { parent.requestPaint() }
                                }
                            }
                            background: Rectangle {
                                color: window.activeEditTool === "erase" ? Theme.accent
                                      : editEraseToolButton.down ? Theme.tabActive
                                      : editEraseToolButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: editEraseToolButton.activeFocus ? Theme.accent : Theme.border
                                border.width: editEraseToolButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.fillHeight: true
                            color: Theme.border
                        }

                        ComboBox {
                            id: editFontBox
                            model: [
                                { text: "Helvetica", value: "Helv" },
                                { text: "Times", value: "TiRo" },
                                { text: "Courier", value: "Cour" }
                            ]
                            textRole: "text"
                            valueRole: "value"
                            currentIndex: window.editFontFamily === "Cour" ? 2 : window.editFontFamily === "TiRo" ? 1 : 0
                            Layout.preferredWidth: 118
                            Layout.preferredHeight: 30
                            onActivated: window.editFontFamily = currentValue
                            ToolTip.visible: hovered
                            ToolTip.text: "Fuente"
                        }

                        SpinBox {
                            id: editSizeBox
                            from: 6
                            to: 144
                            value: window.editFontSize
                            Layout.preferredWidth: 70
                            Layout.preferredHeight: 30
                            onValueChanged: window.editFontSize = value
                            ToolTip.visible: hovered
                            ToolTip.text: "Tamano"
                        }

                        Button {
                            id: editTextColorButton
                            text: ""
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 30
                            onClicked: window.editTextColor = window.nextPaletteColor(window.editTextColor, window.editTextColorOptions)
                            ToolTip.visible: hovered
                            ToolTip.text: "Color de texto"
                            contentItem: Rectangle {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                radius: 9
                                color: window.editTextColor
                                border.color: Theme.border
                            }
                        }

                        Button {
                            id: editHighlightColorButton
                            text: ""
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 30
                            onClicked: window.editHighlightColor = window.nextPaletteColor(window.editHighlightColor, window.editHighlightColorOptions)
                            ToolTip.visible: hovered
                            ToolTip.text: "Color del rotulador"
                            contentItem: Rectangle {
                                anchors.centerIn: parent
                                width: 22
                                height: 10
                                radius: 3
                                color: window.editHighlightColor
                                border.color: Theme.border
                            }
                        }

                        Button {
                            id: editBoldButton
                            text: "B"
                            checkable: false
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            onClicked: window.editBoldEnabled = !editBoldEnabled
                            ToolTip.visible: hovered
                            ToolTip.text: "Negrita"
                            contentItem: Text {
                                text: editBoldButton.text
                                color: window.editBoldEnabled ? Theme.accentText : Theme.text
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: window.editBoldEnabled ? Theme.accent
                                      : editBoldButton.down ? Theme.tabActive
                                      : editBoldButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: editBoldButton.activeFocus ? Theme.accent : Theme.border
                                border.width: editBoldButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                            }
                        }

                        Button {
                            id: editItalicButton
                            text: "I"
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            onClicked: window.editItalicEnabled = !editItalicEnabled
                            ToolTip.visible: hovered
                            ToolTip.text: "Cursiva"
                            contentItem: Text {
                                text: editItalicButton.text
                                color: window.editItalicEnabled ? Theme.accentText : Theme.text
                                font.pixelSize: 13
                                font.italic: true
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: window.editItalicEnabled ? Theme.accent
                                      : editItalicButton.down ? Theme.tabActive
                                      : editItalicButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: editItalicButton.activeFocus ? Theme.accent : Theme.border
                                border.width: editItalicButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                            }
                        }

                        Button {
                            id: editUnderlineButton
                            text: "U"
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            onClicked: window.editUnderlineEnabled = !editUnderlineEnabled
                            ToolTip.visible: hovered
                            ToolTip.text: "Subrayado"
                            contentItem: Text {
                                text: editUnderlineButton.text
                                color: window.editUnderlineEnabled ? Theme.accentText : Theme.text
                                font.pixelSize: 13
                                font.underline: true
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: window.editUnderlineEnabled ? Theme.accent
                                      : editUnderlineButton.down ? Theme.tabActive
                                      : editUnderlineButton.hovered ? Theme.hover
                                      : Theme.surfaceAlt
                                border.color: editUnderlineButton.activeFocus ? Theme.accent : Theme.border
                                border.width: editUnderlineButton.activeFocus ? 2 : 1
                                radius: Theme.radius
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    PdfViewer {
                        id: pdfViewer
                        anchors.fill: parent
                        visible: window.hasActiveDocument && !window.reflowModeEnabled
                        opacity: window.documentViewerOpacity()
                        Behavior on opacity {
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                        pdfDocument: pdfDocument
                        pageSources: window.activeDocumentPageSources()
                        thumbnailSources: window.activeDocumentThumbnailSources()
                        outlineEntries: window.activeDocumentOutlineEntries()
                        pageLinks: window.activeDocumentLinksByPage()
                        searchQuery: window.activeDocumentSearchQuery()
                        searchResults: window.activeDocumentSearchResults()
                        activeSearchResultIndex: window.activeDocumentSearchResultIndex()
                        pageCount: window.activeDocumentPageCount()
                        pageSizesJson: window.activeDocumentPageSizesJson()
                        pageRotations: window.activeDocumentPageRotations()
                        currentPageIndex: window.activePageIndex
                        selectedText: pdfDocument.selectionText
                        selectionGeometryJson: pdfDocument.selectionGeometryJson
                        selectionPageIndex: window.activeSelectionVisualPageIndex()
                        viewMode: window.viewMode
                        editTool: window.activeEditTool
                        editAnnotations: window.activeDocumentEditAnnotations()
                        editingController: window.editingController
                        editFontFamily: window.displayEditFontFamily(window.editFontFamily)
                        editFontSize: window.editFontSize
                        editTextColor: window.editTextColor
                        editBold: window.editBoldEnabled
                        editItalic: window.editItalicEnabled
                        editUnderline: window.editUnderlineEnabled
                        editHighlightColor: window.editHighlightColor
                        syncingPdfTextStyle: window.syncingPdfTextStyle
                        zoom: window.viewerZoom
                        layoutMode: window.layoutMode
                        zoomMode: window.zoomMode
                        sidePanelVisible: window.navigationPanelVisible && !window.readingFullscreenEnabled && !window.presentationModeEnabled
                        sidePanelMode: window.navigationSidePanelMode
                        presentationMode: window.presentationModeEnabled
                        handToolEnabled: window.handToolEnabled
                        snapToPage: window.pageSnapEnabled
                        pageSpacing: window.pageSpacing
                        progressiveRenderingEnabled: window.activeDocumentUsesProgressiveRendering()
                        progressivePreviewScale: window.progressivePreviewScale
                        zoomInAction: window.zoomIn
                        zoomOutAction: window.zoomOut
                        requestPageRenderAction: window.requestActivePageRender
                        requestThumbnailRenderAction: window.requestActiveThumbnailRender
                        currentPageChangedAction: window.reportActivePage
                        sidePanelModeChangedAction: window.setSidePanelMode
                        outlineActivatedAction: window.activateLinkTarget
                        linkActivatedAction: window.activateLinkTarget
                        searchResultActivatedAction: function(index) { window.activateSearchResult(index, true) }
                        beginSelectionAction: window.beginActiveSelection
                        updateSelectionAction: window.updateActiveSelection
                        endSelectionAction: pdfDocument.endSelection
                        clearSelectionAction: pdfDocument.clearSelection
                        copySelectionAction: window.copySelectedText
                        textEditSeedAction: window.prepareActiveTextEdit
                        textElementsForPageAction: window.activeTextElementsForPage
                        textBlocksForPageAction: window.activeTextBlocksForPage
                        commitTextEditAction: window.commitActiveTextEdit
                        commitHighlightAction: window.commitActiveHighlightFromSelection
                        createAnnotationAction: window.createActiveEditAnnotation
                        eraseAnnotationAction: window.eraseActiveEditAnnotation
                        movePageAction: window.moveActiveDocumentPage
                        deletePageAction: window.deleteActiveDocumentPage
                        rotatePageAction: window.rotateDocumentPage
                        formController: formController
                        onFormFieldSelected: function(field) {
                            formInspector.selectedField = field
                        }
                    }

                    EditInspector {
                        id: editInspector
                        anchors {
                            top: parent.top
                            right: parent.right
                            margins: 14
                        }
                        visible: window.hasActiveDocument
                                 && window.topToolbarMenu === "edit"
                                 && pdfViewer
                                 && pdfViewer.inlineTextEditingActive
                        selectedElement: visible && pdfViewer ? pdfViewer.activeTextDraft : null
                        onTextCommitted: function(text) {
                            if (pdfViewer && pdfViewer.inlineTextEditingActive)
                                pdfViewer.updateActiveDraftText(text)
                        }
                        onStyleChanged: function(patch) {
                            if (pdfViewer)
                                pdfViewer.updateActiveTextDraftStyle(patch)
                        }
                        onSaveCopyRequested: function(incremental) {
                            window.pendingEditSaveIncremental = incremental
                            saveRotatedDialog.open()
                        }
                    }

                    FormInspector {
                        id: formInspector
                        anchors {
                            top: parent.top
                            right: parent.right
                            margins: 14
                        }
                        visible: window.hasActiveDocument && window.viewMode === "forms"
                        selectedField: null
                        onTextValueCommitted: function(fieldId, value) {
                            formController.setTextValue(fieldId, value)
                        }
                        onCheckStateToggled: function(fieldId, checked) {
                            formController.setCheckState(fieldId, checked)
                        }
                        onComboValueChanged: function(fieldId, value) {
                            formController.setComboValue(fieldId, value)
                        }
                        onSaveFilledRequested: function(outPath) {
                            formController.saveFilled(outPath)
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: window.hasActiveDocument && window.reflowModeEnabled
                        color: window.presentationModeEnabled ? "#050608" : Theme.background

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: window.presentationModeEnabled || window.readingFullscreenEnabled ? 24 : 20
                            spacing: 14

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Label {
                                    text: window.activeDocumentTitle() + " - Reflow"
                                    color: Theme.text
                                    font.pixelSize: window.presentationModeEnabled ? 18 : 15
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Button {
                                    text: "Copiar"
                                    onClicked: window.copyVisibleText()
                                }

                                Button {
                                    text: "PDF"
                                    onClicked: window.toggleReflowMode()
                                }
                            }

                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                TextArea {
                                    id: reflowTextArea
                                    width: Math.max(parent ? parent.width : 0, 520)
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.Wrap
                                    text: window.readingPanelTextLoading ? "Extrayendo texto..."
                                          : window.readingPanelText.trim().length > 0 ? window.readingPanelText
                                          : "Este PDF no tiene texto extraible para reflow."
                                    color: Theme.text
                                    font.pixelSize: window.presentationModeEnabled ? 22 : 16
                                    leftPadding: 24
                                    rightPadding: 24
                                    topPadding: 24
                                    bottomPadding: 24
                                    background: Rectangle {
                                        color: Theme.surface
                                        radius: Theme.radiusLg
                                        border.color: Theme.border
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Connections {
                target: window
                function onJumpToPageRequested(index) {
                    pdfViewer.navigateToPage(index)
                    if (window.pendingSearchFocusResult) {
                        var result = window.pendingSearchFocusResult
                        window.pendingSearchFocusResult = null
                        Qt.callLater(function() {
                            pdfViewer.focusSearchResult(result)
                        })
                    }
                }
            }

            Connections {
                target: documentSearchController
                function onSearchCompleted(filePath, requestId, query, resultsJson, canceled) {
                    var index = window.findDocumentIndexByPath(filePath)
                    if (index < 0)
                        return

                    var doc = documentModel.get(index)
                    if (Number(doc.searchRequestId || 0) !== Number(requestId))
                        return

                    documentModel.setProperty(index, "searchInProgress", false)

                    if (canceled)
                        return

                    if (String(doc.searchQuery || "").trim() !== String(query || "").trim())
                        return

                    var remappedResultsJson = window.remapSearchResultsForDocument(index, resultsJson)
                    documentModel.setProperty(index, "searchResultsJson", remappedResultsJson)

                    var parsed = []
                    try {
                        parsed = JSON.parse(remappedResultsJson || "[]")
                    } catch(e) {
                        parsed = []
                    }

                    if (parsed.length <= 0) {
                        documentModel.setProperty(index, "activeSearchResultIndex", -1)
                        if (index === window.activeDocumentIndex) {
                            if (window.navigationSidePanelMode === "search")
                                window.navigationSidePanelMode = "thumbnails"
                            window.saveMessage = "No se encontraron coincidencias."
                            window.syncActiveDocumentState()
                        }
                        return
                    }

                    var nextIndex = Number(doc.activeSearchResultIndex)
                    if (isNaN(nextIndex) || nextIndex < 0 || nextIndex >= parsed.length)
                        nextIndex = 0

                    documentModel.setProperty(index, "activeSearchResultIndex", nextIndex)

                    if (index === window.activeDocumentIndex) {
                        window.navigationPanelVisible = true
                        window.navigationSidePanelMode = "search"
                        window.saveMessage = parsed.length === 1 ? "1 coincidencia." : String(parsed.length) + " coincidencias."
                        window.syncActiveDocumentState()
                        Qt.callLater(function() {
                            window.activateSearchResult(nextIndex, false)
                        })
                    }
                }
            }

            Rectangle {
                id: documentLoadingOverlay
                anchors.fill: parent
                visible: window.shouldShowDocumentLoadingOverlay()
                color: Theme.isDark ? "#D010121B" : "#CCF5F7FC"
                z: 24

                MouseArea {
                    anchors.fill: parent
                    enabled: documentLoadingOverlay.visible
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 40, 420)
                    height: 220
                    radius: 22
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 56
                        spacing: 14

                        BusyIndicator {
                            anchors.horizontalCenter: parent.horizontalCenter
                            running: documentLoadingOverlay.visible
                            width: 56
                            height: 56
                        }

                        Label {
                            width: parent.width
                            text: window.loadingOverlayTitle()
                            color: Theme.text
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            font.pixelSize: 20
                            font.weight: Font.DemiBold
                        }

                        Label {
                            width: parent.width
                            text: window.loadingOverlaySubtitle()
                            color: Theme.secondaryText
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            font.pixelSize: 13
                        }

                        Label {
                            visible: window.hasActiveDocument && window.activeDocumentPerformanceText().length > 0
                            width: parent.width
                            text: window.activeDocumentPerformanceText()
                            color: Theme.secondaryText
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            font.pixelSize: 11
                        }
                    }
                }
            }

            Rectangle {
                id: searchOverlay
                visible: window.hasActiveDocument && !window.reflowModeEnabled && window.searchOverlayVisible
                anchors {
                    top: parent.top
                    right: parent.right
                    topMargin: 14
                    rightMargin: 20
                }
                width: Math.min(parent.width - 40, 392)
                height: 48
                radius: 12
                color: Theme.isDark ? "#181A24" : "#F7F8FC"
                border.color: Theme.isDark ? "#2D3146" : "#D7DDED"
                border.width: 1
                z: 25

                Row {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6
                    readonly property int controlsWidth: 1 + 40 + 28 + 28 + 28
                    readonly property int totalSpacing: spacing * 5

                    TextField {
                        id: pageSearchField
                        width: Math.max(120, parent.width - parent.controlsWidth - parent.totalSpacing)
                        height: 32
                        text: window.activeDocumentSearchQuery()
                        placeholderText: "Buscar en documento"
                        selectByMouse: true
                        color: Theme.text
                        font.pixelSize: 12
                        background: Rectangle {
                            color: "transparent"
                            border.color: "transparent"
                        }
                        onTextEdited: window.setSearchQuery(text)
                        onAccepted: {
                            if (window.activeDocumentSearchResultCount() > 0)
                                window.goToNextSearchResult()
                            else
                                window.setSearchQuery(text)
                        }
                        Keys.onEscapePressed: {
                            if (text.trim().length > 0)
                                window.clearSearch()
                            else
                                window.closeSearchOverlay(false)
                        }
                    }

                    Rectangle {
                        width: 1
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.border
                    }

                    Label {
                        width: 40
                        height: 32
                        text: window.activeDocumentSearchQuery().trim().length > 0
                              ? (window.activeDocumentSearchPending()
                                 ? "..."
                                 : window.activeDocumentSearchResultCount() > 0
                                 ? String(Math.max(1, window.activeDocumentSearchResultIndex() + 1)) + "/" + String(window.activeDocumentSearchResultCount())
                                 : "0/0")
                              : ""
                        color: Theme.secondaryText
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Button {
                        id: searchPrevOverlayButton
                        width: 28
                        height: 32
                        enabled: window.activeDocumentSearchResultCount() > 0
                        onClicked: window.goToPreviousSearchResult()
                        ToolTip.visible: hovered
                        ToolTip.text: "Resultado anterior (Shift+F3)"
                        contentItem: Canvas {
                            anchors.centerIn: parent
                            width: 12
                            height: 12
                            property color strokeColor: searchPrevOverlayButton.enabled ? Theme.text : Theme.secondaryText

                            onStrokeColorChanged: requestPaint()
                            Component.onCompleted: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.lineCap = "round"
                                ctx.lineJoin = "round"
                                ctx.strokeStyle = strokeColor
                                ctx.lineWidth = 1.7

                                ctx.beginPath()
                                ctx.moveTo(2, 8)
                                ctx.lineTo(6, 4)
                                ctx.lineTo(10, 8)
                                ctx.stroke()
                            }
                        }
                        background: Rectangle {
                            color: searchPrevOverlayButton.hovered ? Theme.hover : "transparent"
                            radius: 8
                        }
                    }

                    Button {
                        id: searchNextOverlayButton
                        width: 28
                        height: 32
                        enabled: window.activeDocumentSearchResultCount() > 0
                        onClicked: window.goToNextSearchResult()
                        ToolTip.visible: hovered
                        ToolTip.text: "Siguiente resultado (F3)"
                        contentItem: Canvas {
                            anchors.centerIn: parent
                            width: 12
                            height: 12
                            property color strokeColor: searchNextOverlayButton.enabled ? Theme.text : Theme.secondaryText

                            onStrokeColorChanged: requestPaint()
                            Component.onCompleted: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.lineCap = "round"
                                ctx.lineJoin = "round"
                                ctx.strokeStyle = strokeColor
                                ctx.lineWidth = 1.7

                                ctx.beginPath()
                                ctx.moveTo(2, 4)
                                ctx.lineTo(6, 8)
                                ctx.lineTo(10, 4)
                                ctx.stroke()
                            }
                        }
                        background: Rectangle {
                            color: searchNextOverlayButton.hovered ? Theme.hover : "transparent"
                            radius: 8
                        }
                    }

                    Button {
                        id: searchCloseOverlayButton
                        text: "×"
                        width: 28
                        height: 32
                        onClicked: window.closeSearchOverlay(true)
                        ToolTip.visible: hovered
                        ToolTip.text: "Cerrar busqueda"
                        contentItem: Text {
                            text: searchCloseOverlayButton.text
                            color: Theme.text
                            font.pixelSize: 15
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: searchCloseOverlayButton.hovered ? Theme.hover : "transparent"
                            radius: 8
                        }
                    }
                }
            }

            Rectangle {
                anchors {
                    top: parent.top
                    right: parent.right
                    margins: 14
                }
                visible: window.hasActiveDocument && (window.readingFullscreenEnabled || window.presentationModeEnabled)
                radius: Theme.radius
                color: Theme.surface
                border.color: Theme.border
                z: 20

                Row {
                    anchors.margins: 6
                    anchors.fill: parent
                    spacing: 6

                    Button {
                        text: window.reflowModeEnabled ? "PDF" : "Reflow"
                        onClicked: window.toggleReflowMode()
                    }

                    Button {
                        text: "Copiar"
                        onClicked: window.copyVisibleText()
                    }

                    Button {
                        text: window.presentationModeEnabled ? "Salir show" : "Show"
                        onClicked: window.togglePresentationMode()
                    }

                    Button {
                        text: "Salir"
                        onClicked: window.exitImmersiveModes()
                    }
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
                                visible: window.shouldShowGlobalPdfError()
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

            Connections {
                target: documentRenderController
                function onRenderCompleted(filePath, sessionId, pageIndex, thumbnail, scale, source, canceled, fromCache, firstPageVisibleMs, cacheBytes, processMemoryBytes, peakProcessMemoryBytes, pendingCount) {
                    var index = window.findDocumentIndexByPath(filePath)
                    if (index < 0)
                        return

                    var doc = documentModel.get(index)
                    if (Number(doc.renderSessionId || 0) !== Number(sessionId))
                        return

                    window.updateDocumentRenderMetrics(index, firstPageVisibleMs, cacheBytes, processMemoryBytes, peakProcessMemoryBytes, pendingCount)
                    if (canceled || !source || source.length === 0)
                        return

                    if (thumbnail) {
                        var thumbs = []
                        try {
                            thumbs = JSON.parse(doc.thumbnailSourcesJson || "[]")
                        } catch(e) {
                            thumbs = []
                        }
                        while (thumbs.length < Number(doc.pageCount || 0))
                            thumbs.push("")
                        thumbs[pageIndex] = source
                        documentModel.setProperty(index, "thumbnailSourcesJson", JSON.stringify(thumbs))
                        return
                    }

                    if (index === window.activeDocumentIndex && pdfViewer && pdfViewer.largeJumpMode && pageIndex !== window.activePageIndex)
                        return

                    var sources = []
                    try {
                        sources = JSON.parse(doc.pageSourcesJson || "[]")
                    } catch(e) {
                        sources = []
                    }
                    while (sources.length < Number(doc.pageCount || 0))
                        sources.push("")
                    sources[pageIndex] = source
                    var centerPage = index === window.activeDocumentIndex
                        ? window.activePageIndex
                        : Number(doc.activePageIndex || 0)
                    documentModel.setProperty(index,
                                              "pageSourcesJson",
                                              JSON.stringify(window.prunePageSourceWindow(sources,
                                                                                          centerPage,
                                                                                          window.pageRenderWindowRadius)))
                    if (index === window.activeDocumentIndex && pdfViewer)
                        pdfViewer.notePageRenderCompleted(pageIndex, scale)
                }
            }
        }

        Rectangle {
            id: statusBar
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(34, statusBarContent.implicitHeight + 10)
            visible: window.hasActiveDocument
            color: Theme.surface
            readonly property color controlFill: Theme.isDark ? "#1B1D31" : "#FCFCFE"
            readonly property color controlHover: Theme.isDark ? "#252945" : "#EFF3FB"
            readonly property color controlActive: Theme.isDark ? "#2F3557" : "#E3EAF8"
            readonly property color controlBorder: Theme.isDark ? "#41496F" : "#CCD5E8"
            readonly property bool compact: width < 1120
            readonly property bool narrow: width < 840

            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                color: Theme.border
            }

            Flow {
                id: statusBarContent
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                    topMargin: 5
                    bottomMargin: 5
                }
                spacing: 8
                flow: Flow.LeftToRight

                Label {
                    width: statusBar.narrow ? 150 : statusBar.compact ? 220 : 260
                    height: 24
                    text: window.shouldShowGlobalPdfError() ? pdfDocument.errorMessage
                          : saveMessage.length > 0 ? saveMessage
                          : "PDF"
                    color: window.shouldShowGlobalPdfError() ? Theme.danger : Theme.secondaryText
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Label {
                    visible: window.activeDocumentPerformanceText().length > 0
                    width: statusBar.narrow ? 190 : statusBar.compact ? 250 : 320
                    height: 24
                    text: window.activeDocumentPerformanceText()
                    color: Theme.secondaryText
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                Row {
                    spacing: 6
                    height: 24

                    Button {
                        id: historyBackButton
                        text: "↶"
                        enabled: window.activeDocumentHistoryBack().length > 0
                        width: 24
                        height: 24
                        onClicked: window.goBackInDocument()
                        ToolTip.visible: hovered
                        ToolTip.text: "Atras"
                        contentItem: Text {
                            text: historyBackButton.text
                            color: historyBackButton.enabled ? Theme.text : Theme.secondaryText
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: historyBackButton.down ? statusBar.controlActive
                                  : historyBackButton.hovered ? statusBar.controlHover
                                  : statusBar.controlFill
                            radius: Theme.radius
                            border.color: historyBackButton.activeFocus ? Theme.accent : statusBar.controlBorder
                            border.width: historyBackButton.activeFocus ? 2 : 1
                            opacity: historyBackButton.enabled ? 1.0 : 0.55
                        }
                    }

                    Button {
                        id: historyForwardButton
                        text: "↷"
                        enabled: window.activeDocumentHistoryForward().length > 0
                        width: 24
                        height: 24
                        onClicked: window.goForwardInDocument()
                        ToolTip.visible: hovered
                        ToolTip.text: "Adelante"
                        contentItem: Text {
                            text: historyForwardButton.text
                            color: historyForwardButton.enabled ? Theme.text : Theme.secondaryText
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: historyForwardButton.down ? statusBar.controlActive
                                  : historyForwardButton.hovered ? statusBar.controlHover
                                  : statusBar.controlFill
                            radius: Theme.radius
                            border.color: historyForwardButton.activeFocus ? Theme.accent : statusBar.controlBorder
                            border.width: historyForwardButton.activeFocus ? 2 : 1
                            opacity: historyForwardButton.enabled ? 1.0 : 0.55
                        }
                    }

                    Button {
                        id: thumbnailsModeButton
                        text: "Mini"
                        width: 42
                        height: 24
                        onClicked: window.setSidePanelMode("thumbnails")
                        ToolTip.visible: hovered
                        ToolTip.text: "Miniaturas"
                        contentItem: Text {
                            text: thumbnailsModeButton.text
                            color: Theme.text
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: window.navigationSidePanelMode === "thumbnails" ? statusBar.controlActive
                                  : thumbnailsModeButton.hovered ? statusBar.controlHover
                                  : statusBar.controlFill
                            radius: Theme.radius
                            border.color: thumbnailsModeButton.activeFocus ? Theme.accent : statusBar.controlBorder
                            border.width: thumbnailsModeButton.activeFocus ? 2 : 1
                        }
                    }

                    Button {
                        id: outlineModeButton
                        text: "Indice"
                        width: 52
                        height: 24
                        onClicked: window.setSidePanelMode("outline")
                        ToolTip.visible: hovered
                        ToolTip.text: "Bookmarks / indice"
                        contentItem: Text {
                            text: outlineModeButton.text
                            color: Theme.text
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: window.navigationSidePanelMode === "outline" ? statusBar.controlActive
                                  : outlineModeButton.hovered ? statusBar.controlHover
                                  : statusBar.controlFill
                            radius: Theme.radius
                            border.color: outlineModeButton.activeFocus ? Theme.accent : statusBar.controlBorder
                            border.width: outlineModeButton.activeFocus ? 2 : 1
                        }
                    }

                    Button {
                        id: snapToggleButton
                        text: window.pageSnapEnabled ? "Snap" : "Libre"
                        width: 48
                        height: 24
                        onClicked: window.setPageSnapEnabled(!window.pageSnapEnabled)
                        ToolTip.visible: hovered
                        ToolTip.text: "Snapping entre paginas"
                        contentItem: Text {
                            text: snapToggleButton.text
                            color: Theme.text
                            font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: window.pageSnapEnabled ? statusBar.controlActive
                                  : snapToggleButton.hovered ? statusBar.controlHover
                                  : statusBar.controlFill
                            radius: Theme.radius
                            border.color: snapToggleButton.activeFocus ? Theme.accent : statusBar.controlBorder
                            border.width: snapToggleButton.activeFocus ? 2 : 1
                        }
                    }

                    ComboBox {
                        id: spacingBox
                        width: 66
                        height: 24
                        model: [
                            { text: "0px", value: 0 },
                            { text: "8px", value: 8 },
                            { text: "18px", value: 18 },
                            { text: "28px", value: 28 },
                            { text: "40px", value: 40 }
                        ]
                        textRole: "text"
                        valueRole: "value"
                        currentIndex: window.pageSpacing <= 0 ? 0
                                     : window.pageSpacing <= 8 ? 1
                                     : window.pageSpacing <= 18 ? 2
                                     : window.pageSpacing <= 28 ? 3 : 4
                        font.pixelSize: 11
                        onActivated: window.setPageSpacing(currentValue)

                        contentItem: Text {
                            leftPadding: 10
                            rightPadding: 22
                            text: spacingBox.displayText
                            color: Theme.text
                            font.pixelSize: 11
                            verticalAlignment: Text.AlignVCenter
                        }

                        indicator: Text {
                            x: spacingBox.width - width - 8
                            y: (spacingBox.height - height) / 2
                            text: "⌄"
                            color: Theme.secondaryText
                            font.pixelSize: 13
                        }

                        background: Rectangle {
                            color: spacingBox.pressed ? statusBar.controlActive
                                  : spacingBox.hovered ? statusBar.controlHover
                                  : statusBar.controlFill
                            radius: Theme.radius
                            border.color: spacingBox.activeFocus ? Theme.accent : statusBar.controlBorder
                            border.width: spacingBox.activeFocus ? 2 : 1
                        }
                    }

                }

                Row {
                    spacing: 6
                    height: 24

                    Button {
                    id: firstPageButton
                    text: "|‹"
                    enabled: window.activePageIndex > 0
                    width: 30
                    height: 24
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
                    width: 26
                    height: 24
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
                    width: 48
                    height: 24
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
                    width: 42
                    height: 24
                    verticalAlignment: Text.AlignVCenter
                }

                Button {
                    id: nextPageButton
                    text: "›"
                    enabled: window.activePageIndex < window.activeDocumentPageCount() - 1
                    width: 26
                    height: 24
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
                    width: 30
                    height: 24
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

                }

                Row {
                    spacing: 6
                    height: 24

                    Rectangle {
                        width: 1
                        height: 20
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
                    width: statusBar.narrow ? 118 : 136
                    height: 24
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
                    width: 92
                    height: 24
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
                        width: 1
                        height: 20
                        color: Theme.border
                    }

                    ComboBox {
                    id: zoomPresetBox
                    model: window.zoomPresetOptions
                    textRole: "text"
                    valueRole: "value"
                    currentIndex: window.zoomPresetIndex()
                    width: 84
                    height: 24
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
                    width: 54
                    height: 24
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

                }

                Row {
                    spacing: 6
                    height: 24

                    Button {
                    id: statusZoomOutButton
                    text: "−"
                    enabled: window.effectiveZoomPercent() > 10
                    width: 24
                    height: 24
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
                    width: statusBar.narrow ? 96 : statusBar.compact ? 118 : 132
                    height: 24
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
                    width: 24
                    height: 24
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
}
