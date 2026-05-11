import QtQuick
import QtQuick.Layouts
import PDFClowne

// Contextual toolbar shown above a selected/editing block.
Rectangle {
    id: root

    property string fontFamily: "Helvetica"
    property real   fontSize: 12
    property bool   bold: false
    property bool   italic: false
    property string textColor: "#1C1C2E"
    property int    alignment: Qt.AlignLeft
    property string resizeMode: "reflow"

    signal fontFamilyChangeRequested(string family)
    signal fontSizeChangeRequested(real size)
    signal boldToggled()
    signal italicToggled()
    signal alignmentChangeRequested(int align)
    signal resizeModeChangeRequested(string mode)

    implicitHeight: 34
    color: Theme.surface
    border.color: Theme.border
    border.width: 1
    radius: Theme.radius

    RowLayout {
        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
        spacing: 4

        // Font family (abbreviated)
        Text {
            text: root.fontFamily.length > 10
                  ? root.fontFamily.substring(0, 10) + "..."
                  : root.fontFamily
            font.pixelSize: 11
            color: Theme.text
            Layout.preferredWidth: 80
            elide: Text.ElideRight
        }

        Rectangle { width: 1; height: 20; color: Theme.border }

        // Font size -/+
        PclToolButton {
            text: "-"
            Layout.preferredWidth: Theme.iconButtonSize
            Layout.preferredHeight: Theme.compactControlHeight
            tooltip: qsTr("Reducir tamaño")
            onClicked: root.fontSizeChangeRequested(Math.max(6, root.fontSize - 1))
        }
        Text {
            text: Math.round(root.fontSize)
            font.pixelSize: 11
            color: Theme.text
            Layout.preferredWidth: 24
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        PclToolButton {
            text: "+"
            Layout.preferredWidth: Theme.iconButtonSize
            Layout.preferredHeight: Theme.compactControlHeight
            tooltip: qsTr("Aumentar tamaño")
            onClicked: root.fontSizeChangeRequested(root.fontSize + 1)
        }

        Rectangle { width: 1; height: 20; color: Theme.border }

        // Bold / Italic
        PclToolButton {
            text: "B"
            checked: root.bold
            Layout.preferredWidth: Theme.iconButtonSize
            Layout.preferredHeight: Theme.compactControlHeight
            tooltip: qsTr("Negrita")
            onClicked: root.boldToggled()
        }
        PclToolButton {
            text: "I"
            checked: root.italic
            Layout.preferredWidth: Theme.iconButtonSize
            Layout.preferredHeight: Theme.compactControlHeight
            tooltip: qsTr("Cursiva")
            onClicked: root.italicToggled()
        }

        Rectangle { width: 1; height: 20; color: Theme.border }

        // Alignment
        Repeater {
            model: [
                { label: "≡L", align: Qt.AlignLeft },
                { label: "≡C", align: Qt.AlignHCenter },
                { label: "≡R", align: Qt.AlignRight },
            ]
            PclToolButton {
                required property var modelData
                text: modelData.label
                checked: root.alignment === modelData.align
                Layout.preferredWidth: Theme.iconButtonSize
                Layout.preferredHeight: Theme.compactControlHeight
                onClicked: root.alignmentChangeRequested(modelData.align)
            }
        }

        Rectangle { width: 1; height: 20; color: Theme.border }

        // Resize mode
        Repeater {
            model: [
                { label: "↕R", mode: "reflow",    tip: "Reflow text" },
                { label: "↕S", mode: "scaleFont", tip: "Scale font" },
                { label: "↕C", mode: "clip",      tip: "Clip" },
            ]
            PclToolButton {
                required property var modelData
                text: modelData.label
                checked: root.resizeMode === modelData.mode
                Layout.preferredWidth: Theme.iconButtonSize
                Layout.preferredHeight: Theme.compactControlHeight
                tooltip: modelData.tip
                onClicked: root.resizeModeChangeRequested(modelData.mode)
            }
        }

        Item { Layout.fillWidth: true }
    }
}
