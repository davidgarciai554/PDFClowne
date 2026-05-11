pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import PDFClowne

// FormInspector — side panel for editing the selected AcroForm field.
// Adapts layout per field type: text | checkbox | radio | combo | signature.

Pane {
    id: root

    property var selectedField: null

    readonly property string fieldType:  selectedField ? String(selectedField.type  || "text") : "text"
    readonly property string currentVal: selectedField ? String(selectedField.value || "")      : ""
    readonly property bool   hasField:   selectedField !== null
    readonly property bool   isReadOnly: hasField && !!selectedField.readOnly
    readonly property bool   isRequired: hasField && !!selectedField.required

    signal textValueCommitted(string fieldId, string value)
    signal checkStateToggled(string fieldId, bool checked)
    signal comboValueChanged(string fieldId, string value)
    signal saveFilledRequested(string outPath)

    width: 280
    padding: 12
    background: Rectangle {
        color: Theme.surface
        border.color: Theme.border
        radius: Theme.radius
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Header
        Label {
            text: "Formularios"
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }

        // Empty state
        Label {
            visible: !root.hasField
            text: "Haz clic en un campo del formulario para editarlo."
            wrapMode: Text.WordWrap
            color: Theme.text
            font.pixelSize: 11
            opacity: 0.6
            Layout.fillWidth: true
        }

        // Field metadata row
        ColumnLayout {
            visible: root.hasField
            Layout.fillWidth: true
            spacing: 4

            Label {
                text: root.selectedField ? String(root.selectedField.name || "(sin nombre)") : ""
                color: Theme.text
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 4

                Rectangle {
                    width:  typeChip.implicitWidth + 10
                    height: 16
                    radius: 3
                    color:  root.typeColor(root.fieldType)
                    Text {
                        id: typeChip
                        anchors.centerIn: parent
                        text:  root.fieldType
                        color: "white"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }
                Label {
                    visible: root.isReadOnly
                    text: "sólo lectura"
                    color: Theme.text
                    font.pixelSize: 10
                    opacity: 0.5
                }
                Label {
                    visible: root.isRequired
                    text: "requerido"
                    color: "#C83040"
                    font.pixelSize: 10
                }
            }
        }

        // ── Text field ──────────────────────────────────────────────────────
        ColumnLayout {
            visible: root.hasField && root.fieldType === "text"
            Layout.fillWidth: true
            spacing: 6

            TextArea {
                id: textEditor
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                text: root.currentVal
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                enabled: !root.isReadOnly
                placeholderText: root.isReadOnly ? "(sólo lectura)" : "Introduce el valor…"
            }

            Button {
                text: "Aplicar"
                Layout.fillWidth: true
                enabled: !root.isReadOnly
                onClicked: {
                    if (root.selectedField)
                        root.textValueCommitted(String(root.selectedField.id), textEditor.text)
                }
            }
        }

        // ── Checkbox / Radio ────────────────────────────────────────────────
        RowLayout {
            visible: root.hasField && (root.fieldType === "checkbox" || root.fieldType === "radio")
            Layout.fillWidth: true
            spacing: 8

            CheckBox {
                id: checkEditor
                checked: root.currentVal === "true"
                enabled: !root.isReadOnly
                text: checked ? "Marcado" : "Desmarcado"
                onToggled: {
                    if (root.selectedField)
                        root.checkStateToggled(String(root.selectedField.id), checked)
                }
            }
        }

        // ── Combo / List ────────────────────────────────────────────────────
        ColumnLayout {
            visible: root.hasField && (root.fieldType === "combo" || root.fieldType === "list")
            Layout.fillWidth: true
            spacing: 6

            TextField {
                id: comboEditor
                Layout.fillWidth: true
                text: root.currentVal
                enabled: !root.isReadOnly
                placeholderText: "Valor…"
                onEditingFinished: {
                    if (root.selectedField)
                        root.comboValueChanged(String(root.selectedField.id), text)
                }
            }
        }

        // ── Signature ───────────────────────────────────────────────────────
        Label {
            visible: root.hasField && root.fieldType === "signature"
            text: "Campo de firma digital.\nUsa el modo Firmar para colocar una firma."
            wrapMode: Text.WordWrap
            color: Theme.text
            font.pixelSize: 11
            opacity: 0.7
            Layout.fillWidth: true
        }

        Item { Layout.fillHeight: true }

        // ── Save section ────────────────────────────────────────────────────
        ColumnLayout {
            visible: root.hasField
            Layout.fillWidth: true
            spacing: 6

            Label {
                text: "Guardar formulario:"
                color: Theme.text
                font.pixelSize: 11
                opacity: 0.7
            }

            Button {
                text: "Guardar como copia…"
                Layout.fillWidth: true
                onClicked: saveFilledDialog.open()
            }
        }
    }

    function typeColor(t) {
        switch (t) {
            case "text":      return "#2463B6"
            case "checkbox":  return "#1F7A4D"
            case "radio":     return "#C26910"
            case "combo":
            case "list":      return "#7A3E9D"
            case "signature": return "#C83040"
        }
        return "#888888"
    }

    FileDialog {
        id: saveFilledDialog
        title: "Guardar formulario relleno"
        fileMode: FileDialog.SaveFile
        nameFilters: ["PDF (*.pdf)"]
        onAccepted: {
            const raw = String(selectedFile)
            const path = raw.startsWith("file:///") ? raw.slice(8).replace(/\//g, "\\") : raw
            root.saveFilledRequested(path)
        }
    }
}
