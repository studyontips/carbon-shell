import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import "../Singletons"
import "../components"

Item {
    id: root

    property bool open: false
    signal closeRequested()

    property string currentSection: "Appearance"

    // Backdrop dismissal
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    // Main Hub Window (Flat, flush edge-to-edge layout separated by strict 1px hairlines)
    Rectangle {
        id: hubWindow
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, 1060)
        height: Math.min(parent.height - 64, 680)
        color: Theme.surface
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1
        radius: 12
        clip: true

        // Stop propagation so clicking inside window doesn't close
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                color: Qt.rgba(0, 0, 0, 0.20)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 16
                    spacing: 12

                    Text {
                        text: "CARBON // SETTINGS HUB"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(13)
                        font.weight: Font.Bold
                        color: Theme.primary
                    }

                    Item { Layout.fillWidth: true }

                    // Close Button
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 6
                        color: closeMouse.pressed ? Qt.rgba(1, 1, 1, 0.15) : (closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                        border.color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(13)
                            color: Qt.rgba(1, 1, 1, 0.70)
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeRequested()
                        }
                    }
                }
            }

            // Body: Sidebar + Vertical Hairline + Main Tab Content
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ==========================================
                // SIDEBAR with subtle tactile hardware pattern
                // ==========================================
                Item {
                    Layout.preferredWidth: 210
                    Layout.fillHeight: true

                    // Tactile Textured Background: 45-degree etch lines / dot-matrix
                    Canvas {
                        id: sidebarCanvas
                        anchors.fill: parent
                        opacity: 0.03
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.strokeStyle = "#FFFFFF"
                            ctx.lineWidth = 1
                            var step = 6
                            for (var x = -height; x < width; x += step) {
                                ctx.beginPath()
                                ctx.moveTo(x, 0)
                                ctx.lineTo(x + height, height)
                                ctx.stroke()
                            }
                        }
                    }

                    // Sidebar Navigation Items
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: 16
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 4

                        Repeater {
                            model: [
                                { name: "Appearance", glyph: "󰏘", badge: "M3" },
                                { name: "Display", glyph: "󰍹", badge: "" },
                                { name: "Audio", glyph: "󰓃", badge: "" },
                                { name: "Network", glyph: "󰤨", badge: "" },
                                { name: "System", glyph: "󰘚", badge: "" }
                            ]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                radius: 6
                                color: (root.currentSection === modelData.name) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : (navMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                                border.color: (root.currentSection === modelData.name) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40) : "transparent"
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    Text {
                                        text: modelData.glyph
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(15)
                                        color: (root.currentSection === modelData.name) ? Theme.primary : Qt.rgba(1, 1, 1, 0.60)
                                    }

                                    Text {
                                        text: modelData.name
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(13)
                                        font.weight: (root.currentSection === modelData.name) ? Font.DemiBold : Font.Normal
                                        color: (root.currentSection === modelData.name) ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.65)
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible: modelData.badge.length > 0
                                        text: modelData.badge
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(9)
                                        font.weight: Font.Bold
                                        color: Theme.primary
                                    }
                                }

                                MouseArea {
                                    id: navMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.currentSection = modelData.name
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Version info at bottom of sidebar
                        Text {
                            text: "CARBON // v2.6.4"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(10)
                            color: Qt.rgba(1, 1, 1, 0.25)
                            Layout.alignment: Qt.AlignHCenter
                            Layout.bottomMargin: 12
                        }
                    }
                }

                // 1px Vertical Hairline Separating Sidebar & Content
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                // Main Content View
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    AppearanceTab {
                        anchors.fill: parent
                        visible: root.currentSection === "Appearance"
                    }

                    // Placeholder for other sections
                    Item {
                        anchors.fill: parent
                        visible: root.currentSection !== "Appearance"

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                text: root.currentSection.toUpperCase() + " SETTINGS"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(14)
                                font.weight: Font.Bold
                                color: Qt.rgba(1, 1, 1, 0.50)
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: "Section under active development"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(12)
                                color: Qt.rgba(1, 1, 1, 0.30)
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
