#!/bin/sh
# Carbon IPC client: send one command to the shell over its unix socket.
# Commands: wallpaper, launcher, toggle-launcher.
# No socat/nc on this box, so a tiny python client does the writing.
cmd="$*"
[ -z "$cmd" ] && cmd="toggle-launcher"
exec python3 -c '
import socket, sys
cmd = sys.argv[1]
path = "/tmp/carbon-shell.sock"
try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(1.0)
    s.connect(path)
    s.sendall((cmd + "\n").encode())
    s.close()
except OSError:
    sys.exit(1)
' "$cmd"