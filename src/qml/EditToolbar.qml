pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import PDFClowne

RowLayout {
    id: root

    property string currentTool: "text"
    property bool canUndo: false
    property bool canRedo: false
    signal toolSelected(string toolName)
    signal undoRequested()
    signal redoRequested()

    spacing: 6

    PclToolButton {
        text: "↶"
        enabled: root.canUndo
        Layout.preferredHeight: 30
        Layout.preferredWidth: 34
        onClicked: root.undoRequested()
        tooltip: qsTr("Deshacer")
    }

    PclToolButton {
        text: "↷"
        enabled: root.canRedo
        Layout.preferredHeight: 30
        Layout.preferredWidth: 34
        onClicked: root.redoRequested()
        tooltip: qsTr("Rehacer")
    }

    Repeater {
        model: [
            { label: "Bloque", toolName: "text" },
            { label: "Texto", toolName: "freeText" },
            { label: "Nota", toolName: "stickyNote" },
            { label: "HL", toolName: "highlight" },
            { label: "U", toolName: "underline" },
            { label: "S", toolName: "strikeout" },
            { label: "Ink", toolName: "ink" },
            { label: "Rect", toolName: "rect" },
            { label: "Circ", toolName: "circle" },
            { label: "Borrar", toolName: "erase" }
        ]

        PclToolButton {
            id: toolButton
            required property var modelData
            text: modelData.label
            checked: root.currentTool === toolButton.modelData.toolName
            danger: toolButton.modelData.toolName === "erase"
            Layout.preferredHeight: 30
            Layout.preferredWidth: Math.max(36, implicitWidth + 14)
            onClicked: root.toolSelected(modelData.toolName)
            tooltip: modelData.toolName
        }
    }
}
