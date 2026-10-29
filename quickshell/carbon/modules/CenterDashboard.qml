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

        // Top-attached seamless background with flat top edge and curved bottom corners
        Shape {
            id: cardBgShape
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            preferredRendererType: Shape.CurveRenderer
            visible: root.showBackground

            ShapePath {
                fillColor: Theme.isDark ? Qt.rgba(0.04, 0.04, 0.06, root.showBackground ? Theme.shellOpacity : 0.98) : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.showBackground ? Theme.shellOpacity : 0.98)
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 0; startY: 0
                PathLine { x: mainCard.width; y: 0 }
                PathLine { x: mainCard.width; y: mainCard.height - 20 }
                PathArc { x: mainCard.width - 20; y: mainCard.height; radiusX: 20; radiusY: 20 }
                PathLine { x: 20; y: mainCard.height }
                PathArc { x: 0; y: mainCard.height - 20; radiusX: 20; radiusY: 20 }
                PathLine { x: 0; y: 0 }
            }
        }

        /* ── 3-Column Layout ─────────────────────────────────────────────── */
        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
            z: 1

            /* ============================================================= */
            /* 1. LEFT COLUMN: TACTICAL POMODORO & FOCUS DIRECTIVES           */
            /* ============================================================= */
            Item {
                id: timelineCol
                Layout.preferredWidth: 240
                Layout.fillHeight: true
                clip: true

                TacticalPomodoro {
                    anchors.fill: parent
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
                Layout.preferredWidth: 288
                Layout.fillHeight: true
                clip: true

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
            /* 3. RIGHT COLUMN: MEDIA PLAYER & LYRICS STREAM                 */
            /* ============================================================= */
            Item {
                id: rightCol
                Layout.preferredWidth: 240
                Layout.fillHeight: true

                property string viewMode: "lyrics"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    // Header: Clean Track Title, Artist & Album Art (Zero "LRC // SYNC" clutter)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Track Title & Artist (Clean left aligned)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: LyricsService.hasTrack ? LyricsService.trackTitle : "No Media"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: Font.Bold
                                color: Theme.fg
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: LyricsService.hasTrack ? (LyricsService.trackArtist || "Unknown Artist") : "Standby"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(8.5)
                                font.weight: Font.Medium
                                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.50)
                                elide: Text.ElideRight
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
                                visible: !LyricsService.hasTrack || !LyricsService.artUrl || LyricsService.artUrl.length === 0
                                text: "music_note"
                                font.family: Theme.fontIcon
                                font.pixelSize: 14
                                color: Theme.primary
                            }
                        }
                    }

                    // Mini Cairo Kinetic Lyric Engine (Dedicated to this mode)
                    MiniCairo {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        active: root.open
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
