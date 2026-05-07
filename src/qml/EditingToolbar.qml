import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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

    implicitHeight: 32
    color: "#F5F5F5"
    border.color: "#BDBDBD"
    border.width: 1
    radius: 4

    RowLayout {
        anchors { fill: parent; leftMargin: 6; rightMargin: 6 }
        spacing: 4

        // Font family (abbreviated)
        Text {
            text: root.fontFamily.length > 10
                  ? root.fontFamily.substring(0, 10) + "…"
                  : root.fontFamily
            font.pixelSize: 11
            color: "#333"
            Layout.preferredWidth: 80
            elide: Text.ElideRight
        }

        Rectangle { width: 1; height: 20; color: "#BDBDBD" }

        // Font size -/+
        ToolButton {
            text: "−"
            font.pixelSize: 13
            implicitWidth: 24; implicitHeight: 24
            onClicked: root.fontSizeChangeRequested(Math.max(6, root.fontSize - 1))
        }
        Text {
            text: Math.round(root.fontSize)
            font.pixelSize: 11
            color: "#333"
            Layout.preferredWidth: 24
            horizontalAlignment: Text.AlignHCenter
        }
        ToolButton {
            text: "+"
            font.pixelSize: 13
            implicitWidth: 24; implicitHeight: 24
            onClicked: root.fontSizeChangeRequested(root.fontSize + 1)
        }

        Rectangle { width: 1; height: 20; color: "#BDBDBD" }

        // Bold / Italic
        ToolButton {
            text: "B"
            font.bold: true
            font.pixelSize: 12
            implicitWidth: 24; implicitHeight: 24
            opacity: root.bold ? 1.0 : 0.45
            onClicked: root.boldToggled()
        }
        ToolButton {
            text: "I"
            font.italic: true
            font.pixelSize: 12
            implicitWidth: 24; implicitHeight: 24
            opacity: root.italic ? 1.0 : 0.45
            onClicked: root.italicToggled()
        }

        Rectangle { width: 1; height: 20; color: "#BDBDBD" }

        // Alignment
        Repeater {
            model: [
                { label: "≡L", align: Qt.AlignLeft },
                { label: "≡C", align: Qt.AlignHCenter },
                { label: "≡R", align: Qt.AlignRight },
            ]
            ToolButton {
                required property var modelData
                text: modelData.label
                font.pixelSize: 11
                implicitWidth: 26; implicitHeight: 24
                opacity: root.alignment === modelData.align ? 1.0 : 0.45
                onClicked: root.alignmentChangeRequested(modelData.align)
            }
        }

        Rectangle { width: 1; height: 20; color: "#BDBDBD" }

        // Resize mode
        Repeater {
            model: [
                { label: "↕R", mode: "reflow",    tip: "Reflow text" },
                { label: "↕S", mode: "scaleFont", tip: "Scale font" },
                { label: "↕C", mode: "clip",      tip: "Clip" },
            ]
            ToolButton {
                required property var modelData
                text: modelData.label
                font.pixelSize: 10
                implicitWidth: 26; implicitHeight: 24
                opacity: root.resizeMode === modelData.mode ? 1.0 : 0.45
                ToolTip.text: modelData.tip
                ToolTip.visible: hovered
                ToolTip.delay: 600
                onClicked: root.resizeModeChangeRequested(modelData.mode)
            }
        }

        Item { Layout.fillWidth: true }
    }
}
