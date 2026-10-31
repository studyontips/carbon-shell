#!/usr/bin/env bash
# ==============================================================================
# Carbon Shell — Carbon Drop Toggler / Launcher
# ==============================================================================

BIN_DROP="${HOME}/.local/bin/carbon-drop"

if pgrep -f "CarbonDrop.qml" > /dev/null || pgrep -x "carbon-drop" > /dev/null; then
    ACTIVE_TITLE=$(hyprctl activewindow -j 2>/dev/null | jq -r '.title // empty' 2>/dev/null)
    if [ "$ACTIVE_TITLE" = "Carbon Drop" ]; then
        hyprctl dispatch closewindow "title:Carbon Drop"
    else
        hyprctl dispatch focuswindow "title:Carbon Drop"
    fi
else
    if [ -x "$BIN_DROP" ]; then
        nohup "$BIN_DROP" >/dev/null 2>&1 &
    else
        QML_PATH="$HOME/.local/share/quickshell/carbon/modules/CarbonDrop.qml"
        nohup quickshell -p "$QML_PATH" >/dev/null 2>&1 &
    fi
fi

