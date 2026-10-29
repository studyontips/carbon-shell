import QtQuick
import QtQuick.Layouts
import "../Singletons"

/**
 * TacticalChronometer:
 * Minimalist aesthetic cyber clock for Carbon // Center Notch.
 * Features:
 *   - Only the luminous glowing orb smoothly orbiting around the time
 *   - Soft fading comet arc trail
 *   - Bold modern digital time and uppercase letter-spaced date
 *   - Zero unnecessary circles, reticle rings, or cardinal ticks
 *   - 100% Matugen dynamic theme synchronization
 */
Item {
    id: root

    implicitWidth: 320
    implicitHeight: 236

    property var currentDate: new Date()
    property string clockFormat: "12"
    property bool showDate: true

    property int hoursRaw: currentDate.getHours()
    property int minutesRaw: currentDate.getMinutes()
    property int secondsRaw: currentDate.getSeconds()

    property string hourStr: {
        let h = root.hoursRaw
        if (root.clockFormat !== "24") {
            h = h % 12 || 12
        }
        return (h < 10 ? "0" : "") + h
    }

    property string minStr: {
        let m = root.minutesRaw
        return (m < 10 ? "0" : "") + m
    }

    property string secStr: {
        let s = root.secondsRaw
        return (s < 10 ? "0" : "") + s
    }

    property string dateStr: {
        let d = root.currentDate
        let days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        let months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        return days[d.getDay()] + " " + d.getDate() + " " + months[d.getMonth()]
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            root.currentDate = new Date()
        }
    }

    // ── 60 FPS Orbit Rotation Engine ──────────────────────────────────────────
    property real orbitAngle: 0.0

    NumberAnimation on orbitAngle {
        from: 0.0
        to: 360.0
        duration: 60000
        loops: Animation.Infinite
        running: true
    }

    // Pulse animation for satellite beacon
    property real beaconPulse: 0.0
    SequentialAnimation on beaconPulse {
        loops: Animation.Infinite
        running: true
        NumberAnimation { from: 0.0; to: 1.0; duration: 1200; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.0; to: 0.0; duration: 1200; easing.type: Easing.InOutSine }
    }

    // Dial geometry constants
    readonly property real centerX: width / 2
    readonly property real centerY: height / 2
    readonly property real orbitRadius: 82

    /* ── Subtle Ambient Glow Behind Time ───────────────────────────────────── */
    Rectangle {
        anchors.centerIn: parent
        width: 140
        height: 140
        radius: 70
        color: Theme.primary
        opacity: 0.05 + (root.beaconPulse * 0.03)
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }

    /* ── Canvas Layer: Only the Fading Comet Trail Arc (Zero Circles) ───────── */
    Canvas {
        id: chronoCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Threaded

        Connections {
            target: root
            function onOrbitAngleChanged() { chronoCanvas.requestPaint() }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var cx = root.centerX
            var cy = root.centerY
            var rOrbit = root.orbitRadius

            // Smooth fading comet arc trail leading to the orb
            var headAngleRad = (root.orbitAngle - 90) * Math.PI / 180
            var trailSpanRad = Math.PI * 0.50 // ~90 degree luminous tail
            var tailAngleRad = headAngleRad - trailSpanRad

            var x1 = cx + rOrbit * Math.cos(tailAngleRad)
            var y1 = cy + rOrbit * Math.sin(tailAngleRad)
            var x2 = cx + rOrbit * Math.cos(headAngleRad)
            var y2 = cy + rOrbit * Math.sin(headAngleRad)

            var trailGrad = ctx.createLinearGradient(x1, y1, x2, y2)
            trailGrad.addColorStop(0.0, "transparent")
            trailGrad.addColorStop(0.6, Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30))
            trailGrad.addColorStop(1.0, Theme.primary)

            ctx.beginPath()
            ctx.arc(cx, cy, rOrbit, tailAngleRad, headAngleRad)
            ctx.strokeStyle = trailGrad
            ctx.lineWidth = 2.5
            ctx.lineCap = "round"
            ctx.stroke()
        }
    }

    /* ── Glowing Orb Node (Revolving Orbit) ─────────────────────────────────── */
    Item {
        id: satelliteNode
        readonly property real rad: (root.orbitAngle - 90) * Math.PI / 180
        x: root.centerX + root.orbitRadius * Math.cos(rad) - width / 2
        y: root.centerY + root.orbitRadius * Math.sin(rad) - height / 2
        width: 16
        height: 16

        // Pulsing Soft Glow Halo
        Rectangle {
            anchors.centerIn: parent
            width: 22 + root.beaconPulse * 8
            height: width
            radius: width / 2
            color: Theme.primary
            opacity: 0.38 - root.beaconPulse * 0.20
        }

        // Outer Accent Ring
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.90)
            border.color: Theme.primary
            border.width: 1.5

            // Inner Solid Glowing Orb Core
            Rectangle {
                anchors.centerIn: parent
                width: 6
                height: 6
                radius: 3
                color: Theme.primary
            }
        }
    }

    /* ── Center Digital Time & Date ─────────────────────────────────────────── */
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 2
        z: 10

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.hourStr + ":" + root.minStr
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPx(36)
            font.weight: Font.Bold
            color: Theme.fg
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.showDate
            text: root.dateStr
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontPx(10)
            font.weight: Font.Bold
            font.letterSpacing: 1.6
            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
            horizontalAlignment: Text.AlignHCenter
        }
    }

    /* Click to toggle 12h / 24h format */
    MouseArea {
        anchors.centerIn: parent
        width: 130
        height: 130
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.clockFormat = (root.clockFormat === "24" ? "12" : "24")
        }
    }
}
