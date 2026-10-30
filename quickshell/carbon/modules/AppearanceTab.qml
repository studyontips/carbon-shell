import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Singletons"
import "../components"

Item {
    id: root

    implicitWidth: 800
    implicitHeight: 600

    readonly property string wallpaperDir: (Quickshell.env("HOME") || "") + "/Pictures/Wallpapers"
    readonly property string stateFile: (Quickshell.env("CARBON_CONFIG_DIR") || ((Quickshell.env("HOME") || "") + "/.config/carbon")) + "/current_wallpaper_path"
    readonly property string hyprStateFile: (Quickshell.env("HOME") || "") + "/.config/hypr/current_wallpaper_path"
    readonly property string wallhavenScript: (Quickshell.env("CARBON_CONFIG_DIR") || ((Quickshell.env("HOME") || "") + "/.config/carbon")) + "/scripts/wallhaven.py"
    readonly property string matugenScript: (Quickshell.env("CARBON_CONFIG_DIR") || ((Quickshell.env("HOME") || "") + "/.config/carbon")) + "/scripts/matugen-scheme.sh"
    readonly property string hyprControlScript: (Quickshell.env("CARBON_CONFIG_DIR") || ((Quickshell.env("HOME") || "") + "/.config/carbon")) + "/scripts/hypr-control.sh"

    property string currentWallpaperPath: ""
    property var localWallpapers: []
    property string activeScheme: "Tonal Spot"
    property bool liveBgPaused: false

    // Hyprland options
    property real blurRadius: 5
    property real gapsOut: 6
    property real activeOpacity: 1.0
    property real inactiveOpacity: 1.0
    property real borderWidth: 1
    property bool windowShadows: true
    property bool ambientGlow: false
    property bool m3Transitions: false

    // FileView for current wallpaper tracking
    FileView {
        id: wpLinkFile
        path: root.stateFile
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            var t = wpLinkFile.text().trim()
            if (t) root.currentWallpaperPath = t
        }
        onFileChanged: {
            reload()
            var t = wpLinkFile.text().trim()
            if (t) root.currentWallpaperPath = t
        }
    }

    FileView {
        id: hyprWpLinkFile
        path: root.hyprStateFile
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            var t = hyprWpLinkFile.text().trim()
            if (t && !root.currentWallpaperPath) root.currentWallpaperPath = t
        }
        onFileChanged: {
            reload()
            var t = hyprWpLinkFile.text().trim()
            if (t) root.currentWallpaperPath = t
        }
    }

    Component.onCompleted: {
        loadLocalWallpapers()
        loadHyprlandOptions()
    }

    function loadLocalWallpapers() {
        if (!listProc.running) {
            listProc.command = ["python3", root.wallhavenScript, "list-local"]
            listProc.running = true
        }
    }

    function loadHyprlandOptions() {
        if (!hyprQueryProc.running) {
            hyprQueryProc.command = [root.hyprControlScript, "get", "all"]
            hyprQueryProc.running = true
        }
    }

    function applyWallpaper(path) {
        if (!path) return
        root.currentWallpaperPath = path
        Quickshell.execDetached(["python3", root.wallhavenScript, "apply", path])
    }

    function shuffleRandomWallpaper() {
        if (root.localWallpapers.length === 0) return
        var idx = Math.floor(Math.random() * root.localWallpapers.length)
        var item = root.localWallpapers[idx]
        if (item && item.path) {
            applyWallpaper(item.path)
        }
    }

    function setScheme(schemeName) {
        root.activeScheme = schemeName
        Quickshell.execDetached([root.matugenScript, schemeName])
    }

    function updateHypr(key, val) {
        Quickshell.execDetached([root.hyprControlScript, "set", key, String(val)])
    }

    Process {
        id: listProc
        property string buffer: ""
        onRunningChanged: {
            if (running) {
                buffer = ""
            } else if (buffer.trim().length > 0) {
                try {
                    var res = JSON.parse(buffer)
                    if (res && res.success && Array.isArray(res.data)) {
                        root.localWallpapers = res.data
                    }
                } catch (e) {
                    console.log("[AppearanceTab] Failed to parse wallpapers:", e)
                }
            }
        }
        stdout: SplitParser {
            onRead: (chunk) => { listProc.buffer += chunk + "\n" }
        }
    }

    Process {
        id: hyprQueryProc
        property string buffer: ""
        onRunningChanged: {
            if (running) {
                buffer = ""
            } else if (buffer.trim().length > 0) {
                try {
                    var res = JSON.parse(buffer)
                    if (res) {
                        if (res.blur !== undefined) root.blurRadius = res.blur
                        if (res.gaps !== undefined) root.gapsOut = res.gaps
                        if (res.active_opacity !== undefined) root.activeOpacity = res.active_opacity
                        if (res.inactive_opacity !== undefined) root.inactiveOpacity = res.inactive_opacity
                        if (res.border !== undefined) root.borderWidth = res.border
                        if (res.shadow !== undefined) root.windowShadows = (res.shadow === true || res.shadow === "true")
                    }
                } catch (e) {
                    console.log("[AppearanceTab] Failed to parse hypr options:", e)
                }
            }
        }
        stdout: SplitParser {
            onRead: (chunk) => { hyprQueryProc.buffer += chunk + "\n" }
        }
    }

    // 2-Column Asymmetric Layout
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ==========================================
        // LEFT COLUMN: Gallery & Colors (approx 58%)
        // ==========================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 460

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: leftColContent.implicitHeight + 40
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: leftColContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 16

                    // Section Header: Wallpaper Gallery
                    Text {
                        text: "WALLPAPER GALLERY"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(11)
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.45)
                    }

                    // Active Hero Wallpaper Preview (radius: 10, clip: true, NO text overlay)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 190
                        radius: 10
                        color: Qt.rgba(0, 0, 0, 0.40)
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        clip: true

                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: root.currentWallpaperPath ? ("file://" + root.currentWallpaperPath) : ""
                            asynchronous: true
                            smooth: true
                            cache: true
                        }
                    }

                    // Controls Row: [ ⤨ SHUFFLE RANDOM ] + Live BG Pause Badge
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // Shuffle Random Button
                        Rectangle {
                            Layout.preferredWidth: shuffleText.implicitWidth + 24
                            Layout.preferredHeight: 32
                            radius: 6
                            color: shuffleMouse.pressed ? Qt.rgba(1, 1, 1, 0.14) : (shuffleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1

                            Text {
                                id: shuffleText
                                anchors.centerIn: parent
                                text: "⤨  SHUFFLE RANDOM"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: Font.DemiBold
                                color: Qt.rgba(1, 1, 1, 0.90)
                            }

                            MouseArea {
                                id: shuffleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.shuffleRandomWallpaper()
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Live BG Pause Toggle Row
                        RowLayout {
                            spacing: 8
                            Text {
                                text: "Live BG Pause"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(12)
                                color: Qt.rgba(1, 1, 1, 0.70)
                            }

                            TerminalStatusBadge {
                                checked: root.liveBgPaused
                                onClicked: {
                                    root.liveBgPaused = !root.liveBgPaused
                                    if (root.liveBgPaused) {
                                        Quickshell.execDetached(["pkill", "-STOP", "-f", "mpvpaper|swww"])
                                    } else {
                                        Quickshell.execDetached(["pkill", "-CONT", "-f", "mpvpaper|swww"])
                                    }
                                }
                            }
                        }
                    }

                    // Horizontal Thumbnails Carousel (140x80, radius 8, NO text overlays)
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88

                        ListView {
                            id: thumbList
                            anchors.fill: parent
                            orientation: ListView.Horizontal
                            spacing: 12
                            clip: true
                            model: root.localWallpapers

                            delegate: Rectangle {
                                width: 140
                                height: 80
                                radius: 8
                                clip: true
                                color: Qt.rgba(0, 0, 0, 0.35)
                                border.color: (modelData.path === root.currentWallpaperPath) ? Theme.primary : (thumbMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.10))
                                border.width: (modelData.path === root.currentWallpaperPath) ? 2 : 1

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: (modelData.path === root.currentWallpaperPath) ? 2 : 0
                                    fillMode: Image.PreserveAspectCrop
                                    source: modelData.thumb || ("file://" + modelData.path)
                                    asynchronous: true
                                    smooth: true
                                }

                                MouseArea {
                                    id: thumbMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.applyWallpaper(modelData.path)
                                }
                            }
                        }
                    }

                    // Section Divider
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // ==========================================
                    // MATUGEN COLOR ENGINE
                    // ==========================================
                    Text {
                        text: "Matugen Color Scheme"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(12)
                        font.weight: Font.Medium
                        color: Qt.rgba(1, 1, 1, 0.85)
                    }

                    // Inline Row of 5 Live Circular Color Chips (radius: 12, 24px)
                    RowLayout {
                        spacing: 14

                        Repeater {
                            model: [
                                { name: "Primary", col: Theme.primary },
                                { name: "Secondary", col: Theme.secondary },
                                { name: "Tertiary", col: Theme.tertiary },
                                { name: "Surface", col: Theme.surface },
                                { name: "Error", col: Theme.error }
                            ]

                            delegate: ColumnLayout {
                                spacing: 4
                                Layout.alignment: Qt.AlignHCenter

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: modelData.col
                                    border.color: Qt.rgba(1, 1, 1, 0.20)
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: 250 } }
                                }

                                Text {
                                    text: modelData.name
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(9)
                                    color: Qt.rgba(1, 1, 1, 0.40)
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }

                    // Clickable Segmented Scheme Buttons: Tonal Spot | Expressive | Fidelity | Monochrome
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Repeater {
                            model: ["Tonal Spot", "Expressive", "Fidelity", "Monochrome"]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                color: (root.activeScheme === modelData) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : (segMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.02))
                                border.color: (root.activeScheme === modelData) ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(11)
                                    font.weight: (root.activeScheme === modelData) ? Font.DemiBold : Font.Normal
                                    color: (root.activeScheme === modelData) ? Theme.primary : Qt.rgba(1, 1, 1, 0.65)
                                }

                                MouseArea {
                                    id: segMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setScheme(modelData)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // 1PX VERTICAL HAIRLINE SEPARATOR
        // ==========================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // ==========================================
        // RIGHT COLUMN: Compositor & Features (approx 42%)
        // ==========================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 340

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: rightColContent.implicitHeight + 40
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: rightColContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    spacing: 16

                    // Section Header: Hyprland Compositor Controls
                    Text {
                        text: "COMPOSITOR & EFFECTS"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(11)
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.45)
                    }

                    // 5 Razor Wire Sliders (NO Rounded Corners slider)
                    RazorWireSlider {
                        Layout.fillWidth: true
                        label: "Blur Radius"
                        from: 0
                        to: 20
                        stepSize: 1
                        decimals: 0
                        unit: "px"
                        value: root.blurRadius
                        onMoved: (val) => {
                            root.blurRadius = val
                            root.updateHypr("blur", val)
                        }
                    }

                    RazorWireSlider {
                        Layout.fillWidth: true
                        label: "Gaps Out"
                        from: 0
                        to: 32
                        stepSize: 1
                        decimals: 0
                        unit: "px"
                        value: root.gapsOut
                        onMoved: (val) => {
                            root.gapsOut = val
                            root.updateHypr("gaps", val)
                        }
                    }

                    RazorWireSlider {
                        Layout.fillWidth: true
                        label: "Active Opacity"
                        from: 0.20
                        to: 1.00
                        stepSize: 0.05
                        decimals: 2
                        value: root.activeOpacity
                        onMoved: (val) => {
                            root.activeOpacity = val
                            root.updateHypr("active_opacity", val)
                        }
                    }

                    RazorWireSlider {
                        Layout.fillWidth: true
                        label: "Inactive Opacity"
                        from: 0.20
                        to: 1.00
                        stepSize: 0.05
                        decimals: 2
                        value: root.inactiveOpacity
                        onMoved: (val) => {
                            root.inactiveOpacity = val
                            root.updateHypr("inactive_opacity", val)
                        }
                    }

                    RazorWireSlider {
                        Layout.fillWidth: true
                        label: "Border Width"
                        from: 0
                        to: 8
                        stepSize: 1
                        decimals: 0
                        unit: "px"
                        value: root.borderWidth
                        onMoved: (val) => {
                            root.borderWidth = val
                            root.updateHypr("border", val)
                        }
                    }

                    // Structural Hairline
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // Feature Matrix Header
                    Text {
                        text: "FEATURE TOGGLE MATRIX"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(11)
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.45)
                    }

                    // Feature 1: Enable Window Shadows
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Enable Window Shadows"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(13)
                            font.weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.85)
                            Layout.fillWidth: true
                        }

                        TerminalStatusBadge {
                            checked: root.windowShadows
                            onClicked: {
                                root.windowShadows = !root.windowShadows
                                root.updateHypr("shadow", root.windowShadows ? "true" : "false")
                            }
                        }
                    }

                    // Feature 2: Ambient Glow (Audio Borders)
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Ambient Glow (Audio Borders)"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(13)
                            font.weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.85)
                            Layout.fillWidth: true
                        }

                        TerminalStatusBadge {
                            checked: root.ambientGlow
                            onClicked: {
                                root.ambientGlow = !root.ambientGlow
                                Quickshell.execDetached(["sh", "-c", "echo " + (root.ambientGlow ? "1" : "0") + " > ~/.config/carbon/ambient_glow_state"])
                            }
                        }
                    }

                    // Feature 3: Material-3 Transitions (Dimmed Opacity 0.40 Placeholder)
                    RowLayout {
                        Layout.fillWidth: true
                        opacity: 0.40

                        Text {
                            text: "Material-3 Transitions"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(13)
                            font.weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.85)
                            Layout.fillWidth: true
                        }

                        TerminalStatusBadge {
                            checked: false
                            interactive: false
                        }
                    }
                }
            }
        }
    }
}
