import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../Singletons"

/**
 * MiniCairo.qml:
 * Compact, ultra-low-overhead Kinetic Lyric Engine for Carbon // Center Notch Dropdown.
 *
 * Implements:
 *   - 60fps Interpolated Audio Clock (active ONLY when pavilion is open & media is playing).
 *   - Kinetic 3-Slot Vertical Barrel (Previous Word, Active Word, Next Incoming Word).
 *   - Signature Cairo Translucent Glass Tape Highlight with Matugen primary aura.
 *   - Automatic word-level LRC fallback: splits standard line-level lyrics into rhythm chunks.
 *   - 0.0% CPU usage when dashboard is closed.
 */
Item {
    id: root

    property bool active: true

    readonly property bool hasTrack: LyricsService.hasTrack
    readonly property bool isPlaying: LyricsService.isPlaying
    readonly property var rawLines: (CairoLyricsService.lines && CairoLyricsService.lines.length > 0)
                                    ? CairoLyricsService.lines
                                    : LyricsService.lines
    readonly property bool hasLyrics: hasTrack && rawLines && rawLines.length > 0

    property var tokens: []
    property int currentTokenIndex: -1

    // ── 1. 60 FPS Interpolated Wall-Clock Audio Engine ────────────────────────
    property double songEpochMs: 0
    property real livePositionMs: 0

    function syncBaseTime() {
        var player = LyricsService.activePlayer
        var rawPos = player ? player.position : 0
        var posMs = (rawPos > 1000000) ? (rawPos / 1000) : (rawPos < 36000 ? rawPos * 1000 : rawPos)
        if (isNaN(posMs) || posMs < 0) posMs = 0
        root.songEpochMs = Date.now() - posMs
        root.livePositionMs = posMs
        root.updateTokenIndex()
    }

    onIsPlayingChanged: {
        if (root.isPlaying) {
            root.syncBaseTime()
        }
    }

    onActiveChanged: {
        if (root.active && root.isPlaying) {
            root.syncBaseTime()
        }
    }

    Timer {
        id: liveClockTimer
        interval: 16
        repeat: true
        running: root.active && root.isPlaying && root.hasLyrics
        onTriggered: {
            if (root.songEpochMs > 0 && root.isPlaying) {
                root.livePositionMs = Math.max(0, Date.now() - root.songEpochMs)
            }
            root.updateTokenIndex()
        }
    }

    // ── 2. Word Tokenizer (Word-level LRC or Procedural Rhythm Chunks) ────────
    onRawLinesChanged: rebuildTokens()
    onHasTrackChanged: rebuildTokens()

    function rebuildTokens() {
        var srcLines = root.rawLines || []
        if (srcLines.length === 0 || !root.hasTrack) {
            root.tokens = []
            root.currentTokenIndex = -1
            return
        }

        var result = []
        for (var l = 0; l < srcLines.length; l++) {
            var line = srcLines[l]
            var lineStart = line.time || 0
            var nextLineStart = (l + 1 < srcLines.length && srcLines[l + 1].time) ? srcLines[l + 1].time : (lineStart + 4200)
            var lineDuration = Math.max(800, nextLineStart - lineStart)

            if (line.words && line.words.length > 0) {
                for (var w = 0; w < line.words.length; w++) {
                    var wd = line.words[w]
                    var wStart = (wd.time !== undefined) ? wd.time : lineStart
                    var wEnd = (w + 1 < line.words.length && line.words[w + 1].time !== undefined)
                               ? line.words[w + 1].time
                               : (wStart + (wd.duration || 320))
                    result.push({
                        text: (wd.text || "").trim(),
                        startMs: wStart,
                        endMs: Math.max(wStart + 100, wEnd)
                    })
                }
            } else {
                var txt = (line.text || "").trim()
                if (txt.length === 0) continue
                var words = txt.split(/\s+/).filter(function(x) { return x.length > 0 })
                if (words.length === 0) continue

                var chunks = []
                var idx = 0
                while (idx < words.length) {
                    if (idx + 1 < words.length && (words[idx].length + words[idx + 1].length) < 13) {
                        chunks.push(words[idx] + " " + words[idx + 1])
                        idx += 2
                    } else {
                        chunks.push(words[idx])
                        idx += 1
                    }
                }

                var activeWindow = Math.min(lineDuration * 0.90, chunks.length * 480)
                var chunkDuration = activeWindow / chunks.length
                for (var c = 0; c < chunks.length; c++) {
                    var cStart = lineStart + (c * chunkDuration)
                    var cEnd = cStart + chunkDuration
                    result.push({
                        text: chunks[c],
                        startMs: cStart,
                        endMs: cEnd
                    })
                }
            }
        }

        root.tokens = result
        root.syncBaseTime()
    }

    function updateTokenIndex() {
        var toks = root.tokens
        if (!toks || toks.length === 0) {
            root.currentTokenIndex = -1
            return
        }

        var pos = root.livePositionMs
        var cur = root.currentTokenIndex

        if (cur >= 0 && cur < toks.length) {
            if (pos >= toks[cur].startMs && pos < toks[cur].endMs) {
                return
            }
        }

        var found = -1
        for (var i = 0; i < toks.length; i++) {
            if (pos >= toks[i].startMs && pos < toks[i].endMs) {
                found = i
                break
            }
            if (pos < toks[i].startMs) {
                found = Math.max(0, i - 1)
                break
            }
        }
        if (found === -1 && toks.length > 0) {
            if (pos >= toks[toks.length - 1].endMs) {
                found = toks.length - 1
            } else {
                found = 0
            }
        }
        if (root.currentTokenIndex !== found) {
            root.currentTokenIndex = found
        }
    }

    Component.onCompleted: {
        rebuildTokens()
        syncBaseTime()
    }

    // ── 3. Empty State (Strictly preserves the user's favorite notice) ─────────
    Item {
        anchors.fill: parent
        visible: !root.hasLyrics

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "music_note"
                font.family: Theme.fontIcon
                font.pixelSize: 18
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.hasTrack ? "uh oh we got no lyrics for this !" : "STANDBY // NO MEDIA"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(10.5)
                font.weight: Font.Medium
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // ── 4. Mini Cairo 3-Slot Kinetic Barrel ────────────────────────────────────
    Item {
        id: kineticBarrel
        anchors.fill: parent
        clip: true
        visible: root.hasLyrics

        readonly property real centerY: height / 2
        readonly property var toks: root.tokens
        readonly property int idx: root.currentTokenIndex

        readonly property string prevText: (idx > 0 && idx - 1 < toks.length) ? toks[idx - 1].text : ""
        readonly property string curText: (idx >= 0 && idx < toks.length) ? toks[idx].text : ""
        readonly property string nextText: (idx + 1 < toks.length) ? toks[idx + 1].text : ""

        // Slot 0: Previous Word (Receding upward, Stage 1)
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            y: kineticBarrel.centerY - 34 - height / 2
            width: prevTxt.implicitWidth
            height: prevTxt.implicitHeight
            opacity: prevText.length > 0 ? 0.35 : 0.0
            scale: 0.88

            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

            Text {
                id: prevTxt
                anchors.centerIn: parent
                text: kineticBarrel.prevText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(11)
                font.weight: Font.Medium
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.60)
            }
        }

        // Slot 1: Active Word (Stage 0 with Cairo Glass Tape Highlight)
        Item {
            id: activeWordSlot
            anchors.horizontalCenter: parent.horizontalCenter
            y: kineticBarrel.centerY - height / 2
            width: Math.max(80, curTxt.implicitWidth + 28)
            height: curTxt.implicitHeight + 10
            opacity: curText.length > 0 ? 1.0 : 0.0

            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutQuint } }
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

            // Cairo Signature Translucent Glass Tape Block
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.65)
                border.width: 1
                z: -1

                // Subtle ambient glow border
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    radius: 7
                    color: "transparent"
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                    border.width: 1
                }
            }

            // Word Text
            Text {
                id: curTxt
                anchors.centerIn: parent
                text: kineticBarrel.curText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(15)
                font.weight: Font.ExtraBold
                font.letterSpacing: -0.4
                color: Theme.fg

                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: curTxt; property: "scale"; to: 0.94; duration: 40; easing.type: Easing.OutQuad }
                        NumberAnimation { target: curTxt; property: "scale"; to: 1.0; duration: 90; easing.type: Easing.OutBack }
                    }
                }
            }
        }

        // Slot 2: Next Incoming Word (Stage -1)
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            y: kineticBarrel.centerY + 34 - height / 2
            width: nextTxt.implicitWidth
            height: nextTxt.implicitHeight
            opacity: nextText.length > 0 ? 0.45 : 0.0
            scale: 0.90

            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

            Text {
                id: nextTxt
                anchors.centerIn: parent
                text: kineticBarrel.nextText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(11)
                font.weight: Font.Medium
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.70)
            }
        }
    }
}
