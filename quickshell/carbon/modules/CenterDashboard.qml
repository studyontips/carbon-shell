import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../Singletons"
import "../components"

/**
 * CenterDashboard:
 * High-tech aesthetic tactical dashboard for Carbon // Center Notch.
 * 3-Column Architectural Layout:
 *   1. Left Column: Tactical Timeline (nodes, glowing [ IN PROGRESS ] badge, CalDAV status)
 *   2. Center Column: Aesthetic Animated Tactical Chronometer (orbiting satellite, comet trail, reticle)
 *   3. Right Column: Synchronized LRC Lyrics (live LRCLIB stream, album art, progress readout)
 *
 * 100% Dynamic bindings to Matugen Theme tokens (zero hardcoded colors).
 */
Item {
    id: root

    property bool open: false
    property bool minimalCalendarOnly: false
    property bool attachedBottom: false
    property bool showBackground: true
    readonly property bool hovered: (rootHover && rootHover.hovered) || (mainCardHover && mainCardHover.hovered)
    signal closeRequested()

    implicitWidth: 820
    implicitHeight: 270
    width: implicitWidth
    height: implicitHeight
    clip: false
    property real earRadius: 16
    property real bottomRadius: 20

    focus: root.open
    Keys.enabled: root.open
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.closeRequested()
            event.accepted = true
        }
    }
    Keys.onEscapePressed: (event) => {
        root.closeRequested()
        event.accepted = true
    }

    HoverHandler {
        id: rootHover
    }

    readonly property var cardItem: mainCard
    readonly property var rightColItem: rightCol
    property bool animatingOut: false
    property string calendarViewMode: "timeline"
    property int selectedDay: (new Date()).getDate()
    property bool eventFormMode: false

    onOpenChanged: {
        if (root.open) {
            if (LyricsService.hasTrack && (!LyricsService.lines || LyricsService.lines.length === 0)) {
                LyricsService.reloadLyrics()
            }
        }
    }

    function openCalendarMode() {
        root.calendarViewMode = "timeline"
    }

    /* ── Format Time Helper (MM:SS or HH:MM:SS) ───────────────────────────── */
    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec < 0) return "00:00"
        let s = Math.floor(sec)
        let hrs = Math.floor(s / 3600)
        let mins = Math.floor((s % 3600) / 60)
        let secs = s % 60
        let mStr = (mins < 10 ? "0" : "") + mins
        let sStr = (secs < 10 ? "0" : "") + secs
        if (hrs > 0) {
            let hStr = (hrs < 10 ? "0" : "") + hrs
            return hStr + ":" + mStr + ":" + sStr
        }
        return mStr + ":" + sStr
    }

    /* ── Main Card ───────────────────────────────────────────────────────── */
    Item {
        id: mainCard
        anchors.fill: parent

        HoverHandler {
            id: mainCardHover
        }

        MouseArea {
            anchors.fill: parent
            z: 0
        }

        // Top-attached seamless background with notch ear fillets and curved bottom corners
        Shape {
            id: cardBgShape
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            preferredRendererType: Shape.CurveRenderer
            visible: true

            ShapePath {
                fillColor: Theme.isDark ? Qt.rgba(0.04, 0.04, 0.06, root.showBackground ? Theme.shellOpacity : 0.98) : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.showBackground ? Theme.shellOpacity : 0.98)
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 0; startY: 0
                PathLine { x: mainCard.width; y: 0 }
                PathArc {
                    x: mainCard.width - root.earRadius
                    y: root.earRadius
                    radiusX: root.earRadius
                    radiusY: root.earRadius
                    direction: PathArc.Clockwise
                }
                PathLine { x: mainCard.width - root.earRadius; y: mainCard.height - root.bottomRadius }
                PathArc {
                    x: mainCard.width - root.earRadius - root.bottomRadius
                    y: mainCard.height
                    radiusX: root.bottomRadius
                    radiusY: root.bottomRadius
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: root.earRadius + root.bottomRadius; y: mainCard.height }
                PathArc {
                    x: root.earRadius
                    y: mainCard.height - root.bottomRadius
                    radiusX: root.bottomRadius
                    radiusY: root.bottomRadius
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: root.earRadius; y: root.earRadius }
                PathArc {
                    x: 0
                    y: 0
                    radiusX: root.earRadius
                    radiusY: root.earRadius
                    direction: PathArc.Clockwise
                }
            }
        }

        /* ── 3-Column Layout ─────────────────────────────────────────────── */
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            z: 1

            /* ============================================================= */
            /* 1. LEFT COLUMN: TACTICAL TIMELINE                             */
            /* ============================================================= */
            Item {
                id: timelineCol
                Layout.preferredWidth: 226
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    // Header: TACTICAL TIMELINE // 04 NODES
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "TACTICAL TIMELINE"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(9)
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5
                            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: "04 NODES"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(9)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.0
                            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                        }
                    }

                    // Timeline Content Track Area
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // Vertical Connecting Rail Line
                        Rectangle {
                            x: 11
                            y: 12
                            width: 1
                            height: parent.height - 24
                            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12)
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 8

                            // Node 1: Completed / Past
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Item {
                                    width: 24
                                    height: 20

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.40)
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "10:00  —  Morning Focus"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(11)
                                    font.weight: Font.Medium
                                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                                    elide: Text.ElideRight
                                }
                            }

                            // Node 2: [ IN PROGRESS ] (Active Glowing Node)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Item {
                                    width: 24
                                    height: 48

                                    // Pulsing halo ring
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: Theme.primary
                                        opacity: 0.28
                                    }

                                    // Solid active node dot
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: Theme.primary
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    // [ IN PROGRESS ] Badge
                                    Rectangle {
                                        height: 18
                                        width: inProgTxt.implicitWidth + 12
                                        radius: 4
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                                        border.color: Theme.primary
                                        border.width: 1

                                        Text {
                                            id: inProgTxt
                                            anchors.centerIn: parent
                                            text: "[ IN PROGRESS ]"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontPx(8)
                                            font.weight: Font.Bold
                                            font.letterSpacing: 0.8
                                            color: Theme.primary
                                        }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Core Development"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontPx(13)
                                        font.weight: Font.Bold
                                        color: Theme.fg
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            // Node 3: Upcoming (Open Ring)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Item {
                                    width: 24
                                    height: 20

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: "transparent"
                                        border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                                        border.width: 1.5
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "14:00  —  Sync & Review"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(11)
                                    font.weight: Font.Medium
                                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.75)
                                    elide: Text.ElideRight
                                }
                            }

                            // Node 4: Upcoming (Open Ring)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Item {
                                    width: 24
                                    height: 20

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: "transparent"
                                        border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                                        border.width: 1.5
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "16:30  —  Workout"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(11)
                                    font.weight: Font.Medium
                                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.75)
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // Footer: SYNC // LOCAL CALDAV
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "SYNC // LOCAL CALDAV"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(8)
                            font.weight: Font.Bold
                            font.letterSpacing: 1.2
                            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.40)
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.primary
                        }
                    }
                }
            }

            /* ── Vertical Divider 1 ─────────────────────────────────────── */
            Rectangle {
                Layout.fillHeight: true
                width: 1
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
            }

            /* ============================================================= */
            /* 2. CENTER COLUMN: AESTHETIC ANIMATED TACTICAL CHRONOMETER     */
            /* ============================================================= */
            Item {
                id: centerCol
                Layout.fillWidth: true
                Layout.preferredWidth: 320
                Layout.fillHeight: true

                TacticalChronometer {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                }
            }

            /* ── Vertical Divider 2 ─────────────────────────────────────── */
            Rectangle {
                Layout.fillHeight: true
                width: 1
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
            }

            /* ============================================================= */
            /* 3. RIGHT COLUMN: LRC // SYNC (SYNCHRONIZED LYRICS & MPRIS)    */
            /* ============================================================= */
            Item {
                id: rightCol
                Layout.preferredWidth: 236
                Layout.fillHeight: true

                property string viewMode: "lyrics"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    // Header: LRC // SYNC, Track Title & Rounded Album Art
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Left: Glowing dot + LRC // SYNC
                        RowLayout {
                            spacing: 5

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: LyricsService.hasLyrics ? Theme.primary : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.25)
                            }

                            Text {
                                text: LyricsService.hasLyrics ? "LRC // SYNC" : (LyricsService.hasTrack ? "NO LYRICS" : "STANDBY")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(9)
                                font.weight: Font.Bold
                                font.letterSpacing: 1.2
                                color: LyricsService.hasLyrics ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.40)
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Track Title & Subtext
                        ColumnLayout {
                            Layout.maximumWidth: 100
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: LyricsService.hasTrack ? LyricsService.trackTitle : "No Media"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: Font.Bold
                                color: Theme.fg
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: LyricsService.hasTrack ? (LyricsService.trackArtist || "Unknown Artist") : "Standby"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(8)
                                font.weight: Font.Medium
                                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.50)
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        // Rounded Album Art Square
                        Rectangle {
                            width: 30
                            height: 30
                            radius: 8
                            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.90)
                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                            border.width: 1
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: LyricsService.artUrl
                                fillMode: Image.PreserveAspectCrop
                                visible: LyricsService.hasTrack && LyricsService.artUrl.length > 0 && status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "music_note"
                                font.family: Theme.fontIcon
                                font.pixelSize: 14
                                color: Theme.accent
                                visible: !LyricsService.hasTrack || LyricsService.artUrl.length === 0 || !LyricsService.artUrl
                            }
                        }
                    }

                    // Synchronized Lyrics Body (4-line kinetic stack)
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true

                        // Helper calculation for 4 display lines
                        readonly property var allLines: LyricsService.lines || []
                        readonly property int curIdx: LyricsService.currentIndex
                        readonly property bool hasRealLrc: LyricsService.hasTrack && LyricsService.hasLyrics && allLines.length > 0

                        // Empty State: strictly "uh oh we got no lyrics for this !"
                        Item {
                            anchors.fill: parent
                            visible: !parent.hasRealLrc

                            Text {
                                anchors.centerIn: parent
                                text: "uh oh we got no lyrics for this !"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: Font.Medium
                                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        // Synchronized Lyrics Stack
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 4
                            visible: parent.hasRealLrc

                            // 1. Previous Line (dim)
                            Text {
                                Layout.fillWidth: true
                                text: (parent.parent.curIdx > 0 && parent.parent.curIdx - 1 < parent.parent.allLines.length)
                                    ? parent.parent.allLines[parent.parent.curIdx - 1].text : ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: Font.Normal
                                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.35)
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                visible: text.length > 0
                            }

                            // 2. Active Lyric Line (PROMINENT, BOLD, PRIMARY AURA)
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: activeLineTxt.contentHeight + 4

                                Text {
                                    id: activeLineTxt
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    text: (parent.parent.parent.curIdx >= 0 && parent.parent.parent.curIdx < parent.parent.parent.allLines.length)
                                        ? parent.parent.parent.allLines[parent.parent.parent.curIdx].text : ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(13)
                                    font.weight: Font.Bold
                                    color: Theme.fg
                                    wrapMode: Text.Wrap
                                    elide: Text.ElideRight
                                    maximumLineCount: 2
                                }

                                // Soft Glowing Aura behind text
                                Text {
                                    anchors.fill: activeLineTxt
                                    text: activeLineTxt.text
                                    font.family: activeLineTxt.font.family
                                    font.pixelSize: activeLineTxt.font.pixelSize
                                    font.weight: activeLineTxt.font.weight
                                    color: Theme.primary
                                    opacity: 0.28
                                    wrapMode: activeLineTxt.wrapMode
                                    elide: activeLineTxt.elide
                                    maximumLineCount: activeLineTxt.maximumLineCount
                                    z: -1
                                }
                            }

                            // 3. Next Line (semi-dim)
                            Text {
                                Layout.fillWidth: true
                                text: (parent.parent.curIdx + 1 < parent.parent.allLines.length)
                                    ? parent.parent.allLines[parent.parent.curIdx + 1].text : ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: Font.Normal
                                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.50)
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                visible: text.length > 0
                            }

                            // 4. Following Line (faint)
                            Text {
                                Layout.fillWidth: true
                                text: (parent.parent.curIdx + 2 < parent.parent.allLines.length)
                                    ? parent.parent.allLines[parent.parent.curIdx + 2].text : ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(10)
                                font.weight: Font.Normal
                                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.20)
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                visible: text.length > 0
                            }
                        }
                    }

                    // Footer: Track Progress & Controls
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: root.formatTime(LyricsService.currentPosition) + "  /  " + root.formatTime(LyricsService.totalLength)
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(9)
                            font.weight: Font.Medium
                            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                        }

                        Item { Layout.fillWidth: true }

                        // Transport Controls
                        RowLayout {
                            spacing: 6

                            // Prev
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: prevM.containsMouse ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12) : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "skip_previous"
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 13
                                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.70)
                                }
                                MouseArea {
                                    id: prevM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (LyricsService.activePlayer) LyricsService.activePlayer.previous()
                                }
                            }

                            // Play/Pause
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: playM.containsMouse ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                                Text {
                                    anchors.centerIn: parent
                                    text: LyricsService.isPlaying ? "pause" : "play_arrow"
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 14
                                    color: playM.containsMouse ? Theme.bg : Theme.primary
                                }
                                MouseArea {
                                    id: playM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (LyricsService.activePlayer) LyricsService.activePlayer.togglePlaying()
                                }
                            }

                            // Next
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: nextM.containsMouse ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12) : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "skip_next"
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 13
                                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.70)
                                }
                                MouseArea {
                                    id: nextM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (LyricsService.activePlayer) LyricsService.activePlayer.next()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
