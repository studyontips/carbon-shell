pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "."

/**
 * CairoLyricsService:
 * Dedicated Singleton managing lyrics fetching and kinetic timeline data specifically for Cairo.
 * Fully decoupled from Shell lyrics.
 *
 * Supports:
 *   - Dedicated rich word-level / syllable-level lyric loading (--mode cairo)
 *   - Instant live Romanisation switching via LockState.cairoRomanizeLyrics
 *   - Zero interference with Minimal Island / Nucleus Hub / Notch mode shell lyrics
 */
Singleton {
    id: root

    readonly property var activePlayer: LyricsService.activePlayer
    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string trackAlbum: activePlayer && activePlayer.metadata ? (activePlayer.metadata["xesam:album"] || "") : ""
    readonly property string trackId: activePlayer && activePlayer.metadata ? (activePlayer.metadata["mpris:trackid"] || "") : ""
    readonly property string artUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property bool hasTrack: trackTitle.trim().length > 0

    readonly property real currentPosition: LyricsService.currentPosition
    readonly property real totalLength: LyricsService.totalLength

    property var lines: []
    property bool hasLyrics: lines.length > 0
    readonly property bool hasRichWords: {
        if (!lines || lines.length === 0) return false
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].words && lines[i].words.length > 0) return true
        }
        return false
    }

    property string lastFetchedKey: ""

    // Watch for live toggle of Romanisation from Config Editor or IPC
    Connections {
        target: LockState
        function onCairoRomanizeLyricsChanged() {
            console.log("[CairoLyricsService] LockState.cairoRomanizeLyrics changed to:", LockState.cairoRomanizeLyrics)
            root.reloadLyrics()
        }
    }

    onTrackTitleChanged: {
        root.lines = []
        if (lyricsProc.running) lyricsProc.running = false
        fetchLyrics()
    }
    onTrackArtistChanged: {
        root.lines = []
        if (lyricsProc.running) lyricsProc.running = false
        fetchLyrics()
    }
    onTotalLengthChanged: {
        if (root.totalLength > 10 && !root.hasLyrics && !lyricsProc.running) {
            var key = root.trackTitle + "::" + root.trackArtist + "::" + (LockState.cairoRomanizeLyrics ? "rom" : "raw")
            if (root.lastFetchedKey !== key) {
                root.fetchLyrics()
            }
        }
    }

    function reloadLyrics() {
        root.lastFetchedKey = ""
        root.lines = []
        if (lyricsProc.running) lyricsProc.running = false
        root.fetchLyrics()
    }

    function fetchLyrics() {
        var title = root.trackTitle
        var artist = root.trackArtist
        if (!title || title.trim().length === 0) {
            root.lines = []
            return
        }

        var romanize = Boolean(LockState.cairoRomanizeLyrics)
        var key = title + "::" + artist + "::" + (romanize ? "rom" : "raw")
        if (root.lastFetchedKey === key && (root.lines.length > 0 || lyricsProc.running)) return
        if (lyricsProc.running) return

        root.lastFetchedKey = key
        lyricsProc.requestedKey = key

        var home = Quickshell.env("HOME") || ""
        var carbonScript = home + "/.config/carbon/scripts/carbon-lyrics.py"
        var scriptPath = Quickshell.env("CARBON_LYRICS_PATH") || carbonScript

        var cmd = [
            "python3",
            scriptPath,
            "--title", title,
            "--artist", artist,
            "--duration", String(Math.round(root.totalLength)),
            "--mode", "cairo",
            romanize ? "--romanize" : "--no-romanize"
        ]
        if (root.trackId && root.trackId.length > 0) {
            cmd.push("--trackid", root.trackId)
        }
        lyricsProc.command = cmd
        console.log("[CairoLyricsService] Running:", lyricsProc.command.join(" "))
        lyricsProc.running = true
    }

    Process {
        id: lyricsProc
        property string buffer: ""
        property string requestedKey: ""

        stdout: SplitParser {
            onRead: (line) => {
                lyricsProc.buffer += line + "\n"
            }
        }
        stderr: SplitParser {
            onRead: (line) => {
                console.log("[CairoLyricsService stderr]", line)
            }
        }

        onRunningChanged: {
            if (running) {
                buffer = ""
            } else {
                if (requestedKey !== root.lastFetchedKey) {
                    console.log("[CairoLyricsService] Ignoring stale lyrics for:", requestedKey, "current:", root.lastFetchedKey)
                    return
                }
                if (buffer.trim().length > 0) {
                    try {
                        const res = JSON.parse(buffer)
                        if (res && res.found && Array.isArray(res.lines) && res.lines.length > 0) {
                            root.lines = res.lines
                            console.log("[CairoLyricsService] Loaded " + root.lines.length + " kinetic lyric lines for Cairo:", root.trackTitle, "(romanize=" + LockState.cairoRomanizeLyrics + ")")
                        } else {
                            root.lines = []
                        }
                    } catch (e) {
                        console.log("[CairoLyricsService] Error parsing lyrics JSON:", e)
                        root.lines = []
                    }
                } else {
                    root.lines = []
                }
            }
        }
    }

    Component.onCompleted: {
        console.log("[CairoLyricsService] Initialized (cairoRomanizeLyrics=" + LockState.cairoRomanizeLyrics + ")")
        fetchLyrics()
    }
}
