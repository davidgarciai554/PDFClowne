import QtQuick
import QtQuick.Layouts
import PDFClowne

Item {
    id: root

    property int from: 0
    property int to: 100
    property int value: 0

    signal valueModified(int value)

    implicitWidth: 86
    implicitHeight: Theme.controlHeight

    RowLayout {
        anchors.fill: parent
        spacing: 4

        PclToolButton {
            text: "−"
            enabled: root.value > root.from
            Layout.preferredWidth: Theme.iconButtonSize
            Layout.preferredHeight: Theme.compactControlHeight
            onClicked: {
                root.value = Math.max(root.from, root.value - 1)
                root.valueModified(root.value)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.compactControlHeight
            radius: Theme.radius
            color: Theme.controlFill
            border.color: Theme.border

            Text {
                anchors.centerIn: parent
                text: root.value
                color: Theme.text
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }

        PclToolButton {
            text: "+"
            enabled: root.value < root.to
            Layout.preferredWidth: Theme.iconButtonSize
            Layout.preferredHeight: Theme.compactControlHeight
            onClicked: {
                root.value = Math.min(root.to, root.value + 1)
                root.valueModified(root.value)
            }
        }
    }
}
