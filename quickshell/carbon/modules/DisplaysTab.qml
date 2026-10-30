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

    property string selectedMonitor: "eDP-1"
    property var monitorsList: []
    
    // Active monitor properties
    property int monitorWidth: 1366
    property int monitorHeight: 768
    property real monitorRate: 60.0
    property int monitorTransform: 0 // 0: Landscape, 1: Portrait (90 deg), 2: Inverted, 3: Portrait (270 deg)
    property real monitorScale: 1.0

    // Secondary monitor properties (e.g. DP-1 standby/external)
    property int dp1Width: 1920
    property int dp1Height: 1080
    property real dp1Rate: 120.0
    property int dp1Transform: 0
    property real dp1Scale: 1.0

    // Global & Hardware states
    property real globalShellScale: 1.0
    property int colorTemp: 6500
    property bool vrrEnabled: false
    property bool tenBitEnabled: false
    property bool directScanoutEnabled: true
    property bool mirrorEnabled: false

    // -----------------------------------------------------------------------
    // RUST BACKEND IPC SOCKET CLIENT (/tmp/carbon-hub.sock)
    // -----------------------------------------------------------------------
    Socket {
        id: hubSocket
        path: "/tmp/carbon-hub.sock"
        connected: true

        onConnectedChanged: {
            if (connected) {
                root.sendHub({ "module": "display", "action": "get_monitors" })
            }
        }

        parser: SplitParser {
            splitMarker: "\n"
            onRead: function(chunk) {
                var raw = chunk.trim()
                if (!raw) return
                try {
                    var resp = JSON.parse(raw)
                    if (resp && resp.status === "ok" && resp.data) {
                        if (resp.action === "get_monitors") {
                            var arr = resp.data
                            if (Array.isArray(arr) && arr.length > 0) {
                                root.monitorsList = arr
                                for (var i = 0; i < arr.length; i++) {
                                    var m = arr[i]
                                    if (m.name === root.selectedMonitor) {
                                        root.monitorWidth = m.width || 1366
                                        root.monitorHeight = m.height || 768
                                        root.monitorRate = m.refreshRate || 60.0
                                        root.monitorTransform = m.transform || 0
                                        root.monitorScale = m.scale || 1.0
                                        root.vrrEnabled = (m.vrr === true || m.vrr === 1)
                                        break
                                    }
                                }
                            }
                        } else if (resp.action === "set_orientation") {
                            if (resp.data && resp.data.transform !== undefined) {
                                if (resp.data.monitor === "eDP-1") root.monitorTransform = resp.data.transform
                                else if (resp.data.monitor === "DP-1") root.dp1Transform = resp.data.transform
                            }
                        } else if (resp.action === "set_resolution") {
                            if (resp.data) {
                                if (resp.data.monitor === "eDP-1") {
                                    if (resp.data.w) root.monitorWidth = resp.data.w
                                    if (resp.data.h) root.monitorHeight = resp.data.h
                                } else if (resp.data.monitor === "DP-1") {
                                    if (resp.data.w) root.dp1Width = resp.data.w
                                    if (resp.data.h) root.dp1Height = resp.data.h
                                }
                            }
                        } else if (resp.action === "set_vrr") {
                            if (resp.data && resp.data.state !== undefined) {
                                root.vrrEnabled = (resp.data.state === 1)
                            }
                        }
                    }
                } catch (e) {
                    console.log("[DisplaysTab] Socket parse error:", e)
                }
            }
        }
    }

    Timer {
        id: reconnectTimer
        interval: 1500
        repeat: true
        running: !hubSocket.connected
        onTriggered: {
            hubSocket.connected = true
        }
    }

    function sendHub(obj) {
        if (hubSocket.connected) {
            hubSocket.write(JSON.stringify(obj) + "\n")
            hubSocket.flush()
        }
    }

    // Debounced IPC dispatches
    Timer {
        id: scaleDebounce
        interval: 32
        repeat: false
        onTriggered: root.sendHub({ "module": "display", "action": "set_scale", "monitor": root.selectedMonitor, "scale": root.selectedMonitor === "eDP-1" ? root.monitorScale : root.dp1Scale })
    }
    function queueScale(val) {
        if (root.selectedMonitor === "eDP-1") root.monitorScale = val
        else root.dp1Scale = val
        scaleDebounce.restart()
    }

    Timer {
        id: tempDebounce
        interval: 32
        repeat: false
        onTriggered: root.sendHub({ "module": "display", "action": "set_temperature", "temp": root.colorTemp })
    }
    function queueTemp(val) {
        root.colorTemp = Math.round(val)
        tempDebounce.restart()
    }

    Component.onCompleted: {
        root.sendHub({ "module": "display", "action": "get_monitors" })
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ===================================================================
        // TOP SECTION: THE FLUID BLUEPRINT CANVAS
        // ===================================================================
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 230
            clip: true

            // Dotted Matrix Grid (2px dots, 16px spacing, opacity 0.1)
            Canvas {
                id: blueprintCanvas
                anchors.fill: parent
                opacity: 0.10
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.fillStyle = "#FFFFFF"
                    var spacing = 16
                    for (var x = spacing / 2; x < width; x += spacing) {
                        for (var y = spacing / 2; y < height; y += spacing) {
                            ctx.beginPath()
                            ctx.arc(x, y, 1, 0, Math.PI * 2)
                            ctx.fill()
                        }
                    }
                }
            }

            // Blueprint Header Overlay
            RowLayout {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: 14
                anchors.leftMargin: 20
                spacing: 8

                Text {
                    text: "VIRTUAL DESKTOP MATRIX"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(10)
                    font.weight: Font.Bold
                    color: Qt.rgba(1, 1, 1, 0.35)
                }

                Text {
                    text: "// TOPOLOGY VIEW"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontPx(9)
                    color: Theme.primary
                }
            }

            // Interactive Monitor Nodes in Blueprint
            RowLayout {
                anchors.centerIn: parent
                spacing: 32

                // -----------------------------------------------------------
                // Node 1: eDP-1 (Active / Primary Laptop Display)
                // -----------------------------------------------------------
                Item {
                    id: edp1Container
                    readonly property bool isPortrait: (root.monitorTransform === 1 || root.monitorTransform === 3)
                    readonly property bool isSelected: root.selectedMonitor === "eDP-1"
                    
                    // Dimensional Morphing: width & height animated with InOutExpo (400ms)
                    width: isPortrait ? 124 : 220
                    height: isPortrait ? 220 : 124

                    Behavior on width {
                        NumberAnimation { duration: 400; easing.type: Easing.InOutExpo }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 400; easing.type: Easing.InOutExpo }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Qt.rgba(0.06, 0.06, 0.08, 0.75)
                        border.width: edp1Container.isSelected ? 1.5 : 1
                        border.color: edp1Container.isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.15)

                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        // Glowing ambient halo when selected
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: "transparent"
                            border.width: 1
                            border.color: edp1Container.isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35) : "transparent"
                            opacity: edp1Container.isSelected ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                        }

                        // Content inside node stays strictly upright & horizontal (NO rotation)
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "eDP-1"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(13)
                                font.weight: Font.Bold
                                color: edp1Container.isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.90)
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: root.monitorWidth + " × " + root.monitorHeight
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(11)
                                color: Qt.rgba(1, 1, 1, 0.60)
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: Math.round(root.monitorRate) + "Hz  •  " + (edp1Container.isPortrait ? "Portrait" : "Landscape")
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(9)
                                color: edp1Container.isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.40)
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Rectangle {
                                Layout.preferredWidth: 70
                                Layout.preferredHeight: 16
                                radius: 4
                                color: edp1Container.isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                                Layout.alignment: Qt.AlignHCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "PRIMARY"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(8)
                                    font.weight: Font.Bold
                                    color: edp1Container.isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.40)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedMonitor = "eDP-1"
                        }
                    }
                }

                // -----------------------------------------------------------
                // Node 2: DP-1 (Secondary / External Node)
                // -----------------------------------------------------------
                Item {
                    id: dp1Container
                    readonly property bool isPortrait: (root.dp1Transform === 1 || root.dp1Transform === 3)
                    readonly property bool isSelected: root.selectedMonitor === "DP-1"
                    
                    // Dimensional Morphing: width & height animated with InOutExpo (400ms)
                    width: isPortrait ? 124 : 220
                    height: isPortrait ? 220 : 124

                    Behavior on width {
                        NumberAnimation { duration: 400; easing.type: Easing.InOutExpo }
                    }
                    Behavior on height {
                        NumberAnimation { duration: 400; easing.type: Easing.InOutExpo }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Qt.rgba(0.06, 0.06, 0.08, 0.75)
                        border.width: dp1Container.isSelected ? 1.5 : 1
                        border.color: dp1Container.isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.15)

                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        // Content inside node stays strictly upright & horizontal (NO rotation)
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: "DP-1"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(13)
                                font.weight: Font.Bold
                                color: dp1Container.isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.90)
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: root.dp1Width + " × " + root.dp1Height
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(11)
                                color: Qt.rgba(1, 1, 1, 0.60)
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: Math.round(root.dp1Rate) + "Hz  •  " + (dp1Container.isPortrait ? "Portrait" : "Landscape")
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(9)
                                color: dp1Container.isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.40)
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Rectangle {
                                Layout.preferredWidth: 70
                                Layout.preferredHeight: 16
                                radius: 4
                                color: dp1Container.isSelected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                                Layout.alignment: Qt.AlignHCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "EXT // STANDBY"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(8)
                                    font.weight: Font.Bold
                                    color: dp1Container.isSelected ? Theme.primary : Qt.rgba(1, 1, 1, 0.40)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedMonitor = "DP-1"
                        }
                    }
                }
            }
        }

        // 1px Top Border Separating Blueprint From Controls
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // ===================================================================
        // BOTTOM 2-COLUMN ASYMMETRIC CONTROLS
        // ===================================================================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // ---------------------------------------------------------------
            // BOTTOM LEFT COLUMN: Geometry & Active Monitor
            // ---------------------------------------------------------------
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

                        // Header dynamically bound to selected monitor
                        Text {
                            text: "GEOMETRY: " + root.selectedMonitor.toUpperCase()
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(11)
                            font.weight: Font.Bold
                            color: Qt.rgba(1, 1, 1, 0.45)
                        }

                        // Orientation Selector: [ ⬒ Landscape ] | [ ◧ Portrait ]
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            readonly property bool isCurrentPortrait: root.selectedMonitor === "eDP-1" ? (root.monitorTransform === 1 || root.monitorTransform === 3) : (root.dp1Transform === 1 || root.dp1Transform === 3)

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                color: !parent.isCurrentPortrait ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : (landMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.02))
                                border.color: !parent.isCurrentPortrait ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "⬒  Landscape"
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(11)
                                    font.weight: !parent.parent.isCurrentPortrait ? Font.DemiBold : Font.Normal
                                    color: !parent.parent.isCurrentPortrait ? Theme.primary : Qt.rgba(1, 1, 1, 0.65)
                                }

                                MouseArea {
                                    id: landMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.selectedMonitor === "eDP-1") root.monitorTransform = 0
                                        else root.dp1Transform = 0
                                        root.sendHub({ "module": "display", "action": "set_orientation", "monitor": root.selectedMonitor, "transform": 0 })
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                color: parent.isCurrentPortrait ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : (portMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.02))
                                border.color: parent.isCurrentPortrait ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "◧  Portrait"
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(11)
                                    font.weight: parent.parent.isCurrentPortrait ? Font.DemiBold : Font.Normal
                                    color: parent.parent.isCurrentPortrait ? Theme.primary : Qt.rgba(1, 1, 1, 0.65)
                                }

                                MouseArea {
                                    id: portMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.selectedMonitor === "eDP-1") root.monitorTransform = 1
                                        else root.dp1Transform = 1
                                        root.sendHub({ "module": "display", "action": "set_orientation", "monitor": root.selectedMonitor, "transform": 1 })
                                    }
                                }
                            }
                        }

                        // Resolution: Manual Digit Inputs [ 1366 ] × [ 768 ]
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "Resolution (px)"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(12)
                                font.weight: Font.Medium
                                color: Qt.rgba(1, 1, 1, 0.85)
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                // Width Box
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    color: Qt.rgba(0, 0, 0, 0.35)
                                    border.color: resWInput.activeFocus ? Theme.primary : (wBoxMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10))
                                    border.width: 1

                                    TextInput {
                                        id: resWInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: String(root.selectedMonitor === "eDP-1" ? root.monitorWidth : root.dp1Width)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(12)
                                        color: Qt.rgba(1, 1, 1, 0.90)
                                        selectByMouse: true
                                        onEditingFinished: {
                                            var val = parseInt(text)
                                            if (val > 0) {
                                                if (root.selectedMonitor === "eDP-1") root.monitorWidth = val
                                                else root.dp1Width = val
                                                root.sendHub({ "module": "display", "action": "set_resolution", "monitor": root.selectedMonitor, "w": val, "h": parseInt(resHInput.text) })
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: wBoxMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                    }
                                }

                                Text {
                                    text: "×"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(14)
                                    color: Qt.rgba(1, 1, 1, 0.40)
                                }

                                // Height Box
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    color: Qt.rgba(0, 0, 0, 0.35)
                                    border.color: resHInput.activeFocus ? Theme.primary : (hBoxMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.10))
                                    border.width: 1

                                    TextInput {
                                        id: resHInput
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: String(root.selectedMonitor === "eDP-1" ? root.monitorHeight : root.dp1Height)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(12)
                                        color: Qt.rgba(1, 1, 1, 0.90)
                                        selectByMouse: true
                                        onEditingFinished: {
                                            var val = parseInt(text)
                                            if (val > 0) {
                                                if (root.selectedMonitor === "eDP-1") root.monitorHeight = val
                                                else root.dp1Height = val
                                                root.sendHub({ "module": "display", "action": "set_resolution", "monitor": root.selectedMonitor, "w": parseInt(resWInput.text), "h": val })
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: hBoxMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                    }
                                }
                            }
                        }

                        // Refresh Rate Flush Buttons: [ 60Hz ] [ ◆ 120Hz ]
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "Refresh Rate"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(12)
                                font.weight: Font.Medium
                                color: Qt.rgba(1, 1, 1, 0.85)
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                readonly property real currentRate: root.selectedMonitor === "eDP-1" ? root.monitorRate : root.dp1Rate

                                Repeater {
                                    model: [48, 60, 120, 144]

                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30
                                        readonly property bool isActive: Math.round(parent.parent.currentRate) === modelData
                                        color: isActive ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : (rateMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.02))
                                        border.color: isActive ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                        border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: (parent.isActive ? "◆ " : "") + modelData + "Hz"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontPx(10)
                                            font.weight: parent.isActive ? Font.Bold : Font.Normal
                                            color: parent.isActive ? Theme.primary : Qt.rgba(1, 1, 1, 0.65)
                                        }

                                        MouseArea {
                                            id: rateMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.selectedMonitor === "eDP-1") root.monitorRate = modelData
                                                else root.dp1Rate = modelData
                                                root.sendHub({ "module": "display", "action": "set_resolution", "monitor": root.selectedMonitor, "w": root.selectedMonitor === "eDP-1" ? root.monitorWidth : root.dp1Width, "h": root.selectedMonitor === "eDP-1" ? root.monitorHeight : root.dp1Height, "rate": modelData })
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Monitor Fractional Scale Slider
                        RazorWireSlider {
                            Layout.fillWidth: true
                            label: "Monitor Fractional Scale"
                            from: 0.80
                            to: 2.00
                            stepSize: 0.05
                            decimals: 2
                            unit: "x"
                            value: root.selectedMonitor === "eDP-1" ? root.monitorScale : root.dp1Scale
                            onMoved: (val) => root.queueScale(val)
                        }
                    }
                }
            }

            // 1px Vertical Hairline Separator
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Qt.rgba(1, 1, 1, 0.08)
            }

            // ---------------------------------------------------------------
            // BOTTOM RIGHT COLUMN: Global Shell & Hardware
            // ---------------------------------------------------------------
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

                        // Header
                        Text {
                            text: "GLOBAL & HARDWARE"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(11)
                            font.weight: Font.Bold
                            color: Qt.rgba(1, 1, 1, 0.45)
                        }

                        // Global Shell Scale
                        RazorWireSlider {
                            Layout.fillWidth: true
                            label: "Global Shell Scale"
                            from: 0.75
                            to: 1.50
                            stepSize: 0.05
                            decimals: 2
                            unit: "x"
                            value: root.globalShellScale
                            onMoved: (val) => {
                                root.globalShellScale = val
                            }
                        }

                        // Night-Owl Optics (Temperature) with ice-white to warm-amber gradient track
                        RazorWireSlider {
                            Layout.fillWidth: true
                            label: "Night-Owl Optics"
                            from: 3000
                            to: 6500
                            stepSize: 100
                            decimals: 0
                            unit: "K"
                            value: root.colorTemp
                            useGradientTrack: true
                            gradientStart: "#E6F4F1"
                            gradientEnd: "#F5A623"
                            onMoved: (val) => root.queueTemp(val)
                        }

                        // Structural Hairline
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        // Feature Matrix Header
                        Text {
                            text: "HARDWARE FEATURE MATRIX"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(11)
                            font.weight: Font.Bold
                            color: Qt.rgba(1, 1, 1, 0.45)
                        }

                        // Hardware Feature 1: Variable Refresh Rate (VRR) [ ● / ○ ]
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30

                            Text {
                                text: "Variable Refresh Rate (VRR)"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(13)
                                font.weight: Font.Medium
                                color: Qt.rgba(1, 1, 1, 0.85)
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.vrrEnabled ? "●" : "○"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(14)
                                color: root.vrrEnabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.35)
                                Layout.alignment: Qt.AlignRight

                                Behavior on color { ColorAnimation { duration: 150 } }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.vrrEnabled = !root.vrrEnabled
                                        root.sendHub({ "module": "display", "action": "set_vrr", "state": root.vrrEnabled ? 1 : 0 })
                                    }
                                }
                            }
                        }

                        // Hardware Feature 2: 10-Bit Color Depth [ ● / ○ ]
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30

                            Text {
                                text: "10-Bit Color Depth"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(13)
                                font.weight: Font.Medium
                                color: Qt.rgba(1, 1, 1, 0.85)
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.tenBitEnabled ? "●" : "○"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(14)
                                color: root.tenBitEnabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.35)
                                Layout.alignment: Qt.AlignRight

                                Behavior on color { ColorAnimation { duration: 150 } }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.tenBitEnabled = !root.tenBitEnabled
                                        root.sendHub({ "module": "display", "action": "set_display_feature", "feature": "10bit", "value": root.tenBitEnabled })
                                    }
                                }
                            }
                        }

                        // Hardware Feature 3: Direct Scanout [ ● / ○ ]
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30

                            Text {
                                text: "Direct Scanout"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(13)
                                font.weight: Font.Medium
                                color: Qt.rgba(1, 1, 1, 0.85)
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.directScanoutEnabled ? "●" : "○"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(14)
                                color: root.directScanoutEnabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.35)
                                Layout.alignment: Qt.AlignRight

                                Behavior on color { ColorAnimation { duration: 150 } }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.directScanoutEnabled = !root.directScanoutEnabled
                                        root.sendHub({ "module": "display", "action": "set_display_feature", "feature": "direct_scanout", "value": root.directScanoutEnabled })
                                    }
                                }
                            }
                        }

                        // Hardware Feature 4: Mirror Display (Clone) [ ● / ○ ]
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30

                            Text {
                                text: "Mirror Display (Clone)"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(13)
                                font.weight: Font.Medium
                                color: Qt.rgba(1, 1, 1, 0.85)
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.mirrorEnabled ? "●" : "○"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(14)
                                color: root.mirrorEnabled ? Theme.primary : Qt.rgba(1, 1, 1, 0.35)
                                Layout.alignment: Qt.AlignRight

                                Behavior on color { ColorAnimation { duration: 150 } }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.mirrorEnabled = !root.mirrorEnabled
                                        root.sendHub({ "module": "display", "action": "set_display_feature", "feature": "mirror", "value": root.mirrorEnabled })
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
