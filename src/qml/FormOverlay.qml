pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import PDFClowne

// FormOverlay — draws interactive field boxes over a PDF page.
// Each field gets a type-specific colored border. Click selects field.
// Checkboxes/radios toggle on click (if not readOnly).

Item {
    id: root

    property var formFields: []
    property var mapRect: function(rect) { return rect || { x: 0, y: 0, width: 1, height: 1 } }
    property string selectedFieldId: ""
    property bool interactive: true

    signal fieldSelected(var field)
    signal checkStateChanged(string fieldId, bool checked)

    Repeater {
        model: root.formFields

        Item {
            id: fieldDelegate
            required property var modelData

            readonly property string fieldId:   String(modelData.id   || "")
            readonly property string fieldType: String(modelData.type || "text")
            readonly property var    mapped:    root.mapRect(modelData.rect || {})
            readonly property bool   selected:  root.selectedFieldId === fieldId
            readonly property bool   isCheckable: fieldType === "checkbox" || fieldType === "radio"
            readonly property bool   isSignature: fieldType === "signature"
            readonly property bool   readOnly:  !!modelData.readOnly
            readonly property bool   isChecked: String(modelData.value || "") === "true"

            readonly property color typeColor: {
                switch (fieldType) {
                    case "text":      return "#2463B6"
                    case "checkbox":  return "#1F7A4D"
                    case "radio":     return "#C26910"
                    case "combo":
                    case "list":      return "#7A3E9D"
                    case "signature": return "#C83040"
                    default:          return "#888888"
                }
            }

            x:      mapped.x
            y:      mapped.y
            width:  Math.max(8, mapped.width)
            height: Math.max(8, mapped.height)

            Rectangle {
                anchors.fill: parent
                color: {
                    var c = Qt.color(fieldDelegate.typeColor)
                    if (fieldDelegate.selected)        return Qt.rgba(c.r, c.g, c.b, 0.14)
                    if (hoverArea.containsMouse)       return Qt.rgba(c.r, c.g, c.b, 0.07)
                    return Qt.rgba(c.r, c.g, c.b, 0.04)
                }
                border.color: fieldDelegate.typeColor
                border.width: fieldDelegate.selected ? 2 : 1
                radius: fieldDelegate.isCheckable ? 3 : 2

                // Check/radio fill indicator
                Rectangle {
                    visible: fieldDelegate.isCheckable && fieldDelegate.isChecked
                    anchors.centerIn: parent
                    width:  Math.min(parent.width, parent.height) * 0.55
                    height: width
                    radius: fieldDelegate.fieldType === "radio" ? width / 2 : 2
                    color:  fieldDelegate.typeColor
                }

                // Signature placeholder glyph
                Text {
                    visible: fieldDelegate.isSignature
                    anchors.centerIn: parent
                    text: "✍"
                    color: fieldDelegate.typeColor
                    font.pixelSize: Math.max(9, Math.min(parent.height * 0.55, 16))
                }

                // Type chip shown when selected
                Rectangle {
                    visible: fieldDelegate.selected && parent.width > 28
                    anchors {
                        bottom: parent.top
                        left:   parent.left
                        bottomMargin: 2
                    }
                    width:  chipLabel.implicitWidth + 8
                    height: 16
                    radius: 3
                    color:  fieldDelegate.typeColor

                    Text {
                        id: chipLabel
                        anchors.centerIn: parent
                        text:  fieldDelegate.fieldType
                        color: "white"
                        font.pixelSize: 9
                        font.weight: Font.DemiBold
                    }
                }
            }

            MouseArea {
                id: hoverArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: root.interactive
                cursorShape: fieldDelegate.isCheckable
                             ? Qt.PointingHandCursor : Qt.IBeamCursor

                onClicked: {
                    root.selectedFieldId = fieldDelegate.fieldId
                    root.fieldSelected(fieldDelegate.modelData)
                    if (fieldDelegate.isCheckable && !fieldDelegate.readOnly)
                        root.checkStateChanged(fieldDelegate.fieldId, !fieldDelegate.isChecked)
                }
            }
        }
    }
}
