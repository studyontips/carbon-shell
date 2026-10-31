import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
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

    // ── Draggable Y Position & Magnetic Docking Animation ────────────────────
    property real notchBarsY: 0
    property string notchDockPosition: "top" // "top" | "bottom"
    property bool isDraggingNotch: false
    readonly property real currentBarHeight: root.centerExpanded ? 240 : root.previewNotchHeight
    readonly property real notchMaxY: Math.max(0, (blueprintWorkspace ? blueprintWorkspace.height : 230) - currentBarHeight)

    Behavior on notchBarsY {
        enabled: !root.isDraggingNotch
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    onCenterExpandedChanged: {
        if (notchDockPosition === "bottom") {
            notchBarsY = notchMaxY
        }
    }

    function dockToTop() {
        root.isDraggingNotch = false
        root.notchDockPosition = "top"
        root.notchBarsY = 0
        topFlashAnim.start()
        root.saveBarEdgeConfig("top")
    }

    function dockToBottom() {
        root.isDraggingNotch = false
        root.notchDockPosition = "bottom"
        root.notchBarsY = root.notchMaxY
        bottomFlashAnim.start()
        root.saveBarEdgeConfig("bottom")
    }

    function toggleNotchDock() {
        if (root.notchDockPosition === "top") root.dockToBottom()
        else root.dockToTop()
    }

    function resetBarPositions() {
        dockToTop()
    }

    property string activeSystemMode: "notch"

    function activateMode(modeName) {
        root.activeSystemMode = modeName
        var script = "import json, os\n" +
            "dir = os.environ.get('CARBON_CONFIG_DIR', os.path.expanduser('~/.config/carbon'))\n" +
            "os.makedirs(dir, exist_ok=True)\n" +
            "p = os.path.join(dir, 'carbon-bar-mode.json')\n" +
            "d = json.load(open(p)) if os.path.exists(p) else {}\n" +
            "d['mode'] = '" + modeName + "'\n" +
            "json.dump(d, open(p, 'w'), indent=2)\n"
        Quickshell.execDetached(["python3", "-c", script])
    }

    function saveBarEdgeConfig(edge) {
        var script = "import json, os\n" +
            "dir = os.environ.get('CARBON_CONFIG_DIR', os.path.expanduser('~/.config/carbon'))\n" +
            "os.makedirs(dir, exist_ok=True)\n" +
            "p1 = os.path.join(dir, 'carbon-bar-position.json')\n" +
            "d1 = json.load(open(p1)) if os.path.exists(p1) else {}\n" +
            "d1['mainBarEdge'] = '" + edge + "'\n" +
            "d1['edge'] = '" + edge + "'\n" +
            "d1['barEdge'] = '" + edge + "'\n" +
            "d1['musicBarEdge'] = '" + edge + "'\n" +
            "d1['leftEdge'] = '" + edge + "'\n" +
            "d1['centerEdge'] = '" + edge + "'\n" +
            "d1['rightEdge'] = '" + edge + "'\n" +
            "json.dump(d1, open(p1, 'w'), indent=2)\n" +
            "p2 = os.path.join(dir, 'carbon-bar-mode.json')\n" +
            "d2 = json.load(open(p2)) if os.path.exists(p2) else {}\n" +
            "d2['mainBarEdge'] = '" + edge + "'\n" +
            "json.dump(d2, open(p2, 'w'), indent=2)\n"
        Quickshell.execDetached(["python3", "-c", script])
    }

    // Bottom Bar Configuration Properties
    property int previewBottomGap: 8
    property int previewBottomOffset: 0
    property bool previewBottomExclusiveZone: true
    property bool previewBottomAutohide: false

    function saveBottomSetting(key, val) {
        var script = "import json, os\n" +
            "dir = os.environ.get('CARBON_CONFIG_DIR', os.path.expanduser('~/.config/carbon'))\n" +
            "os.makedirs(dir, exist_ok=True)\n" +
            "p1 = os.path.join(dir, 'carbon-bar-position.json')\n" +
            "d1 = json.load(open(p1)) if os.path.exists(p1) else {}\n" +
            "d1['" + key + "'] = " + JSON.stringify(val) + "\n" +
            "json.dump(d1, open(p1, 'w'), indent=2)\n"
        Quickshell.execDetached(["python3", "-c", script])
    }

    // Geometry & Atmosphere Preview Settings
    property int previewNotchHeight: 34
    property int previewEarRadius: 10
    property int previewBottomRadius: 14
    property real previewNotchOpacity: 0.94
    property bool previewBlur: true
    property int previewAppGap: 6

    // ── Vanish Mode State & Configuration ────────────────────────────────────
    property bool vanishMediaPlaying: true
    property string vanishSubSection: "Designs" // "Designs" | "Settings"
    property bool vanishTransitionEnabled: false
    property string vanishTransitionWord: "Wooshh!!"
    property int vanishWallpaperDuration: 800
    property string vanishWallpaperAnimation: "cinematic"
    property bool vanishShowRestingAtom: false
    property string vanishRestingSpin: "hover"
    property string vanishMusicVisualizer: "liquidHalo"

    FileView {
        id: vanishConfigView
        path: (Quickshell.env("CARBON_CONFIG_DIR") || ((Quickshell.env("HOME") || "") + "/.config/carbon")) + "/carbon-bar-mode.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.loadVanishConfig()
        onFileChanged: vanishConfigView.reload()
    }

    function loadVanishConfig() {
        try {
            const raw = vanishConfigView.text().trim()
            if (!raw) return
            const d = JSON.parse(raw)
            if (d.mode) {
                var m = String(d.mode).toLowerCase()
                root.activeSystemMode = m
                if (m === "notch" || m === "pill") root.currentMode = 0
                else if (m === "minimal" || m === "minimal_notch") root.currentMode = 1
                else if (m === "nucleus" || m === "vanish") root.currentMode = 2
            }
            if (d.mainBarEdge === "bottom") {
                root.notchDockPosition = "bottom"
                root.notchBarsY = root.notchMaxY
            } else if (d.mainBarEdge === "top") {
                root.notchDockPosition = "top"
                root.notchBarsY = 0
            }
            if (d.wallpaperAnimation) root.vanishWallpaperAnimation = String(d.wallpaperAnimation)
            if (d.wallpaperDuration) root.vanishWallpaperDuration = Number(d.wallpaperDuration)
            if (d.musicVisualizer) root.vanishMusicVisualizer = String(d.musicVisualizer)
            if (d.nucleus) {
                if (d.nucleus.transition !== undefined) root.vanishTransitionEnabled = Boolean(d.nucleus.transition)
                if (d.nucleus.transitionWord) root.vanishTransitionWord = String(d.nucleus.transitionWord)
                if (d.nucleus.showRestingAtom !== undefined) root.vanishShowRestingAtom = Boolean(d.nucleus.showRestingAtom)
                if (d.nucleus.restingSpin) root.vanishRestingSpin = String(d.nucleus.restingSpin)
            }
        } catch (e) {
            console.warn("[ModesTab] Error loading carbon-bar-mode.json:", e)
        }
    }

    function saveVanishConfig(key, val) {
        var script = "import json, os\n" +
            "dir = os.environ.get('CARBON_CONFIG_DIR', os.path.expanduser('~/.config/carbon'))\n" +
            "os.makedirs(dir, exist_ok=True)\n" +
            "p = os.path.join(dir, 'carbon-bar-mode.json')\n" +
            "d = json.load(open(p)) if os.path.exists(p) else {}\n"
        if (key.indexOf("nucleus.") === 0) {
            var subKey = key.substring(8)
            script += "if 'nucleus' not in d: d['nucleus'] = {}\n"
            script += "d['nucleus']['" + subKey + "'] = " + JSON.stringify(val) + "\n"
        } else {
            script += "d['" + key + "'] = " + JSON.stringify(val) + "\n"
        }
        script += "json.dump(d, open(p, 'w'), indent=2)\n"
        Quickshell.execDetached(["python3", "-c", script])
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

                        // ── Plain Dotted Matrix Canvas (Crisp 1.2px dots, 18px grid) ──
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

                        // ── Rounded Mask for Workspace (Keeps bars cleanly inside card boundary) ──
                        Item {
                            id: blueprintMask
                            anchors.fill: blueprintWorkspace
                            visible: false
                            layer.enabled: true
                            Rectangle {
                                anchors.fill: parent
                                radius: 13
                                color: "#FFFFFFFF"
                            }
                        }

                        // ── Blueprint Screen Workspace (Connected to Card Borders, 1px Margin) ──
                        Item {
                            id: blueprintWorkspace
                            anchors.fill: parent
                            anchors.margins: 1
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true
                                maskSource: blueprintMask
                            }

                            // Top Border Snap Flash Effect
                            Rectangle {
                                id: topSnapFlash
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 3
                                color: Theme.primary
                                opacity: 0.0
                                z: 30

                                SequentialAnimation {
                                    id: topFlashAnim
                                    NumberAnimation { target: topSnapFlash; property: "opacity"; to: 0.85; duration: 80; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: topSnapFlash; property: "opacity"; to: 0.0; duration: 320; easing.type: Easing.OutQuad }
                                }
                            }

                            // Bottom Border Snap Flash Effect
                            Rectangle {
                                id: bottomSnapFlash
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 3
                                color: Theme.primary
                                opacity: 0.0
                                z: 30

                                SequentialAnimation {
                                    id: bottomFlashAnim
                                    NumberAnimation { target: bottomSnapFlash; property: "opacity"; to: 0.85; duration: 80; easing.type: Easing.OutQuad }
                                    NumberAnimation { target: bottomSnapFlash; property: "opacity"; to: 0.0; duration: 320; easing.type: Easing.OutQuad }
                                }
                            }

                            // Top Dock Receiver Bay (Faint dashed bay shown while dragging)
                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: root.previewNotchHeight
                                color: root.notchBarsY < (root.notchMaxY * 0.35) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                                border.color: root.notchBarsY < (root.notchMaxY * 0.35) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40) : Qt.rgba(1, 1, 1, 0.10)
                                border.width: 1
                                opacity: (root.isDraggingNotch && root.notchBarsY > 15) ? 1.0 : 0.0
                                z: 1
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                                Behavior on color { ColorAnimation { duration: 180 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "↑ RELEASE TO DOCK TO TOP BEZEL"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(8.5)
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                    visible: parent.opacity > 0.5
                                }
                            }

                            // Bottom Dock Receiver Bay (Faint dashed bay shown while dragging)
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: root.previewNotchHeight
                                color: root.notchBarsY > (root.notchMaxY * 0.65) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : "transparent"
                                border.color: root.notchBarsY > (root.notchMaxY * 0.65) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40) : Qt.rgba(1, 1, 1, 0.10)
                                border.width: 1
                                opacity: (root.isDraggingNotch && root.notchBarsY < (root.notchMaxY - 15)) ? 1.0 : 0.0
                                z: 1
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                                Behavior on color { ColorAnimation { duration: 180 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "↓ RELEASE TO DOCK TO BOTTOM BEZEL"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(8.5)
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                    visible: parent.opacity > 0.5
                                }
                            }

                            // Drop / Rise Connection Traces Canvas (Vertical Guide Lines)
                            Canvas {
                                id: notchTraceCanvas
                                anchors.fill: parent
                                visible: root.notchBarsY > 3 && root.notchBarsY < (root.notchMaxY - 3)
                                z: 2

                                Connections {
                                    target: root
                                    function onNotchBarsYChanged() {
                                        notchTraceCanvas.requestPaint()
                                    }
                                }

                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)

                                    var inUpperHalf = root.notchBarsY <= (root.notchMaxY * 0.5)
                                    var yTarget = inUpperHalf ? 0 : height
                                    var yNotch = inUpperHalf ? root.notchBarsY : (root.notchBarsY + root.currentBarHeight)

                                    ctx.strokeStyle = Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
                                    ctx.lineWidth = 1.0
                                    ctx.setLineDash([3, 3])

                                    // Left ear tip
                                    var leftEarX = Math.round(leftBarWrapper.x + leftBarWrapper.width)
                                    ctx.beginPath()
                                    ctx.moveTo(1, yTarget)
                                    ctx.lineTo(1, yNotch)
                                    ctx.moveTo(leftEarX, yTarget)
                                    ctx.lineTo(leftEarX, yNotch)
                                    ctx.stroke()

                                    // Center ear tips
                                    var centerLeftX = Math.round(centerBarWrapper.x)
                                    var centerRightX = Math.round(centerBarWrapper.x + centerBarWrapper.width)
                                    ctx.beginPath()
                                    ctx.moveTo(centerLeftX, yTarget)
                                    ctx.lineTo(centerLeftX, yNotch)
                                    ctx.moveTo(centerRightX, yTarget)
                                    ctx.lineTo(centerRightX, yNotch)
                                    ctx.stroke()

                                    // Right ear tips
                                    var rightEarX = Math.round(rightBarWrapper.x)
                                    var rightEdgeX = Math.round(width - 1)
                                    ctx.beginPath()
                                    ctx.moveTo(rightEarX, yTarget)
                                    ctx.lineTo(rightEarX, yNotch)
                                    ctx.moveTo(rightEdgeX, yTarget)
                                    ctx.lineTo(rightEdgeX, yNotch)
                                    ctx.stroke()
                                }
                            }

                            // ── UNIFIED DRAGGABLE NOTCH CONTAINER (All bars move in unison) ──
                            Item {
                                id: notchBarsContainer
                                anchors.left: parent.left
                                anchors.right: parent.right
                                y: root.notchBarsY
                                height: root.currentBarHeight
                                z: 10
                                scale: root.isDraggingNotch ? 0.985 : 1.0
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                MouseArea {
                                    id: notchUnifiedDragArea
                                    anchors.fill: parent
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    property real startWorkspaceY: 0
                                    property real startNotchY: 0
                                    property bool movedBeyondThreshold: false

                                    onPressed: (mouse) => {
                                        var pt = mapToItem(blueprintWorkspace, mouse.x, mouse.y)
                                        startWorkspaceY = pt.y
                                        startNotchY = root.notchBarsY
                                        movedBeyondThreshold = false
                                        root.isDraggingNotch = true
                                    }

                                    onPositionChanged: (mouse) => {
                                        if (!pressed) return
                                        var pt = mapToItem(blueprintWorkspace, mouse.x, mouse.y)
                                        var delta = pt.y - startWorkspaceY
                                        if (Math.abs(delta) > 3) {
                                            movedBeyondThreshold = true
                                        }
                                        var newY = startNotchY + delta
                                        var maxY = root.notchMaxY
                                        root.notchBarsY = Math.max(0, Math.min(maxY, newY))

                                        // Realtime edge synchronization when dragging across midpoint
                                        if (root.notchBarsY > (maxY * 0.5) && root.notchDockPosition !== "bottom") {
                                            root.notchDockPosition = "bottom"
                                            root.saveBarEdgeConfig("bottom")
                                            bottomFlashAnim.restart()
                                        } else if (root.notchBarsY <= (maxY * 0.5) && root.notchDockPosition !== "top") {
                                            root.notchDockPosition = "top"
                                            root.saveBarEdgeConfig("top")
                                            topFlashAnim.restart()
                                        }
                                    }

                                    onReleased: (mouse) => {
                                        root.isDraggingNotch = false
                                        if (!movedBeyondThreshold) {
                                            // Click inside center bar region toggles expansion
                                            var localX = mouse.x
                                            if (localX >= centerBarWrapper.x && localX <= (centerBarWrapper.x + centerBarWrapper.width)) {
                                                root.centerExpanded = !root.centerExpanded
                                                return
                                            }
                                        }
                                        // Finished dragging: snap target docking border
                                        var maxY = root.notchMaxY
                                        if (root.notchBarsY > (maxY * 0.5)) {
                                            root.dockToBottom()
                                        } else {
                                            root.dockToTop()
                                        }
                                    }
                                }

                                // ── 1. LEFT NOTCH BAR (Flush Left Edge, Fillet on Right) ──
                                Item {
                                    id: leftBarWrapper
                                    anchors.left: parent.left
                                    y: root.notchBarsY > (root.notchMaxY * 0.5) ? (parent.height - height) : 0
                                    width: leftNotchBar.width
                                    height: leftNotchBar.height
                                    z: 2

                                    NotchContainer {
                                        id: leftNotchBar
                                        leftFillet: false
                                        rightFillet: true
                                        filletRadius: root.previewEarRadius
                                        bottomRadius: root.previewBottomRadius
                                        notchOpacity: root.previewNotchOpacity
                                        implicitHeight: root.previewNotchHeight
                                        height: root.previewNotchHeight
                                        attachedBottom: root.notchBarsY > (root.notchMaxY * 0.5)
                                        horizontalPadding: 10
                                        contentSpacing: 8
                                        mouseArea.enabled: false

                                        // Brand Logo Button
                                        Rectangle {
                                            z: 2
                                            width: 22
                                            height: 22
                                            radius: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: logoBtnMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : "transparent"
                                            border.color: logoBtnMouse.containsMouse ? Theme.primary : "transparent"
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: root.selectedLogo
                                                font.family: Theme.fontMono
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

                                        // Workspace Switcher Pills (Interactive)
                                        Row {
                                            z: 2
                                            spacing: 4
                                            anchors.verticalCenter: parent.verticalCenter

                                            Repeater {
                                                model: [1, 2, 3, 4]
                                                delegate: Rectangle {
                                                    required property int modelData
                                                    readonly property bool isSelected: root.activePreviewWorkspace === modelData

                                                    width: isSelected ? 22 : 16
                                                    height: 18
                                                    radius: 5
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : (wsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                                    border.color: isSelected ? Theme.primary : "transparent"
                                                    border.width: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: isSelected ? root.selectedActiveGlyph : root.selectedInactiveGlyph
                                                        font.family: Theme.fontMono
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

                                // ── 2. CENTER NOTCH BAR (Fillets on Both Sides, Expandable) ──
                                Item {
                                    id: centerBarWrapper
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: root.notchBarsY > (root.notchMaxY * 0.5) ? (parent.height - height) : 0
                                    width: centerNotchBar.width
                                    height: centerNotchBar.height
                                    z: root.centerExpanded ? 20 : 3

                                    NotchContainer {
                                        id: centerNotchBar
                                        leftFillet: true
                                        rightFillet: true
                                        filletRadius: root.previewEarRadius
                                        bottomRadius: root.centerExpanded ? 18 : root.previewBottomRadius
                                        notchOpacity: root.previewNotchOpacity
                                        implicitHeight: root.centerExpanded ? 240 : root.previewNotchHeight
                                        implicitWidth: root.centerExpanded ? Math.min(blueprintCard.width - 40, 560) : (contentImplicitWidth + (leftFillet ? filletRadius : 0) + (rightFillet ? filletRadius : 0) + (horizontalPadding * 2))
                                        height: implicitHeight
                                        width: implicitWidth
                                        attachedBottom: root.notchBarsY > (root.notchMaxY * 0.5)
                                        horizontalPadding: 12
                                        contentSpacing: 8
                                        mouseArea.enabled: false

                                        // Compact Content (visible when not expanded)
                                        Row {
                                            id: centerBarContent
                                            spacing: 8
                                            height: parent.height
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: !root.centerExpanded

                                            // Titan Clock
                                            Text {
                                                text: "10:19"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(12.5)
                                                font.weight: Font.Bold
                                                color: Theme.primary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            // Separator
                                            Text {
                                                text: "|"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(11)
                                                color: Qt.rgba(1, 1, 1, 0.25)
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            // Spinning Disc Glyph
                                            Text {
                                                text: "󰝚"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(12)
                                                color: Theme.primary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            // Track title
                                            Text {
                                                text: "Do I Wanna Know? • Arctic Monkeys"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(10.5)
                                                font.weight: Font.Medium
                                                color: Qt.rgba(1, 1, 1, 0.85)
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        // Expanded Pavilion Content (reparented directly to centerNotchBar)
                                        ColumnLayout {
                                            id: centerExpandedContent
                                            parent: centerNotchBar
                                            anchors.fill: parent
                                            anchors.margins: 14
                                            anchors.leftMargin: root.previewEarRadius + 14
                                            anchors.rightMargin: root.previewEarRadius + 14
                                            visible: root.centerExpanded
                                            spacing: 10
                                            z: 5

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

                                                // Column 2: Animated Tactical Chronometer Preview
                                                Rectangle {
                                                    Layout.preferredWidth: 180
                                                    Layout.fillHeight: true
                                                    radius: 10
                                                    color: Qt.rgba(0, 0, 0, 0.35)
                                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                                                    border.width: 1
                                                    clip: true

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

                                // ── 3. RIGHT NOTCH BAR (Flush Right Edge, Fillet on Left) ──
                                Item {
                                    id: rightBarWrapper
                                    anchors.right: parent.right
                                    y: root.notchBarsY > (root.notchMaxY * 0.5) ? (parent.height - height) : 0
                                    width: rightNotchBar.width
                                    height: rightNotchBar.height
                                    z: 2

                                    NotchContainer {
                                        id: rightNotchBar
                                        leftFillet: true
                                        rightFillet: false
                                        filletRadius: root.previewEarRadius
                                        bottomRadius: root.previewBottomRadius
                                        notchOpacity: root.previewNotchOpacity
                                        implicitHeight: root.previewNotchHeight
                                        height: root.previewNotchHeight
                                        attachedBottom: root.notchBarsY > (root.notchMaxY * 0.5)
                                        horizontalPadding: 10
                                        contentSpacing: 8
                                        mouseArea.enabled: false

                                        Row {
                                            id: rightBarContent
                                            spacing: 8
                                            height: parent.height
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                text: "󰕾"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(12)
                                                color: Qt.rgba(1, 1, 1, 0.70)
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: "󰤨"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(12)
                                                color: Qt.rgba(1, 1, 1, 0.70)
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Text {
                                                text: "󰁹 98%"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(10)
                                                font.weight: Font.DemiBold
                                                color: Theme.primary
                                                anchors.verticalCenter: parent.verticalCenter
                                            }

                                            Rectangle {
                                                width: 16
                                                height: 16
                                                radius: 4
                                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                                                anchors.verticalCenter: parent.verticalCenter

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
                            } // end notchBarsContainer
                        } // end blueprintWorkspace
                } // end blueprintCard
            } // end blueprintSection

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

                        // Mode Enable / Disable Toggle Button
                        Rectangle {
                            readonly property bool isEnabled: root.activeSystemMode === "notch" || root.activeSystemMode === "pill"
                            height: 28
                            width: notchModeToggleRow.implicitWidth + 24
                            radius: 6
                            color: isEnabled 
                                ? (notchModeToggleMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18))
                                : (notchModeToggleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.25))
                            border.color: isEnabled ? Theme.primary : (notchModeToggleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12))
                            border.width: 1

                            RowLayout {
                                id: notchModeToggleRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: parent.parent.isEnabled ? "󰄬" : "󰄱"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(11)
                                    color: parent.parent.isEnabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.50)
                                }

                                Text {
                                    text: parent.parent.isEnabled ? "Notch Mode Enabled" : "Enable Notch Mode"
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(10.5)
                                    font.weight: Font.DemiBold
                                    color: parent.parent.isEnabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.85)
                                }
                            }

                            MouseArea {
                                id: notchModeToggleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (parent.isEnabled) {
                                        root.activateMode("nucleus")
                                    } else {
                                        root.activateMode("notch")
                                    }
                                }
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

                                // ── Bottom Bar Active Quick Banner ───────────
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 38
                                    radius: 8
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                                    border.width: 1
                                    visible: root.notchDockPosition === "bottom"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10

                                        Text {
                                            text: "󰘕"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontPx(14)
                                            color: Theme.primary
                                        }

                                        Text {
                                            text: "Bottom Notch Bar Active — Bezel-docked geometry engaged."
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontPx(11)
                                            font.weight: Font.Medium
                                            color: Qt.rgba(1, 1, 1, 0.90)
                                        }

                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            Layout.preferredHeight: 24
                                            Layout.preferredWidth: 154
                                            radius: 5
                                            color: Theme.primary

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Configure Bottom Bar 󰄾"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(10)
                                                font.weight: Font.Bold
                                                color: Theme.m3onPrimary || "#000000"
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.activeSubSection = "Settings"
                                            }
                                        }
                                    }
                                }

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

                                // ── Top Bezel Status Card ──
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 48
                                    radius: 10
                                    color: Qt.rgba(0, 0, 0, 0.22)
                                    border.color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1
                                    visible: root.notchDockPosition === "top"

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 10

                                        Text {
                                            text: "󰘚"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontPx(14)
                                            color: Theme.primary
                                        }

                                        ColumnLayout {
                                            spacing: 1
                                            Text {
                                                text: "Top Bezel Dock Active"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(11.5)
                                                font.weight: Font.Bold
                                                color: Qt.rgba(1, 1, 1, 0.90)
                                            }
                                            Text {
                                                text: "Drag the blueprint bar downward to dock to bottom and reveal bottom bar controls."
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(9.5)
                                                color: Qt.rgba(1, 1, 1, 0.45)
                                            }
                                        }

                                        Item { Layout.fillWidth: true }

                                        Rectangle {
                                            Layout.preferredHeight: 24
                                            Layout.preferredWidth: 130
                                            radius: 5
                                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                            border.color: Theme.primary
                                            border.width: 1

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                Text {
                                                    text: "󰘕"
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontPx(10)
                                                    color: Theme.primary
                                                }
                                                Text {
                                                    text: "Dock to Bottom"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(9.5)
                                                    font.weight: Font.DemiBold
                                                    color: Theme.primary
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.dockToBottom()
                                            }
                                        }
                                    }
                                }

                                // ── Dedicated Bottom Bar Configuration Card ──
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: bottomBarCol.implicitHeight + 28
                                    radius: 12
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                                    border.width: 1
                                    visible: root.notchDockPosition === "bottom"

                                    ColumnLayout {
                                        id: bottomBarCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        RowLayout {
                                            Layout.fillWidth: true

                                            ColumnLayout {
                                                spacing: 2
                                                Text {
                                                    text: "󰘕  Bottom Bar Configuration & Bezel Dynamics"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(13)
                                                    font.weight: Font.Bold
                                                    color: Theme.primary
                                                }
                                                Text {
                                                    text: "Settings tailored for when notch bars are docked to the bottom of the screen."
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(10.5)
                                                    color: Qt.rgba(1, 1, 1, 0.60)
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            Rectangle {
                                                Layout.preferredHeight: 24
                                                Layout.preferredWidth: 124
                                                radius: 5
                                                color: Qt.rgba(1, 1, 1, 0.08)
                                                border.color: Qt.rgba(1, 1, 1, 0.15)
                                                border.width: 1

                                                RowLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 4
                                                    Text {
                                                        text: "󰘚"
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontPx(10)
                                                        color: Theme.primary
                                                    }
                                                    Text {
                                                        text: "Dock to Top"
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.fontPx(9.5)
                                                        color: Qt.rgba(1, 1, 1, 0.85)
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.dockToTop()
                                                }
                                            }
                                        }

                                        RazorWireSlider {
                                            Layout.fillWidth: true
                                            label: "Bottom Window Clearance / App Gap"
                                            from: 0
                                            to: 32
                                            value: root.previewBottomGap
                                            unit: "px"
                                            onMoved: function(v) {
                                                root.previewBottomGap = Math.round(v)
                                                root.saveBottomSetting("notchAppGap", Math.round(v))
                                            }
                                        }

                                        RazorWireSlider {
                                            Layout.fillWidth: true
                                            label: "Bottom Edge Lift / Offset"
                                            from: 0
                                            to: 20
                                            value: root.previewBottomOffset
                                            unit: "px"
                                            onMoved: function(v) {
                                                root.previewBottomOffset = Math.round(v)
                                                root.saveBottomSetting("bottomOffset", Math.round(v))
                                            }
                                        }

                                        // Bottom Exclusive Zone Toggle
                                        RowLayout {
                                            Layout.fillWidth: true

                                            ColumnLayout {
                                                spacing: 2
                                                Text {
                                                    text: "Reserve Space on Bottom Bezel"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(12)
                                                    color: Qt.rgba(1, 1, 1, 0.90)
                                                }
                                                Text {
                                                    text: "Pushes tiled and maximized windows upward to prevent overlapping the bottom notch bars."
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
                                                color: root.previewBottomExclusiveZone ? Theme.primary : Qt.rgba(1, 1, 1, 0.15)

                                                Behavior on color { ColorAnimation { duration: 180 } }

                                                Rectangle {
                                                    width: 18
                                                    height: 18
                                                    radius: 9
                                                    color: root.previewBottomExclusiveZone ? (Theme.m3onPrimary || Theme.bg || "#000000") : (Theme.fg || "#ffffff")
                                                    x: root.previewBottomExclusiveZone ? 23 : 3
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.previewBottomExclusiveZone = !root.previewBottomExclusiveZone
                                                        root.saveBottomSetting("exclusiveZone", root.previewBottomExclusiveZone)
                                                    }
                                                }
                                            }
                                        }

                                        // Smart Bottom Autohide Toggle
                                        RowLayout {
                                            Layout.fillWidth: true

                                            ColumnLayout {
                                                spacing: 2
                                                Text {
                                                    text: "Smart Bottom Autohide on Fullscreen"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(12)
                                                    color: Qt.rgba(1, 1, 1, 0.90)
                                                }
                                                Text {
                                                    text: "Smoothly tuck the notch bar away when a window is focused in full screen mode."
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
                                                color: root.previewBottomAutohide ? Theme.primary : Qt.rgba(1, 1, 1, 0.15)

                                                Behavior on color { ColorAnimation { duration: 180 } }

                                                Rectangle {
                                                    width: 18
                                                    height: 18
                                                    radius: 9
                                                    color: root.previewBottomAutohide ? (Theme.m3onPrimary || Theme.bg || "#000000") : (Theme.fg || "#ffffff")
                                                    x: root.previewBottomAutohide ? 23 : 3
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.previewBottomAutohide = !root.previewBottomAutohide
                                                        root.saveBottomSetting("autohide", root.previewBottomAutohide)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

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
            // ---------------------------------------------------------------
            // MODE 1: MINIMAL ISLAND (Compact Floating Dynamic Pill)
            // ---------------------------------------------------------------
            ColumnLayout {
                anchors.fill: parent
                visible: root.currentMode === 1
                spacing: 0

                // Sub-header Row with Mode Enable/Disable Toggle
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16

                    RowLayout {
                        anchors.fill: parent

                        Text {
                            text: "MINIMAL ISLAND // COMPACT DYNAMIC PILL"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(9.5)
                            font.weight: Font.Bold
                            color: Qt.rgba(1, 1, 1, 0.45)
                        }

                        Item { Layout.fillWidth: true }

                        // Mode Enable / Disable Toggle Button
                        Rectangle {
                            readonly property bool isEnabled: root.activeSystemMode === "minimal" || root.activeSystemMode === "minimal_notch"
                            height: 28
                            width: minToggleRow.implicitWidth + 24
                            radius: 6
                            color: isEnabled 
                                ? (minToggleMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18))
                                : (minToggleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.25))
                            border.color: isEnabled ? Theme.primary : (minToggleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12))
                            border.width: 1

                            RowLayout {
                                id: minToggleRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: parent.parent.isEnabled ? "󰄬" : "󰄱"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(11)
                                    color: parent.parent.isEnabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.50)
                                }

                                Text {
                                    text: parent.parent.isEnabled ? "Minimal Island Enabled" : "Enable Minimal Island"
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(10.5)
                                    font.weight: Font.DemiBold
                                    color: parent.parent.isEnabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.85)
                                }
                            }

                            MouseArea {
                                id: minToggleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (parent.isEnabled) {
                                        root.activateMode("notch")
                                    } else {
                                        root.activateMode("minimal")
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.centerIn: parent
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
                            text: "Ultra-compact single pill bar with floating dynamic island expansions.\nClick the button above to enable this mode on your desktop."
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(11.5)
                            color: Qt.rgba(1, 1, 1, 0.50)
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            // ---------------------------------------------------------------
            // MODE 2: VANISH // NUCLEUS (Barless sp³ Radial Desktop Studio)
            // ---------------------------------------------------------------
            ColumnLayout {
                anchors.fill: parent
                visible: root.currentMode === 2
                spacing: 0

                // ── 1. Blueprint Canvas Preview Section ────────────────────
                Item {
                    id: vanishBlueprintSection
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.vanishMediaPlaying ? 400 : 330
                    Layout.minimumHeight: 280
                    clip: true

                    Behavior on Layout.preferredHeight {
                        NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                    }

                    // Inset Rounded Card Container with 1px border
                    Rectangle {
                        id: vanishBlueprintCard
                        anchors.fill: parent
                        anchors.margins: 14
                        radius: 14
                        color: Qt.rgba(0, 0, 0, 0.40)
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        clip: true

                        // Dotted Matrix Grid Canvas (Crisp 1.2px dots, 18px grid)
                        Canvas {
                            id: vanishBlueprintDots
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
                            height: 24
                            color: Qt.rgba(0, 0, 0, 0.35)
                            border.color: Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12

                                Text {
                                    text: "BLUEPRINT // VANISH MODE (BARLESS SP³ HYBRID NUCLEUS)"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(8.5)
                                    font.weight: Font.Bold
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                                }

                                Item { Layout.fillWidth: true }

                                // Interactive Music Preview Toggle Switch / Pill
                                Rectangle {
                                    Layout.preferredHeight: 18
                                    Layout.preferredWidth: mediaToggleRow.implicitWidth + 14
                                    radius: 999
                                    color: root.vanishMediaPlaying ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : Qt.rgba(1, 1, 1, 0.06)
                                    border.color: root.vanishMediaPlaying ? Theme.primary : Qt.rgba(1, 1, 1, 0.14)
                                    border.width: 1

                                    RowLayout {
                                        id: mediaToggleRow
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Text {
                                            text: root.vanishMediaPlaying ? "󰝚" : "󰝛"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontPx(9.5)
                                            color: root.vanishMediaPlaying ? Theme.primary : Qt.rgba(1, 1, 1, 0.45)
                                        }

                                        Text {
                                            text: root.vanishMediaPlaying ? "MUSIC PLAYING: ON" : "MUSIC: OFF (RESTING)"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontPx(8)
                                            font.weight: Font.Bold
                                            color: root.vanishMediaPlaying ? Theme.primary : Qt.rgba(1, 1, 1, 0.60)
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.vanishMediaPlaying = !root.vanishMediaPlaying
                                    }
                                }
                            }
                        }

                        // ── Blueprint Screen Workspace ─────────────────────
                        Item {
                            id: vanishWorkspace
                            anchors.fill: parent
                            anchors.topMargin: 24

                            // ── Center Vanish Hub System ──
                            Item {
                                id: vanishHubContainer
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: root.vanishMediaPlaying ? 24 : 50
                                width: 360
                                height: 200

                                Behavior on y {
                                    NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                                }

                                // 60fps continuous phase accumulator for preview orbit spin
                                property real previewPhase: 0.0
                                Timer {
                                    interval: 16
                                    running: root.currentMode === 2
                                    repeat: true
                                    onTriggered: {
                                        vanishHubContainer.previewPhase = (vanishHubContainer.previewPhase + 0.02) % 628.3
                                    }
                                }

                                // ── Orbital Guide Rings & Rotating Carbon Valence Electrons ──
                                Canvas {
                                    id: vanishOrbitsCanvas
                                    anchors.centerIn: parent
                                    width: 240
                                    height: 240
                                    z: 1

                                    Connections {
                                        target: vanishHubContainer
                                        function onPreviewPhaseChanged() {
                                            vanishOrbitsCanvas.requestPaint()
                                        }
                                    }

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        var cx = width / 2
                                        var cy = height / 2
                                        var phase = vanishHubContainer.previewPhase
                                        var primaryCol = Theme.primary

                                        // Orbit Ring 1 (Inner, r = 46px)
                                        ctx.save()
                                        ctx.lineWidth = 1
                                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.08)
                                        ctx.setLineDash([4, 4])
                                        ctx.beginPath()
                                        ctx.arc(cx, cy, 46, 0, Math.PI * 2)
                                        ctx.stroke()
                                        ctx.restore()

                                        // 2 Inner Electrons (moving along Ring 1)
                                        var e1_angle = phase * 0.4
                                        for (var k = 0; k < 2; k++) {
                                            var a = e1_angle + (k * Math.PI)
                                            var ex = cx + 46 * Math.cos(a)
                                            var ey = cy + 46 * Math.sin(a)
                                            ctx.fillStyle = primaryCol
                                            ctx.beginPath()
                                            ctx.arc(ex, ey, 2.5, 0, Math.PI * 2)
                                            ctx.fill()
                                        }

                                        // Orbit Ring 2 (Outer, r = 82px)
                                        ctx.save()
                                        ctx.lineWidth = 1
                                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06)
                                        ctx.setLineDash([3, 5])
                                        ctx.beginPath()
                                        ctx.arc(cx, cy, 82, 0, Math.PI * 2)
                                        ctx.stroke()
                                        ctx.restore()

                                        // 4 Outer Valence Electrons (moving counter-clockwise)
                                        var e2_angle = -phase * 0.28
                                        for (var j = 0; j < 4; j++) {
                                            var a2 = e2_angle + (j * (Math.PI / 2))
                                            var ex2 = cx + 82 * Math.cos(a2)
                                            var ey2 = cy + 82 * Math.sin(a2)
                                            ctx.fillStyle = primaryCol
                                            ctx.beginPath()
                                            ctx.arc(ex2, ey2, 2.5, 0, Math.PI * 2)
                                            ctx.fill()
                                        }

                                        // Dotted Tracers connecting Center to the 4 Satellites (-65°, 25°, 135°, 205°)
                                        var satAngles = [-65 * Math.PI / 180, 25 * Math.PI / 180, 135 * Math.PI / 180, 205 * Math.PI / 180]
                                        ctx.save()
                                        ctx.lineWidth = 1
                                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.12)
                                        ctx.setLineDash([2, 4])
                                        for (var s = 0; s < 4; s++) {
                                            ctx.beginPath()
                                            ctx.moveTo(cx, cy)
                                            ctx.lineTo(cx + 95 * Math.cos(satAngles[s]), cy + 95 * Math.sin(satAngles[s]))
                                            ctx.stroke()
                                        }
                                        ctx.restore()
                                    }
                                }

                                // ── 4 Radial sp³ Satellites ──
                                // 1. Top-Left (-65°): Connect / Mixer
                                Rectangle {
                                    x: (parent.width / 2) + 95 * Math.cos(-65 * Math.PI / 180) - (width / 2)
                                    y: (parent.height / 2) + 95 * Math.sin(-65 * Math.PI / 180) - (height / 2)
                                    width: 34
                                    height: 34
                                    radius: 17
                                    z: 4
                                    color: Qt.rgba(0.06, 0.07, 0.09, 0.90)
                                    border.color: sat1Mouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.18)
                                    border.width: 1.2
                                    scale: sat1Mouse.containsMouse ? 1.12 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 140 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰕾"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(13)
                                        color: sat1Mouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.80)
                                    }

                                    MouseArea {
                                        id: sat1Mouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }

                                // 2. Top-Right (25°): Launcher
                                Rectangle {
                                    x: (parent.width / 2) + 95 * Math.cos(25 * Math.PI / 180) - (width / 2)
                                    y: (parent.height / 2) + 95 * Math.sin(25 * Math.PI / 180) - (height / 2)
                                    width: 34
                                    height: 34
                                    radius: 17
                                    z: 4
                                    color: Qt.rgba(0.06, 0.07, 0.09, 0.90)
                                    border.color: sat2Mouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.18)
                                    border.width: 1.2
                                    scale: sat2Mouse.containsMouse ? 1.12 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 140 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰀻"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(13)
                                        color: sat2Mouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.80)
                                    }

                                    MouseArea {
                                        id: sat2Mouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }

                                // 3. Bottom-Right (135°): Spaces / Workspaces
                                Rectangle {
                                    x: (parent.width / 2) + 95 * Math.cos(135 * Math.PI / 180) - (width / 2)
                                    y: (parent.height / 2) + 95 * Math.sin(135 * Math.PI / 180) - (height / 2)
                                    width: 34
                                    height: 34
                                    radius: 17
                                    z: 4
                                    color: Qt.rgba(0.06, 0.07, 0.09, 0.90)
                                    border.color: sat3Mouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.18)
                                    border.width: 1.2
                                    scale: sat3Mouse.containsMouse ? 1.12 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 140 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰍹"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(13)
                                        color: sat3Mouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.80)
                                    }

                                    MouseArea {
                                        id: sat3Mouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }

                                // 4. Bottom-Left (205°): Alerts & System
                                Rectangle {
                                    x: (parent.width / 2) + 95 * Math.cos(205 * Math.PI / 180) - (width / 2)
                                    y: (parent.height / 2) + 95 * Math.sin(205 * Math.PI / 180) - (height / 2)
                                    width: 34
                                    height: 34
                                    radius: 17
                                    z: 4
                                    color: Qt.rgba(0.06, 0.07, 0.09, 0.90)
                                    border.color: sat4Mouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.18)
                                    border.width: 1.2
                                    scale: sat4Mouse.containsMouse ? 1.12 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 140 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰂚"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(13)
                                        color: sat4Mouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.80)
                                    }

                                    MouseArea {
                                        id: sat4Mouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                }

                                // ── Center Core Disc ──
                                Rectangle {
                                    id: vanishCoreDisc
                                    anchors.centerIn: parent
                                    width: 58
                                    height: 58
                                    radius: 29
                                    z: 5
                                    color: Qt.rgba(0.04, 0.05, 0.07, 0.96)
                                    border.color: root.vanishMediaPlaying ? Theme.primary : Qt.rgba(1, 1, 1, 0.22)
                                    border.width: 1.5

                                    // Pulsing Halo Glow when media is playing
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width + 10
                                        height: parent.height + 10
                                        radius: width / 2
                                        color: "transparent"
                                        border.color: Theme.primary
                                        border.width: 1
                                        opacity: root.vanishMediaPlaying ? 0.45 : 0.0
                                        z: -1
                                        Behavior on opacity { NumberAnimation { duration: 250 } }
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 1

                                        Text {
                                            text: "13:42"
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontPx(11.5)
                                            font.weight: Font.Bold
                                            color: Theme.primary
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        Text {
                                            text: "OCT 31"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontPx(7.5)
                                            color: Qt.rgba(1, 1, 1, 0.55)
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }
                                }
                            }

                            // ── Organic Music Player & Synced Lyrics Overlay (Appears below Nucleus when Media is Playing) ──
                            Item {
                                id: vanishMediaCard
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: vanishHubContainer.bottom
                                anchors.topMargin: 12
                                width: Math.min(parent.width - 32, 420)
                                height: 74
                                visible: opacity > 0.01
                                opacity: root.vanishMediaPlaying ? 1.0 : 0.0
                                scale: root.vanishMediaPlaying ? 1.0 : 0.92

                                Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 12
                                    color: Qt.rgba(0.04, 0.05, 0.08, 0.85)
                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                                    border.width: 1
                                    clip: true

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 4

                                        // Top Row: Album Art + Track Info + Transport Controls
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            // Rotating Vinyl / Album Art Micro-Orb
                                            Rectangle {
                                                Layout.preferredWidth: 28
                                                Layout.preferredHeight: 28
                                                radius: 14
                                                color: Qt.rgba(0, 0, 0, 0.50)
                                                border.color: Theme.primary
                                                border.width: 1.2
                                                clip: true

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰝚"
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: 13
                                                    color: Theme.primary
                                                }

                                                RotationAnimation on rotation {
                                                    running: root.vanishMediaPlaying
                                                    loops: Animation.Infinite
                                                    from: 0
                                                    to: 360
                                                    duration: 4000
                                                }
                                            }

                                            // Track & Artist Title
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1

                                                Text {
                                                    text: "Do I Wanna Know?"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(11.5)
                                                    font.weight: Font.Bold
                                                    color: Qt.rgba(1, 1, 0.95, 1.0)
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }

                                                Text {
                                                    text: "Arctic Monkeys • AM"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(9.5)
                                                    color: Qt.rgba(1, 1, 1, 0.55)
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }

                                            // Valence Circular Transport Buttons
                                            RowLayout {
                                                spacing: 6

                                                // Skip Previous
                                                Rectangle {
                                                    Layout.preferredWidth: 22
                                                    Layout.preferredHeight: 22
                                                    radius: 11
                                                    color: Qt.rgba(1, 1, 1, 0.08)
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰒮"
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: 11
                                                        color: Qt.rgba(1, 1, 1, 0.75)
                                                    }
                                                }

                                                // Play / Pause (Accent)
                                                Rectangle {
                                                    Layout.preferredWidth: 24
                                                    Layout.preferredHeight: 24
                                                    radius: 12
                                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                                                    border.color: Theme.primary
                                                    border.width: 1
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰏤"
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: 12
                                                        color: Theme.primary
                                                    }
                                                }

                                                // Skip Next
                                                Rectangle {
                                                    Layout.preferredWidth: 22
                                                    Layout.preferredHeight: 22
                                                    radius: 11
                                                    color: Qt.rgba(1, 1, 1, 0.08)
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "󰒭"
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: 11
                                                        color: Qt.rgba(1, 1, 1, 0.75)
                                                    }
                                                }
                                            }
                                        }

                                        // Bottom Row: Scrubber Bar + Live Lyric Line
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8

                                            // Scrubber Bar
                                            Rectangle {
                                                Layout.preferredWidth: 100
                                                Layout.preferredHeight: 3
                                                radius: 1.5
                                                color: Qt.rgba(1, 1, 1, 0.12)

                                                Rectangle {
                                                    width: parent.width * 0.42
                                                    height: parent.height
                                                    radius: parent.radius
                                                    color: Theme.primary
                                                }
                                            }

                                            Text {
                                                text: "01:42"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(8)
                                                color: Qt.rgba(1, 1, 1, 0.40)
                                            }

                                            Item { Layout.fillWidth: true }

                                            // Floating Synced Lyric Line
                                            RowLayout {
                                                spacing: 4
                                                Text {
                                                    text: "󰎈"
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontPx(9)
                                                    color: Theme.primary
                                                }
                                                Text {
                                                    text: "\"Crawlin' back to you...\""
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(10)
                                                    font.italic: true
                                                    color: Theme.primary
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 2. Separator Hairline ──────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                // ── 3. Sub-Section Switcher: "Designs" vs "Settings" ───────
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
                                    color: root.vanishSubSection === "Designs" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : "transparent"
                                    border.color: root.vanishSubSection === "Designs" ? Theme.primary : "transparent"
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰙵  Designs"
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(11)
                                        font.weight: root.vanishSubSection === "Designs" ? Font.Bold : Font.Normal
                                        color: root.vanishSubSection === "Designs" ? Theme.primary : Qt.rgba(1, 1, 1, 0.65)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.vanishSubSection = "Designs"
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 7
                                    color: root.vanishSubSection === "Settings" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : "transparent"
                                    border.color: root.vanishSubSection === "Settings" ? Theme.primary : "transparent"
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰒓  Settings"
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(11)
                                        font.weight: root.vanishSubSection === "Settings" ? Font.Bold : Font.Normal
                                        color: root.vanishSubSection === "Settings" ? Theme.primary : Qt.rgba(1, 1, 1, 0.65)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.vanishSubSection = "Settings"
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Quick Toggle Media Preview Button in sub-header
                        Rectangle {
                            height: 28
                            width: vanishPreviewBtnText.implicitWidth + 20
                            radius: 6
                            color: vanishPreviewBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.20)
                            border.color: vanishPreviewBtnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1

                            Text {
                                id: vanishPreviewBtnText
                                anchors.centerIn: parent
                                text: root.vanishMediaPlaying ? "󰝛  Hide Media" : "󰝚  Show Media"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(10)
                                color: Qt.rgba(1, 1, 1, 0.75)
                            }

                            MouseArea {
                                id: vanishPreviewBtnMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.vanishMediaPlaying = !root.vanishMediaPlaying
                            }
                        }

                        // Mode Enable / Disable Toggle Button
                        Rectangle {
                            readonly property bool isEnabled: root.activeSystemMode === "nucleus" || root.activeSystemMode === "vanish"
                            height: 28
                            width: vanishToggleRow.implicitWidth + 24
                            radius: 6
                            color: isEnabled 
                                ? (vanishToggleMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18))
                                : (vanishToggleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.25))
                            border.color: isEnabled ? Theme.primary : (vanishToggleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.12))
                            border.width: 1

                            RowLayout {
                                id: vanishToggleRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: parent.parent.isEnabled ? "󰄬" : "󰄱"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(11)
                                    color: parent.parent.isEnabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.50)
                                }

                                Text {
                                    text: parent.parent.isEnabled ? "Vanish Mode Enabled" : "Enable Vanish Mode"
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(10.5)
                                    font.weight: Font.DemiBold
                                    color: parent.parent.isEnabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.85)
                                }
                            }

                            MouseArea {
                                id: vanishToggleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (parent.isEnabled) {
                                        root.activateMode("notch")
                                    } else {
                                        root.activateMode("nucleus")
                                    }
                                }
                            }
                        }
                    }
                }

                // ── 4. Scrollable Controls Body ────────────────────────────
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Flickable {
                        id: vanishControlsFlickable
                        anchors.fill: parent
                        contentWidth: width
                        contentHeight: vanishControlsColumn.implicitHeight + 30
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: vanishControlsColumn
                            width: vanishControlsFlickable.width - 32
                            x: 16
                            y: 8
                            spacing: 14

                            // ===============================================
                            // SUB-SECTION 1: DESIGNS (Empty placeholder slots)
                            // ===============================================
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.vanishSubSection === "Designs"
                                spacing: 14

                                // Section Heading
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "VANISH NUCLEUS // THEMES & ORBITAL VARIATIONS"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(11)
                                        font.weight: Font.Bold
                                        color: Qt.rgba(1, 1, 1, 0.90)
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: "BARLESS SP³ TOPOLOGY"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(9)
                                        color: Theme.primary
                                    }
                                }

                                // Grid of Variations: 1 active default + empty coming-soon cards
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    // Active Card: sp3 Hybrid Orbital
                                    Rectangle {
                                        width: 260
                                        height: 120
                                        radius: 10
                                        color: Qt.rgba(0.05, 0.06, 0.08, 0.80)
                                        border.color: Theme.primary
                                        border.width: 1.5

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    text: "󱐋"
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontPx(16)
                                                    color: Theme.primary
                                                }
                                                Text {
                                                    text: "sp³ Hybrid Orbital"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(12)
                                                    font.weight: Font.Bold
                                                    color: "#FFFFFF"
                                                }
                                                Item { Layout.fillWidth: true }
                                                Rectangle {
                                                    Layout.preferredWidth: 50
                                                    Layout.preferredHeight: 18
                                                    radius: 4
                                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "ACTIVE"
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: Theme.fontPx(8)
                                                        font.weight: Font.Bold
                                                        color: Theme.primary
                                                    }
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: "Tetrahedral 4-satellite valence system with continuous electron spin and floating media."
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(10)
                                                color: Qt.rgba(1, 1, 1, 0.60)
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }

                                    // Empty Slot 1: Coming Soon
                                    Rectangle {
                                        width: 260
                                        height: 120
                                        radius: 10
                                        color: Qt.rgba(0, 0, 0, 0.15)
                                        border.color: Qt.rgba(1, 1, 1, 0.10)
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: "󰐕"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(22)
                                                color: Qt.rgba(1, 1, 1, 0.25)
                                                Layout.alignment: Qt.AlignHCenter
                                            }

                                            Text {
                                                text: "Variation Slot #2"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(11.5)
                                                font.weight: Font.Bold
                                                color: Qt.rgba(1, 1, 1, 0.50)
                                                Layout.alignment: Qt.AlignHCenter
                                            }

                                            Text {
                                                text: "No variations created yet"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(9.5)
                                                color: Qt.rgba(1, 1, 1, 0.30)
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }
                                    }

                                    // Empty Slot 2: Coming Soon
                                    Rectangle {
                                        width: 260
                                        height: 120
                                        radius: 10
                                        color: Qt.rgba(0, 0, 0, 0.15)
                                        border.color: Qt.rgba(1, 1, 1, 0.10)
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: "󰐕"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(22)
                                                color: Qt.rgba(1, 1, 1, 0.25)
                                                Layout.alignment: Qt.AlignHCenter
                                            }

                                            Text {
                                                text: "Variation Slot #3"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(11.5)
                                                font.weight: Font.Bold
                                                color: Qt.rgba(1, 1, 1, 0.50)
                                                Layout.alignment: Qt.AlignHCenter
                                            }

                                            Text {
                                                text: "No variations created yet"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(9.5)
                                                color: Qt.rgba(1, 1, 1, 0.30)
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }
                                    }

                                    // Create Custom Variation Slot
                                    Rectangle {
                                        width: 260
                                        height: 120
                                        radius: 10
                                        color: createVarMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08) : Qt.rgba(0, 0, 0, 0.12)
                                        border.color: createVarMouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.10)
                                        border.width: 1

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 6

                                            Text {
                                                text: "󰐕"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(20)
                                                color: createVarMouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.35)
                                                Layout.alignment: Qt.AlignHCenter
                                            }

                                            Text {
                                                text: "+ New Orbital Variation"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(11)
                                                font.weight: Font.Bold
                                                color: createVarMouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.60)
                                                Layout.alignment: Qt.AlignHCenter
                                            }

                                            Text {
                                                text: "Studio builder coming in update"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(9)
                                                color: Qt.rgba(1, 1, 1, 0.30)
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                        }

                                        MouseArea {
                                            id: createVarMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                    }
                                }
                            }

                            // ===============================================
                            // SUB-SECTION 2: SETTINGS (Live Vanish Mode Settings)
                            // ===============================================
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.vanishSubSection === "Settings"
                                spacing: 14

                                // ── Card 1: Transition Dynamics ───────────
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: transCol.implicitHeight + 28
                                    radius: 12
                                    color: Qt.rgba(0, 0, 0, 0.22)
                                    border.color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1

                                    ColumnLayout {
                                        id: transCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "TRANSITION DYNAMICS"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(10)
                                                font.weight: Font.Bold
                                                color: Theme.primary
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: root.vanishTransitionEnabled ? "ENABLED" : "DIRECT"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(9)
                                                color: Qt.rgba(1, 1, 1, 0.45)
                                            }
                                        }

                                        // Toggle: Enable Cinematic Transition Overlay
                                        RowLayout {
                                            Layout.fillWidth: true
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text {
                                                    text: "Cinematic Transition Overlay"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(11.5)
                                                    font.weight: Font.Medium
                                                    color: "#FFFFFF"
                                                }
                                                Text {
                                                    text: "Play full-screen cinematic overlay when opening or vanishing the hub."
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(9.5)
                                                    color: Qt.rgba(1, 1, 1, 0.45)
                                                }
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 38
                                                Layout.preferredHeight: 20
                                                radius: 10
                                                color: root.vanishTransitionEnabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.15)

                                                Rectangle {
                                                    x: root.vanishTransitionEnabled ? parent.width - width - 2 : 2
                                                    y: 2
                                                    width: 16
                                                    height: 16
                                                    radius: 8
                                                    color: root.vanishTransitionEnabled ? (Theme.m3onPrimary || "#000000") : "#FFFFFF"

                                                    Behavior on x {
                                                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.vanishTransitionEnabled = !root.vanishTransitionEnabled
                                                        root.saveVanishConfig("nucleus.transition", root.vanishTransitionEnabled)
                                                    }
                                                }
                                            }
                                        }

                                        // Slider: Transition Duration
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text {
                                                    text: "Transition Duration"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(11.5)
                                                    font.weight: Font.Medium
                                                    color: "#FFFFFF"
                                                }
                                                Text {
                                                    text: "Length of the wallpaper blur, satellite expansion, and atom collapse."
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(9.5)
                                                    color: Qt.rgba(1, 1, 1, 0.45)
                                                }
                                            }

                                            Slider {
                                                Layout.preferredWidth: 160
                                                from: 300
                                                to: 1500
                                                stepSize: 50
                                                value: root.vanishWallpaperDuration
                                                onMoved: {
                                                    root.vanishWallpaperDuration = Math.round(value)
                                                    root.saveVanishConfig("wallpaperDuration", root.vanishWallpaperDuration)
                                                }
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 54
                                                Layout.preferredHeight: 22
                                                radius: 4
                                                color: Qt.rgba(1, 1, 1, 0.08)
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: root.vanishWallpaperDuration + " ms"
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: Theme.fontPx(9)
                                                    color: Theme.primary
                                                }
                                            }
                                        }

                                        // Option Selector: Transition Wordmark
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            ColumnLayout {
                                                Layout.preferredWidth: 150
                                                spacing: 2
                                                Text {
                                                    text: "Transition Wordmark"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(11.5)
                                                    font.weight: Font.Medium
                                                    color: "#FFFFFF"
                                                }
                                                Text {
                                                    text: "Text displayed momentarily."
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(9.5)
                                                    color: Qt.rgba(1, 1, 1, 0.45)
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Repeater {
                                                    model: ["Wooshh!!", "Vanish", "Hyperdrive", "Quantum", "Zero"]
                                                    delegate: Rectangle {
                                                        required property string modelData
                                                        readonly property bool isSelected: root.vanishTransitionWord === modelData

                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 24
                                                        radius: 6
                                                        color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : (wordMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                                        border.color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                                                        border.width: 1

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData
                                                            font.family: Theme.font
                                                            font.pixelSize: Theme.fontPx(10)
                                                            font.weight: isSelected ? Font.Bold : Font.Normal
                                                            color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.70)
                                                        }

                                                        MouseArea {
                                                            id: wordMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                root.vanishTransitionWord = modelData
                                                                root.saveVanishConfig("nucleus.transitionWord", modelData)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // ── Card 2: Resting Desktop Atom ──────────
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: restingCol.implicitHeight + 28
                                    radius: 12
                                    color: Qt.rgba(0, 0, 0, 0.22)
                                    border.color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1

                                    ColumnLayout {
                                        id: restingCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "RESTING DESKTOP ATOM"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(10)
                                                font.weight: Font.Bold
                                                color: Theme.primary
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: root.vanishShowRestingAtom ? "VISIBLE ON WALLPAPER" : "HIDDEN"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(9)
                                                color: Qt.rgba(1, 1, 1, 0.45)
                                            }
                                        }

                                        // Toggle: Show Resting Atom
                                        RowLayout {
                                            Layout.fillWidth: true
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2
                                                Text {
                                                    text: "Show Resting Atom on Desktop"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(11.5)
                                                    font.weight: Font.Medium
                                                    color: "#FFFFFF"
                                                }
                                                Text {
                                                    text: "Keep a minimalist 14px carbon atom visible on the wallpaper when all apps are minimized."
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(9.5)
                                                    color: Qt.rgba(1, 1, 1, 0.45)
                                                }
                                            }

                                            Rectangle {
                                                Layout.preferredWidth: 38
                                                Layout.preferredHeight: 20
                                                radius: 10
                                                color: root.vanishShowRestingAtom ? Theme.primary : Qt.rgba(1, 1, 1, 0.15)

                                                Rectangle {
                                                    x: root.vanishShowRestingAtom ? parent.width - width - 2 : 2
                                                    y: 2
                                                    width: 16
                                                    height: 16
                                                    radius: 8
                                                    color: root.vanishShowRestingAtom ? (Theme.m3onPrimary || "#000000") : "#FFFFFF"

                                                    Behavior on x {
                                                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.vanishShowRestingAtom = !root.vanishShowRestingAtom
                                                        root.saveVanishConfig("nucleus.showRestingAtom", root.vanishShowRestingAtom)
                                                    }
                                                }
                                            }
                                        }

                                        // Option Selector: Resting Spin Behavior
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            ColumnLayout {
                                                Layout.preferredWidth: 150
                                                spacing: 2
                                                Text {
                                                    text: "Resting Spin Behavior"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(11.5)
                                                    font.weight: Font.Medium
                                                    color: "#FFFFFF"
                                                }
                                                Text {
                                                    text: "When electron rings rotate."
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(9.5)
                                                    color: Qt.rgba(1, 1, 1, 0.45)
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Repeater {
                                                    model: [
                                                        { id: "hover", label: "Hover / Press Only" },
                                                        { id: "always", label: "Always Spin" },
                                                        { id: "never", label: "Static (No Spin)" }
                                                    ]
                                                    delegate: Rectangle {
                                                        required property var modelData
                                                        readonly property bool isSelected: root.vanishRestingSpin === modelData.id

                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 24
                                                        radius: 6
                                                        color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : (spinMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                                        border.color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                                                        border.width: 1

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData.label
                                                            font.family: Theme.font
                                                            font.pixelSize: Theme.fontPx(10)
                                                            font.weight: isSelected ? Font.Bold : Font.Normal
                                                            color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.70)
                                                        }

                                                        MouseArea {
                                                            id: spinMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                root.vanishRestingSpin = modelData.id
                                                                root.saveVanishConfig("nucleus.restingSpin", modelData.id)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // ── Card 3: Audio Visualizer & Wallpaper Shader ─
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: visCol.implicitHeight + 28
                                    radius: 12
                                    color: Qt.rgba(0, 0, 0, 0.22)
                                    border.color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1

                                    ColumnLayout {
                                        id: visCol
                                        anchors.fill: parent
                                        anchors.margins: 14
                                        spacing: 12

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                text: "AUDIO VISUALIZER & WALLPAPER"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(10)
                                                font.weight: Font.Bold
                                                color: Theme.primary
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: "SHADERS & SYNCS"
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontPx(9)
                                                color: Qt.rgba(1, 1, 1, 0.45)
                                            }
                                        }

                                        // Music Visualizer Style
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            ColumnLayout {
                                                Layout.preferredWidth: 150
                                                spacing: 2
                                                Text {
                                                    text: "Music Visualizer Style"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(11.5)
                                                    font.weight: Font.Medium
                                                    color: "#FFFFFF"
                                                }
                                                Text {
                                                    text: "Waveform geometry around core."
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(9.5)
                                                    color: Qt.rgba(1, 1, 1, 0.45)
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Repeater {
                                                    model: [
                                                        { id: "liquidHalo", label: "Liquid Halo" },
                                                        { id: "orbitalWave", label: "Orbital Wave" },
                                                        { id: "bars", label: "Classic Bars" },
                                                        { id: "none", label: "Disabled" }
                                                    ]
                                                    delegate: Rectangle {
                                                        required property var modelData
                                                        readonly property bool isSelected: root.vanishMusicVisualizer === modelData.id

                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 24
                                                        radius: 6
                                                        color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : (visMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                                        border.color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                                                        border.width: 1

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData.label
                                                            font.family: Theme.font
                                                            font.pixelSize: Theme.fontPx(10)
                                                            font.weight: isSelected ? Font.Bold : Font.Normal
                                                            color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.70)
                                                        }

                                                        MouseArea {
                                                            id: visMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                root.vanishMusicVisualizer = modelData.id
                                                                root.saveVanishConfig("musicVisualizer", modelData.id)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Wallpaper Transition Effect
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            ColumnLayout {
                                                Layout.preferredWidth: 150
                                                spacing: 2
                                                Text {
                                                    text: "Wallpaper Transition"
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(11.5)
                                                    font.weight: Font.Medium
                                                    color: "#FFFFFF"
                                                }
                                                Text {
                                                    text: "Shader on wallpaper switch."
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontPx(9.5)
                                                    color: Qt.rgba(1, 1, 1, 0.45)
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                Repeater {
                                                    model: [
                                                        { id: "cinematic", label: "Cinematic" },
                                                        { id: "fade", label: "Crossfade" },
                                                        { id: "zoom", label: "Hyper Zoom" },
                                                        { id: "slide", label: "Smooth Slide" }
                                                    ]
                                                    delegate: Rectangle {
                                                        required property var modelData
                                                        readonly property bool isSelected: root.vanishWallpaperAnimation === modelData.id

                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 24
                                                        radius: 6
                                                        color: isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : (wpMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                                                        border.color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                                                        border.width: 1

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: modelData.label
                                                            font.family: Theme.font
                                                            font.pixelSize: Theme.fontPx(10)
                                                            font.weight: isSelected ? Font.Bold : Font.Normal
                                                            color: isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.70)
                                                        }

                                                        MouseArea {
                                                            id: wpMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                root.vanishWallpaperAnimation = modelData.id
                                                                root.saveVanishConfig("wallpaperAnimation", modelData.id)
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
                    }
                }
            }
        }
    }
}
