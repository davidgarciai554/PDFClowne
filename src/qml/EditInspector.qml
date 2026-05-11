pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import PDFClowne

Pane {
    id: root

    property var selectedElement: null
    property string editedText: selectedElement ? String(selectedElement.text || "") : ""
    property string fontFamily: selectedElement ? String(selectedElement.fontFamily || selectedElement.fontName || "Helvetica") : "Helvetica"
    property int fontSize: selectedElement ? Math.max(6, Math.round(Number(selectedElement.fontSize || 12))) : 12
    property string color: selectedElement ? String(selectedElement.color || "#1C1C2E") : "#1C1C2E"
    property bool fontChangeSafe: !!(selectedElement && selectedElement.fontResourceName)
    property bool incrementalSave: false

    signal textCommitted(string text)
    signal styleChanged(var patch)
    signal saveCopyRequested(bool incremental)

    width: 280
    padding: 12
    background: Rectangle {
        color: Theme.surface
        border.color: Theme.border
        radius: Theme.radius
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Text {
            text: qsTr("Inspector")
            color: Theme.text
            font.pixelSize: 14
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }

        TextArea {
            id: editor
            Layout.fillWidth: true
            Layout.preferredHeight: 118
            text: root.editedText
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            onEditingFinished: root.textCommitted(text)
            color: Theme.text
            selectedTextColor: Theme.accentText
            selectionColor: Theme.accent
            background: Rectangle {
                radius: Theme.radius
                color: Theme.controlFill
                border.color: editor.activeFocus ? Theme.focusRing : Theme.border
                border.width: editor.activeFocus ? 2 : 1
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PclComboBox {
                Layout.fillWidth: true
                model: ["Helvetica", "Times", "Courier"]
                currentIndex: root.fontFamily.toLowerCase().indexOf("cour") >= 0 ? 2
                              : root.fontFamily.toLowerCase().indexOf("times") >= 0 ? 1
                              : 0
                enabled: root.fontChangeSafe
                onActivated: root.styleChanged({ fontFamily: currentText })
            }

            PclSpinBox {
                from: 6
                to: 144
                value: root.fontSize
                Layout.preferredWidth: 96
                onValueModified: root.styleChanged({ fontSize: value })
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            PclColorSwatch {
                swatchColor: root.color
                Layout.preferredWidth: Theme.controlHeight
                Layout.preferredHeight: Theme.controlHeight
                onClicked: colorDialog.open()
            }

            PclButton {
                text: qsTr("Color")
                Layout.fillWidth: true
                onClicked: colorDialog.open()
            }
        }

        PclButton {
            text: qsTr("Guardar copia")
            primary: true
            Layout.fillWidth: true
            onClicked: root.saveCopyRequested(root.incrementalSave)
        }

        PclCheckBox {
            text: qsTr("Guardado incremental")
            checked: root.incrementalSave
            Layout.fillWidth: true
            onToggled: root.incrementalSave = checked
        }
    }

    ColorDialog {
        id: colorDialog
        selectedColor: root.color
        onAccepted: root.styleChanged({ color: selectedColor.toString() })
    }
}
