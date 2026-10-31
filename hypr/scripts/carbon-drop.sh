#!/usr/bin/env bash
# ==============================================================================
# Carbon Shell — Carbon Drop Toggler / Launcher
# ==============================================================================

BIN_DROP="${HOME}/.local/bin/carbon-drop"

if pgrep -f "CarbonDrop.qml" > /dev/null || pgrep -x "carbon-drop" > /dev/null; then
    pkill -f "CarbonDrop.qml" 2>/dev/null || true
    pkill -x "carbon-drop" 2>/dev/null || true
else
    if [ -x "$BIN_DROP" ]; then
        nohup "$BIN_DROP" >/dev/null 2>&1 &
    else
        QML_PATH="$HOME/.local/share/quickshell/carbon/modules/CarbonDrop.qml"
        nohup quickshell -p "$QML_PATH" >/dev/null 2>&1 &
    fi
fi

