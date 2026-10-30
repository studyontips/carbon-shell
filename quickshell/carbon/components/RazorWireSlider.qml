import QtQuick
import QtQuick.Layouts
import "../Singletons"

Item {
    id: root

    property string label: ""
    property real from: 0
    property real to: 100
    property real value: 0
    property real stepSize: 1
    property string unit: ""
    property int decimals: 0

    signal moved(real val)

    implicitWidth: 300
    implicitHeight: 48

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.label
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.Medium
                color: Qt.rgba(1, 1, 1, 0.85)
                Layout.alignment: Qt.AlignLeft
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.value.toFixed(root.decimals) + (root.unit.length > 0 ? (" " + root.unit) : "")
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Theme.primary
                Layout.alignment: Qt.AlignRight
            }
        }

        // Track and Diamond Handle
        Item {
            id: trackContainer
            Layout.fillWidth: true
            Layout.preferredHeight: 18

            readonly property real normVal: Math.max(0.0, Math.min(1.0, (root.value - root.from) / (root.to - root.from || 1)))
            readonly property real handleX: normVal * (trackContainer.width - 12)

            // Inactive track (1px solid hairline)
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: Qt.rgba(1, 1, 1, 0.12)
            }

            // Active track (1px glowing Theme.primary line)
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: trackContainer.handleX + 6
                height: 1
                color: Theme.primary
            }

            // Diamond Handle (10x10 rotated 45 deg, hollow with 1.5px border)
            Rectangle {
                x: trackContainer.handleX
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                rotation: 45
                color: Theme.surface
                border.color: Theme.primary
                border.width: 1.5

                // Subtle center dot or glow if dragged
                Rectangle {
                    anchors.centerIn: parent
                    width: 3
                    height: 3
                    color: Theme.primary
                    visible: mouseArea.containsPress
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                function updateVal(mouseX) {
                    var boundedX = Math.max(0, Math.min(trackContainer.width - 12, mouseX - 6))
                    var ratio = boundedX / Math.max(1, trackContainer.width - 12)
                    var raw = root.from + ratio * (root.to - root.from)
                    if (root.stepSize > 0) {
                        raw = Math.round(raw / root.stepSize) * root.stepSize
                    }
                    var clamped = Math.max(root.from, Math.min(root.to, raw))
                    root.value = clamped
                    root.moved(clamped)
                }

                onPositionChanged: function(mouse) {
                    if (pressed) {
                        updateVal(mouse.x)
                    }
                }

                onPressed: function(mouse) {
                    updateVal(mouse.x)
                }
            }
        }
    }
}
