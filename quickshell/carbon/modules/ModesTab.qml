import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../Singletons"
import "../components"

/**
 * ModesTab.qml:
 * Carbon Shell // Modes Studio & Blueprint Customizer
 *
 * Implements:
 *   - ReactBits Rubber-Segment Category Pill (Screen Notch / Minimal Island / Vanish)
 *   - Fluid Blueprint Canvas with Dotted Pattern & Inset Curved Bezel
 *   - Draggable Notch Bars (Left, Center, Right) constrained strictly to Y-axis
 *   - Live interactive Notch components (workspaces, clock, music, pavilion expansion)
 *   - Two-Section Architecture: "Designs" & "Settings"
 *   - Live Design Switchers:
 *       1. Animated Center Chronometer / Clock (with expansion preview)
 *       2. Workspace Indicator Glyphs (Diamonds, Dots, Bars, Squares, Numerals, Roman)
 *       3. Distro / App Launcher Brand Logos (Arch, Carbon, Nix, Debian, Fedora, Apple, Rocket)
 *   - Live Notch Geometry & Atmosphere Sliders (Height, Ear Radius, Bottom Radius, Opacity, Blur)
 */
Item {
    id: root

    implicitWidth: 800
    implicitHeight: 600

    // Mode Selector: 0: Screen Notch, 1: Minimal Island, 2: Vanish
    property int currentMode: 0
    property string activeSubSection: "Designs" // "Designs" | "Settings"

    // ── Live Design Selection State ──────────────────────────────────────────
    property string selectedLogo: (typeof Theme !== "undefined" && Theme.distroIcon) ? Theme.distroIcon : "󰣇"
    property string selectedActiveGlyph: (typeof Theme !== "undefined" && Theme.workspaceActiveGlyph) ? Theme.workspaceActiveGlyph : "◆"
    property string selectedInactiveGlyph: (typeof Theme !== "undefined" && Theme.workspaceInactiveGlyph) ? Theme.workspaceInactiveGlyph : "◇"
    property string selectedClockDesign: "tactical_chrono"

    // ── Interactive Preview State ────────────────────────────────────────────
    property int activePreviewWorkspace: 1
    property bool centerExpanded: false

    // Draggable Y Positions (Strictly Y-Axis Only)
    property real leftBarY: 0
    property real centerBarY: 0
    property real rightBarY: 0

    // Geometry & Atmosphere Preview Settings
    property int previewNotchHeight: 34
    property int previewEarRadius: 10
    property int previewBottomRadius: 14
    property real previewNotchOpacity: 0.94
    property bool previewBlur: true
    property int previewAppGap: 6

    function resetBarPositions() {
        leftBarY = 0
        centerBarY = 0
        rightBarY = 0
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ===================================================================
        // 1. TOP HEADER: REACTBITS RUBBER-SEGMENT MODE SELECTOR
        // ===================================================================
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            Layout.topMargin: 8
            Layout.leftMargin: 16
            Layout.rightMargin: 16

            Rectangle {
                id: modeTrack
                anchors.centerIn: parent
                width: Math.min(parent.width - 24, 520)
                height: 36
                radius: 999
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)

                readonly property real segmentWidth: (width - 6) / 3

                // Sliding Rubber Indicator Pill
                Rectangle {
                    id: rubberPill
                    x: 3 + (root.currentMode * modeTrack.segmentWidth)
                    y: 3
                    width: modeTrack.segmentWidth
                    height: 30
                    radius: 999
                    color: Theme.primary
                    transformOrigin: Item.Center

                    Behavior on x {
                        NumberAnimation {
                            duration: 360
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.15
                        }
                    }

                    // Rubber stretch & squash animation on mode switch
                    SequentialAnimation {
                        id: rubberAnim
                        ParallelAnimation {
                            NumberAnimation { target: rubberPill; property: "scale"; to: 1.0; duration: 1 }
                            NumberAnimation { target: rubberPillScale; property: "xScale"; to: 1.22; duration: 160; easing.type: Easing.OutQuad }
                            NumberAnimation { target: rubberPillScale; property: "yScale"; to: 0.84; duration: 160; easing.type: Easing.OutQuad }
                        }
                        ParallelAnimation {
                            NumberAnimation { target: rubberPillScale; property: "xScale"; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                            NumberAnimation { target: rubberPillScale; property: "yScale"; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                        }
                    }

                    transform: Scale {
                        id: rubberPillScale
                        origin.x: rubberPill.width / 2
                        origin.y: rubberPill.height / 2
                        xScale: 1.0
                        yScale: 1.0
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 0

                    Repeater {
                        model: [
                            { name: "Screen Notch", glyph: "󰹑" },
                            { name: "Minimal Island", glyph: "󰝥" },
                            { name: "Vanish", glyph: "󱐋" }
                        ]

                        delegate: Item {
                            required property int index
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: modelData.glyph
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(13)
                                    color: root.currentMode === index ? (Theme.m3onPrimary || "#000000") : Qt.rgba(1, 1, 1, 0.65)
                                }

                                Text {
                                    text: modelData.name
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(11.5)
                                    font.weight: root.currentMode === index ? Font.Bold : Font.Medium
                                    color: root.currentMode === index ? (Theme.m3onPrimary || "#000000") : Qt.rgba(1, 1, 1, 0.75)
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.currentMode !== index) {
                                        rubberAnim.restart()
                                        root.currentMode = index
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ===================================================================
        // 2. MAIN CONTENT STACK ACCORDING TO ACTIVE MODE
        // ===================================================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ---------------------------------------------------------------
            // MODE 0: SCREEN NOTCH (Complete Blueprint & Configurator)
            // ---------------------------------------------------------------
            ColumnLayout {
                anchors.fill: parent
                visible: root.currentMode === 0
                spacing: 0

                // ── 2a. Blueprint Canvas Preview Section ───────────────────
                Item {
                    id: blueprintSection
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.centerExpanded ? 340 : 260
                    Layout.minimumHeight: 240
                    clip: true

                    Behavior on Layout.preferredHeight {
                        NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                    }

                    // Inset Rounded Card Container with 1px border
                    Rectangle {
                        id: blueprintCard
                        anchors.fill: parent
                        anchors.margins: 14
                        radius: 14
                        color: Qt.rgba(0, 0, 0, 0.40)
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        clip: true

                        // Dotted Matrix Grid Canvas (Crisp 1.2px dots, 18px grid)
                        Canvas {
                            id: blueprintDots
                            anchors.fill: parent
                            opacity: 0.22
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.fillStyle = "#FFFFFF"
                                var spacing = 18
                                for (var x = spacing / 2; x < width; x += spacing) {
                                    for (var y = spacing / 2; y < height; y += spacing) {
                                        ctx.beginPath()
                                        ctx.arc(x, y, 1.2, 0, Math.PI * 2)
                                        ctx.fill()
                                    }
                                }
                            }
                        }

                        // Top Ruler & Info Header
                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 22
                            color: Qt.rgba(0, 0, 0, 0.35)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                Text {
                                    text: "BLUEPRINT // NOTCH SYSTEM (HOLD & DRAG BARS VERTICALLY)"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(8.5)
                                    font.weight: Font.Bold
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "Y-AXIS LOCKED  •  CLICK NOTCH TO EXPAND"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(8)
                                    color: Qt.rgba(1, 1, 1, 0.40)
                                }
                            }
                        }

                        // ── Blueprint Screen Workspace ─────────────────────
                        Item {
                            id: blueprintWorkspace
                            anchors.fill: parent
                            anchors.topMargin: 24

                            // ── 1. LEFT NOTCH BAR (Draggable Y-Only) ────────
                            Item {
                                id: leftBarWrapper
                                x: 20
                                y: root.leftBarY
                                width: leftBarCard.width
                                height: leftBarCard.height
                                z: leftDragArea.pressed ? 10 : 2

                                DragHandler {
                                    id: leftDragHandler
                                    target: leftBarWrapper
                                    xAxis.enabled: false
                                    yAxis.enabled: true
                                    yAxis.minimum: 0
                                    yAxis.maximum: Math.max(0, blueprintWorkspace.height - leftBarWrapper.height - 10)
                                }

                                MouseArea {
                                    id: leftDragArea
                                    anchors.fill: parent
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    drag.target: leftBarWrapper
                                    drag.axis: Drag.YAxis
                                    drag.minimumY: 0
                                    drag.maximumY: Math.max(0, blueprintWorkspace.height - leftBarWrapper.height - 10)
                                    onReleased: root.leftBarY = leftBarWrapper.y
                                }

                                Rectangle {
                                    id: leftBarCard
                                    width: leftBarContent.implicitWidth + 24
                                    height: root.previewNotchHeight
                                    radius: root.previewBottomRadius
                                    color: Qt.rgba(0.04, 0.04, 0.06, root.previewNotchOpacity)
                                    border.color: leftDragArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.50) : Qt.rgba(1, 1, 1, 0.14)
                                    border.width: 1

                                    // Ear Fillets (visual notch integration)
                                    Rectangle {
                                        width: 10
                                        height: 10
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        color: "transparent"
                                        border.color: Qt.rgba(1, 1, 1, 0.10)
                                        border.width: 1
                                        visible: root.leftBarY <= 1
                                    }
                                    Rectangle {
                                        width: 10
                                        height: 10
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        color: "transparent"
                                        border.color: Qt.rgba(1, 1, 1, 0.10)
                                        border.width: 1
                                        visible: root.leftBarY <= 1
                                    }

                                    RowLayout {
                                        id: leftBarContent
                                        anchors.centerIn: parent
                                        spacing: 8

                                        // Brand Logo Button
                                        Rectangle {
                                            Layout.preferredWidth: 22
                                            Layout.preferredHeight: 22
                                            radius: 6
                                            color: logoBtnMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : "transparent"
                                            border.color: logoBtnMouse.containsMouse ? Theme.primary : "transparent"
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.selectedLogo
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: Theme.fontPx(14)
                                                color: Theme.primary
                                            }

                                            MouseArea {
                                                id: logoBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {}
                                            }
                                        }

                                        // Workspace Switcher Pills (Interactive!)
                                        RowLayout {
                                            spacing: 4

                                            Repeater {
                                                model: [1, 2, 3, 4]
                                                delegate: Rectangle {
                                                    required property int modelData
                                                    readonly property bool isSelected: root.activePreviewWorkspace === modelData

                                                    Layout.preferredWidth: isSelected ? 22 : 16
                                                    Layout.preferredHeight: 18
                                                    radius: 5
                                                    color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : (wsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                                    border.color: isSelected ? Theme.primary : "transparent"
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: isSelected ? root.selectedActiveGlyph : root.selectedInactiveGlyph
                                                        font.family: "JetBrainsMono Nerd Font"
                                                        font.pixelSize: Theme.fontPx(10)
                                                        color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.50)
                                                    }

                                                    MouseArea {
                                                        id: wsMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.activePreviewWorkspace = modelData
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ── 2. CENTER NOTCH BAR (Draggable Y-Only & Expandable) ─
                            Item {
                                id: centerBarWrapper
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: root.centerBarY
                                width: root.centerExpanded ? Math.min(parent.width - 40, 560) : centerBarContent.implicitWidth + 28
                                height: root.centerExpanded ? 240 : root.previewNotchHeight
                                z: root.centerExpanded ? 20 : (centerDragArea.pressed ? 10 : 3)

                                Behavior on width {
                                    NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.08 }
                                }
                                Behavior on height {
                                    NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.08 }
                                }

                                DragHandler {
                                    id: centerDragHandler
                                    target: centerBarWrapper
                                    xAxis.enabled: false
                                    yAxis.enabled: true
                                    yAxis.minimum: 0
                                    yAxis.maximum: Math.max(0, blueprintWorkspace.height - centerBarWrapper.height - 10)
                                }

                                MouseArea {
                                    id: centerDragArea
                                    anchors.fill: parent
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    drag.target: centerBarWrapper
                                    drag.axis: Drag.YAxis
                                    drag.minimumY: 0
                                    drag.maximumY: Math.max(0, blueprintWorkspace.height - centerBarWrapper.height - 10)
                                    onReleased: root.centerBarY = centerBarWrapper.y
                                    onClicked: {
                                        // Toggle center pavilion expansion preview
                                        root.centerExpanded = !root.centerExpanded
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: root.centerExpanded ? 18 : root.previewBottomRadius
                                    color: Qt.rgba(0.04, 0.04, 0.06, root.previewNotchOpacity)
                                    border.color: root.centerExpanded ? Theme.primary : (centerDragArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.50) : Qt.rgba(1, 1, 1, 0.14))
                                    border.width: root.centerExpanded ? 1.5 : 1
                                    clip: true

                                    // Compact State (Unexpanded)
                                    RowLayout {
                                        id: centerBarContent
                                        anchors.centerIn: parent
                                        visible: !root.centerExpanded
                                        spacing: 8

                                        // Titan Clock
                                        Text {
                                            text: "10:19"
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontPx(12.5)
                                            font.weight: Font.Bold
                                            color: Theme.primary
                                        }

                                        // Separator
                                        Text {
                                            text: "|"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontPx(11)
                                            color: Qt.rgba(1, 1, 1, 0.25)
                                        }

                                        // Spinning Disc Glyph
                                        Text {
                                            text: "󰝚"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontPx(12)
                                            color: Theme.primary
                                        }

                                        // Track title
                                        Text {
                                            text: "Do I Wanna Know? • Arctic Monkeys"
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontPx(10.5)
                                            font.weight: Font.Medium
                                            color: Qt.rgba(1, 1, 1, 0.85)
                                        }
                                    }

                                    // Expanded State (Center Notch Pavilion with Animated Chronometer Preview)
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        visible: root.centerExpanded
                                        spacing: 10

                                        // Pavilion Header
                                        RowLayout {
                                            Layout.fillWidth: true

                                            Text {
                                                text: "CENTER NOTCH PAVILION // PREVIEW"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(9)
                                                font.weight: Font.Bold
                                                color: Theme.primary
                                            }

                                            Item { Layout.fillWidth: true }

                                            Rectangle {
                                                Layout.preferredWidth: 18
                                                Layout.preferredHeight: 18
                                                radius: 4
                                                color: Qt.rgba(1, 1, 1, 0.10)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✕"
                                                    font.pixelSize: 10
                                                    color: Qt.rgba(1, 1, 1, 0.70)
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.centerExpanded = false
                                                }
                                            }
                                        }

                                        // 3-Column Architecture
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            spacing: 12

                                            // Column 1: Tactical Agenda Preview
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                radius: 8
                                                color: Qt.rgba(1, 1, 1, 0.03)
                                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                                border.width: 1

                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 4

                                                    Text {
                                                        text: "[ IN PROGRESS ]"
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontPx(9)
                                                        font.weight: Font.Bold
                                                        color: Theme.primary
                                                    }
                                                    Text {
                                                        text: "Design Sync @ 11:30"
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.fontPx(10)
                                                        color: Qt.rgba(1, 1, 1, 0.80)
                                                    }
                                                }
                                            }

                                            // Column 2: THE ANIMATED CLOCK (Chronometer Design Preview)
                                            Rectangle {
                                                Layout.preferredWidth: 180
                                                Layout.fillHeight: true
                                                radius: 10
                                                color: Qt.rgba(0, 0, 0, 0.35)
                                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                                                border.width: 1
                                                clip: true

                                                // Embedded Tactical Chronometer
                                                TacticalChronometer {
                                                    anchors.centerIn: parent
                                                    width: parent.width - 8
                                                    height: parent.height - 8
                                                }
                                            }

                                            // Column 3: Lyrics Stream Preview
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                radius: 8
                                                color: Qt.rgba(1, 1, 1, 0.03)
                                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                                border.width: 1

                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 4

                                                    Text {
                                                        text: "CAIRO // LYRICS"
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontPx(8)
                                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.70)
                                                    }
                                                    Text {
                                                        text: "Crawlin' back to you..."
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.fontPx(10.5)
                                                        font.weight: Font.DemiBold
                                                        color: Theme.primary
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ── 3. RIGHT NOTCH BAR (Draggable Y-Only) ───────
                            Item {
                                id: rightBarWrapper
                                anchors.right: parent.right
                                anchors.rightMargin: 20
                                y: root.rightBarY
                                width: rightBarCard.width
                                height: rightBarCard.height
                                z: rightDragArea.pressed ? 10 : 2

                                DragHandler {
                                    id: rightDragHandler
                                    target: rightBarWrapper
                                    xAxis.enabled: false
                                    yAxis.enabled: true
                                    yAxis.minimum: 0
                                    yAxis.maximum: Math.max(0, blueprintWorkspace.height - rightBarWrapper.height - 10)
                                }

                                MouseArea {
                                    id: rightDragArea
                                    anchors.fill: parent
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    drag.target: rightBarWrapper
                                    drag.axis: Drag.YAxis
                                    drag.minimumY: 0
                                    drag.maximumY: Math.max(0, blueprintWorkspace.height - rightBarWrapper.height - 10)
                                    onReleased: root.rightBarY = rightBarWrapper.y
                                }

                                Rectangle {
                                    id: rightBarCard
                                    width: rightBarContent.implicitWidth + 24
                                    height: root.previewNotchHeight
                                    radius: root.previewBottomRadius
                                    color: Qt.rgba(0.04, 0.04, 0.06, root.previewNotchOpacity)
                                    border.color: rightDragArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.50) : Qt.rgba(1, 1, 1, 0.14)
                                    border.width: 1

                                    RowLayout {
                                        id: rightBarContent
                                        anchors.centerIn: parent
                                        spacing: 8

                                        Text {
                                            text: "󰕾"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontPx(12)
                                            color: Qt.rgba(1, 1, 1, 0.70)
                                        }

                                        Text {
                                            text: "󰤨"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontPx(12)
                                            color: Qt.rgba(1, 1, 1, 0.70)
                                        }

                                        Text {
                                            text: "󰁹 98%"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontPx(10)
                                            font.weight: Font.DemiBold
                                            color: Theme.primary
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 16
                                            Layout.preferredHeight: 16
                                            radius: 4
                                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰐥"
                                                font.family: Theme.fontMono
                                                font.pixelSize: 10
                                                color: Theme.primary
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 2b. Separator Hairline with Reset Bar Button ────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                // ── 2c. Sub-Section Switcher: "Designs" vs "Settings" ──────
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16

                    RowLayout {
                        anchors.fill: parent

                        // Segmented Tab Switcher
                        Rectangle {
                            height: 30
                            width: 180
                            radius: 8
                            color: Qt.rgba(0, 0, 0, 0.25)
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                spacing: 0

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 7
                                    color: root.activeSubSection === "Designs" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : "transparent"
                                    border.color: root.activeSubSection === "Designs" ? Theme.primary : "transparent"
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰙵  Designs"
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(11)
                                        font.weight: root.activeSubSection === "Designs" ? Font.Bold : Font.Normal
                                        color: root.activeSubSection === "Designs" ? Theme.primary : Qt.rgba(1, 1, 1, 0.65)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.activeSubSection = "Designs"
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 7
                                    color: root.activeSubSection === "Settings" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : "transparent"
                                    border.color: root.activeSubSection === "Settings" ? Theme.primary : "transparent"
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰒓  Settings"
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(11)
                                        font.weight: root.activeSubSection === "Settings" ? Font.Bold : Font.Normal
                                        color: root.activeSubSection === "Settings" ? Theme.primary : Qt.rgba(1, 1, 1, 0.65)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.activeSubSection = "Settings"
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Quick Blueprint Reset Button
                        Rectangle {
                            height: 28
                            width: resetText.implicitWidth + 24
                            radius: 6
                            color: resetMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.20)
                            border.color: resetMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1

                            Text {
                                id: resetText
                                anchors.centerIn: parent
                                text: "󰑐  Dock Bars to Top"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(10)
                                color: Qt.rgba(1, 1, 1, 0.75)
                            }

                            MouseArea {
                                id: resetMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.resetBarPositions()
                            }
                        }
                    }
                }

                // ── 2d. Scrollable Controls Body ───────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Flickable {
                        id: controlsFlickable
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: controlsColumn.implicitHeight + 30
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: controlsColumn
                            width: controlsFlickable.width - 32
                            x: 16
                            y: 8
                            spacing: 14

                            // ===============================================
                            // SUB-SECTION 1: DESIGNS
                            // ===============================================
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.activeSubSection === "Designs"
                                spacing: 14

                                // ── 1. Animated Center Clock Customizer ────
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: clockSecCol.implicitHeight + 28
                                    radius: 12
                                    color: Qt.rgba(0, 0, 0, 0.22)
                                    border.color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1

                                    ColumnLayout {
                                        id: clockSecCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 10

                                        RowLayout {
                                            Layout.fillWidth: true

                                            ColumnLayout {
                                                spacing: 2
                                                Text {
                                                    text: "Animated Center Chronometer"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(13)
                                                    font.weight: Font.Bold
                                                    color: Qt.rgba(1, 1, 1, 0.95)
                                                }
                                                Text {
                                                    text: "Aesthetic animated clock displayed when the center notch pavilion opens."
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(10.5)
                                                    color: Qt.rgba(1, 1, 1, 0.50)
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Rectangle {
                                                Layout.preferredWidth: 108
                                                Layout.preferredHeight: 22
                                                radius: 4
                                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                                border.color: Theme.primary
                                                border.width: 1

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "CENTER PAVILION"
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontPx(8.5)
                                                    font.weight: Font.Bold
                                                    color: Theme.primary
                                                }
                                            }
                                        }

                                        // Clock Design Cards
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            // Design 1: Tactical Chronometer (Default)
                                            Rectangle {
                                                Layout.preferredWidth: 190
                                                Layout.preferredHeight: 88
                                                radius: 8
                                                color: root.selectedClockDesign === "tactical_chrono" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(1, 1, 1, 0.03)
                                                border.color: root.selectedClockDesign === "tactical_chrono" ? Theme.primary : Qt.rgba(1, 1, 1, 0.10)
                                                border.width: root.selectedClockDesign === "tactical_chrono" ? 1.5 : 1

                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 10
                                                    spacing: 4

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Text {
                                                            text: "󰥔  Tactical Chrono"
                                                            font.family: Theme.font
                                                            font.pixelSize: Theme.fontPx(11.5)
                                                            font.weight: Font.Bold
                                                            color: Theme.primary
                                                        }
                                                        Item { Layout.fillWidth: true }
                                                        Text {
                                                            text: "ACTIVE"
                                                            font.family: Theme.fontMono
                                                            font.pixelSize: Theme.fontPx(8)
                                                            font.weight: Font.Bold
                                                            color: Theme.primary
                                                        }
                                                    }

                                                    Text {
                                                        text: "Dual-ring orbital chronometer with rotating reticle, pulsing seconds & date."
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.fontPx(9)
                                                        color: Qt.rgba(1, 1, 1, 0.60)
                                                        wrapMode: Text.WordWrap
                                                        Layout.fillWidth: true
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.selectedClockDesign = "tactical_chrono"
                                                }
                                            }

                                            // Design 2: Coming Soon Slot
                                            Rectangle {
                                                Layout.preferredWidth: 170
                                                Layout.preferredHeight: 88
                                                radius: 8
                                                color: Qt.rgba(1, 1, 1, 0.02)
                                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                                border.width: 1

                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 4

                                                    Text {
                                                        text: "+ DESIGN SLOT"
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontPx(10)
                                                        font.weight: Font.Bold
                                                        color: Qt.rgba(1, 1, 1, 0.35)
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }
                                                    Text {
                                                        text: "Coming soon"
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.fontPx(8.5)
                                                        color: Qt.rgba(1, 1, 1, 0.25)
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }
                                                }
                                            }

                                            // Design 3: Coming Soon Slot
                                            Rectangle {
                                                Layout.preferredWidth: 170
                                                Layout.preferredHeight: 88
                                                radius: 8
                                                color: Qt.rgba(1, 1, 1, 0.02)
                                                border.color: Qt.rgba(1, 1, 1, 0.06)
                                                border.width: 1

                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 4

                                                    Text {
                                                        text: "+ DESIGN SLOT"
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontPx(10)
                                                        font.weight: Font.Bold
                                                        color: Qt.rgba(1, 1, 1, 0.35)
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }
                                                    Text {
                                                        text: "Coming soon"
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.fontPx(8.5)
                                                        color: Qt.rgba(1, 1, 1, 0.25)
                                                        Layout.alignment: Qt.AlignHCenter
                                                    }
                                                }
                                            }

                                            Item { Layout.fillWidth: true }
                                        }
                                    }
                                }

                                // ── 2. Workspace Indicator Glyphs Customizer ──
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: wsSecCol.implicitHeight + 28
                                    radius: 12
                                    color: Qt.rgba(0, 0, 0, 0.22)
                                    border.color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1

                                    ColumnLayout {
                                        id: wsSecCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 10

                                        ColumnLayout {
                                            spacing: 2
                                            Text {
                                                text: "Workspace Indicator Glyphs"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(13)
                                                font.weight: Font.Bold
                                                color: Qt.rgba(1, 1, 1, 0.95)
                                            }
                                            Text {
                                                text: "Iconography and glyph styling of active and inactive workspaces. Updates blueprint immediately."
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(10.5)
                                                color: Qt.rgba(1, 1, 1, 0.50)
                                            }
                                        }

                                        // Glyphs Grid
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            Repeater {
                                                model: [
                                                    { name: "Diamonds", active: "◆", inactive: "◇" },
                                                    { name: "Orbs / Dots", active: "●", inactive: "○" },
                                                    { name: "Tactile Bars", active: "━", inactive: "─" },
                                                    { name: "Cyber Squares", active: "■", inactive: "□" },
                                                    { name: "Numerals", active: "1", inactive: "•" },
                                                    { name: "Roman", active: "I", inactive: "•" }
                                                ]

                                                delegate: Rectangle {
                                                    required property var modelData
                                                    readonly property bool isSelected: root.selectedActiveGlyph === modelData.active

                                                    width: 154
                                                    height: 52
                                                    radius: 8
                                                    color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : (glyphMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.02))
                                                    border.color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                                    border.width: isSelected ? 1.5 : 1

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 10
                                                        spacing: 8

                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 2

                                                            Text {
                                                                text: modelData.name
                                                                font.family: Theme.font
                                                                font.pixelSize: Theme.fontPx(10.5)
                                                                font.weight: isSelected ? Font.Bold : Font.Medium
                                                                color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.85)
                                                            }

                                                            Text {
                                                                text: modelData.active + "  " + modelData.inactive + "  " + modelData.inactive + "  " + modelData.inactive
                                                                font.family: "JetBrainsMono Nerd Font"
                                                                font.pixelSize: Theme.fontPx(11)
                                                                color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.45)
                                                            }
                                                        }

                                                        Text {
                                                            visible: isSelected
                                                            text: "✓"
                                                            font.family: Theme.fontMono
                                                            font.pixelSize: Theme.fontPx(12)
                                                            color: Theme.primary
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: glyphMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.selectedActiveGlyph = modelData.active
                                                            root.selectedInactiveGlyph = modelData.inactive
                                                            if (typeof Theme !== "undefined") {
                                                                Theme.workspaceActiveGlyph = modelData.active
                                                                Theme.workspaceInactiveGlyph = modelData.inactive
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // ── 3. Workspace Switcher Logo Customizer ──
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: logoSecCol.implicitHeight + 28
                                    radius: 12
                                    color: Qt.rgba(0, 0, 0, 0.22)
                                    border.color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1

                                    ColumnLayout {
                                        id: logoSecCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 10

                                        ColumnLayout {
                                            spacing: 2
                                            Text {
                                                text: "Workspace Switcher Distro Logo"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(13)
                                                font.weight: Font.Bold
                                                color: Qt.rgba(1, 1, 1, 0.95)
                                            }
                                            Text {
                                                text: "Choose the emblem displayed beside the workspaces in the left notch. Updates blueprint immediately."
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(10.5)
                                                color: Qt.rgba(1, 1, 1, 0.50)
                                            }
                                        }

                                        // Logos Grid
                                        Flow {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            Repeater {
                                                model: [
                                                    { name: "Arch Linux", icon: "󰣇" },
                                                    { name: "Carbon Shell", icon: "󰮔" },
                                                    { name: "NixOS", icon: "󰌽" },
                                                    { name: "Debian", icon: "󰊠" },
                                                    { name: "Fedora", icon: "󰣚" },
                                                    { name: "Apple Minimal", icon: "󰀵" },
                                                    { name: "Rocket Launch", icon: "󰄛" }
                                                ]

                                                delegate: Rectangle {
                                                    required property var modelData
                                                    readonly property bool isSelected: root.selectedLogo === modelData.icon

                                                    width: 130
                                                    height: 48
                                                    radius: 8
                                                    color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : (logoMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.02))
                                                    border.color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                                    border.width: isSelected ? 1.5 : 1

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.margins: 8
                                                        spacing: 8

                                                        Text {
                                                            text: modelData.icon
                                                            font.family: "JetBrainsMono Nerd Font"
                                                            font.pixelSize: Theme.fontPx(16)
                                                            color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.75)
                                                        }

                                                        Text {
                                                            text: modelData.name
                                                            font.family: Theme.font
                                                            font.pixelSize: Theme.fontPx(10)
                                                            font.weight: isSelected ? Font.Bold : Font.Normal
                                                            color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.75)
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                        }
                                                    }

                                                    MouseArea {
                                                        id: logoMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            root.selectedLogo = modelData.icon
                                                            if (typeof Theme !== "undefined") {
                                                                Theme.distroIcon = modelData.icon
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ===============================================
                            // SUB-SECTION 2: GENERAL NOTCH SETTINGS
                            // ===============================================
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.activeSubSection === "Settings"
                                spacing: 14

                                // Notch Geometry Sliders Card
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: geomSecCol.implicitHeight + 28
                                    radius: 12
                                    color: Qt.rgba(0, 0, 0, 0.22)
                                    border.color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1

                                    ColumnLayout {
                                        id: geomSecCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        ColumnLayout {
                                            spacing: 2
                                            Text {
                                                text: "Bar Geometry & Dimensions"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(13)
                                                font.weight: Font.Bold
                                                color: Qt.rgba(1, 1, 1, 0.95)
                                            }
                                            Text {
                                                text: "Configure the vertical profile and curvature of the three screen notches."
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(10.5)
                                                color: Qt.rgba(1, 1, 1, 0.50)
                                            }
                                        }

                                        RazorWireSlider {
                                            Layout.fillWidth: true
                                            label: "Notch Height"
                                            from: 26
                                            to: 48
                                            value: root.previewNotchHeight
                                            unit: "px"
                                            onMoved: function(v) { root.previewNotchHeight = Math.round(v) }
                                        }

                                        RazorWireSlider {
                                            Layout.fillWidth: true
                                            label: "Ear Curvature Fillet Radius"
                                            from: 4
                                            to: 20
                                            value: root.previewEarRadius
                                            unit: "px"
                                            onMoved: function(v) { root.previewEarRadius = Math.round(v) }
                                        }

                                        RazorWireSlider {
                                            Layout.fillWidth: true
                                            label: "Bottom Corner Convex Radius"
                                            from: 6
                                            to: 24
                                            value: root.previewBottomRadius
                                            unit: "px"
                                            onMoved: function(v) { root.previewBottomRadius = Math.round(v) }
                                        }
                                    }
                                }

                                // Notch Atmosphere & Surface Card
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: atmoSecCol.implicitHeight + 28
                                    radius: 12
                                    color: Qt.rgba(0, 0, 0, 0.22)
                                    border.color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1

                                    ColumnLayout {
                                        id: atmoSecCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        ColumnLayout {
                                            spacing: 2
                                            Text {
                                                text: "Atmosphere & Optical Effects"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(13)
                                                font.weight: Font.Bold
                                                color: Qt.rgba(1, 1, 1, 0.95)
                                            }
                                            Text {
                                                text: "OLED opacity, edge spacing, and compositor blur shaders."
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(10.5)
                                                color: Qt.rgba(1, 1, 1, 0.50)
                                            }
                                        }

                                        RazorWireSlider {
                                            Layout.fillWidth: true
                                            label: "Notch Surface Opacity"
                                            from: 0.20
                                            to: 1.00
                                            value: root.previewNotchOpacity
                                            decimals: 2
                                            onMoved: function(v) { root.previewNotchOpacity = v }
                                        }

                                        RazorWireSlider {
                                            Layout.fillWidth: true
                                            label: "Screen / App Gaps"
                                            from: 0
                                            to: 24
                                            value: root.previewAppGap
                                            unit: "px"
                                            onMoved: function(v) { root.previewAppGap = Math.round(v) }
                                        }

                                        // Blur Toggle
                                        RowLayout {
                                            Layout.fillWidth: true

                                            ColumnLayout {
                                                spacing: 2
                                                Text {
                                                    text: "Hardware Dual-Kawase Blur"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(12)
                                                    color: Qt.rgba(1, 1, 1, 0.90)
                                                }
                                                Text {
                                                    text: "Real-time background frosting beneath notch surfaces."
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(10)
                                                    color: Qt.rgba(1, 1, 1, 0.45)
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Rectangle {
                                                Layout.preferredWidth: 44
                                                Layout.preferredHeight: 24
                                                radius: 12
                                                color: root.previewBlur ? Theme.primary : Qt.rgba(1, 1, 1, 0.15)

                                                Behavior on color { ColorAnimation { duration: 180 } }

                                                Rectangle {
                                                    width: 18
                                                    height: 18
                                                    radius: 9
                                                    color: root.previewBlur ? (Theme.m3onPrimary || "#000000") : "#ffffff"
                                                    x: root.previewBlur ? 23 : 3
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.previewBlur = !root.previewBlur
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------------------------
            // MODE 1: MINIMAL ISLAND (Placeholder for Next Iteration)
            // ---------------------------------------------------------------
            ColumnLayout {
                anchors.centerIn: parent
                visible: root.currentMode === 1
                spacing: 12

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰝥"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontPx(36)
                    color: Theme.primary
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "MINIMAL ISLAND MODE"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(16)
                    font.weight: Font.Bold
                    color: Qt.rgba(1, 1, 1, 0.95)
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Ultra-compact single pill bar with floating dynamic island expansions.\nCustomizer modules for Minimal Island will be configured here."
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(11.5)
                    color: Qt.rgba(1, 1, 1, 0.50)
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // ---------------------------------------------------------------
            // MODE 2: VANISH (NUCLEUS) (Placeholder for Next Iteration)
            // ---------------------------------------------------------------
            ColumnLayout {
                anchors.centerIn: parent
                visible: root.currentMode === 2
                spacing: 12

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󱐋"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontPx(36)
                    color: Theme.primary
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "VANISH // NUCLEUS MODE"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(16)
                    font.weight: Font.Bold
                    color: Qt.rgba(1, 1, 1, 0.95)
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Zero permanent screen chrome. Central orbital nucleus hub with radial satellites.\nCustomizer modules for Vanish mode will be configured here."
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(11.5)
                    color: Qt.rgba(1, 1, 1, 0.50)
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }
}
