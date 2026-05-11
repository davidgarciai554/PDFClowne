import QtQuick
import PDFClowne

Rectangle {
    id: root

    property color swatchColor: "#000000"
    property bool selected: false
    signal clicked()

    implicitWidth: Theme.controlHeight
    implicitHeight: Theme.controlHeight
    radius: Theme.radius
    color: Theme.controlFill
    border.color: mouseArea.containsMouse || selected ? Theme.focusRing : Theme.border
    border.width: selected ? 2 : 1

    Rectangle {
        anchors.centerIn: parent
        width: Math.max(16, parent.width - 12)
        height: Math.max(16, parent.height - 12)
        radius: 3
        color: root.swatchColor
        border.color: Theme.border
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
