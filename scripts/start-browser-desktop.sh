#!/bin/bash
set -euo pipefail
SESSION_DIR="$RUNNER_TEMP/ios-desktop-session"
mkdir -p "$SESSION_DIR" diagnostics session
chmod 700 "$SESSION_DIR"
export DESKTOP_SESSION_TOKEN=$(openssl rand -hex 32)
export DESKTOP_VNC_PASSWORD=$(openssl rand -hex 4)
echo "::add-mask::$DESKTOP_SESSION_TOKEN"
echo "::add-mask::$DESKTOP_VNC_PASSWORD"
export NOVNC_DIRECTORY="$SESSION_DIR/noVNC"
export DESKTOP_STOP_FILE="$SESSION_DIR/stop"
printf '%s\n' "$SESSION_DIR" > "$RUNNER_TEMP/ios-desktop-session-path"

python3 -m venv "$SESSION_DIR/venv"
"$SESSION_DIR/venv/bin/pip" -q install aiohttp
brew install cloudflared
git clone --quiet --depth 1 --branch v1.7.0 https://github.com/novnc/noVNC.git "$NOVNC_DIRECTORY"

ARD=/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart
sudo "$ARD" -activate -configure -access -on -users "$(id -un)" -privs -all -clientopts -setvnclegacy -vnclegacy yes -clientopts -setvncpw -vncpw "$DESKTOP_VNC_PASSWORD" -restart -agent 2>&1 | tee diagnostics/screen-sharing.txt
# Launch only this repository's generated demo project.
open DesktopDebugDemo.xcodeproj

# Processes are bounded by the final step and the workflow's 20-minute limit.
nohup "$SESSION_DIR/venv/bin/python" scripts/browser-desktop.py > "$SESSION_DIR/viewer.log" 2>&1 &
printf '%s\n' "$!" > "$SESSION_DIR/viewer.pid"
nohup cloudflared tunnel --url http://127.0.0.1:6080 --no-autoupdate > "$SESSION_DIR/tunnel.log" 2>&1 &
printf '%s\n' "$!" > "$SESSION_DIR/tunnel.pid"

python3 - "$SESSION_DIR" <<'PY'
import os,re,sys,time,urllib.request
from pathlib import Path
p=Path(sys.argv[1])
for _ in range(45):
    text=(p/"tunnel.log").read_text(errors="replace") if (p/"tunnel.log").exists() else ""
    match=re.search(r"https://[a-z0-9-]+\.trycloudflare\.com",text)
    if match:
        url=match.group(0)+"/"+os.environ["DESKTOP_SESSION_TOKEN"]+"/"
        (p/"connection.txt").write_text(url)
        print("Temporary connection created; its private URL will be encrypted.")
        break
    time.sleep(1)
else:
    print("Tunnel setup failed. See retained local diagnostics.")
    raise SystemExit(1)
# Check that unauthorized requests cannot access the viewer.
try:
    urllib.request.urlopen("http://127.0.0.1:6080/not-authorized/",timeout=5)
    raise RuntimeError("Viewer incorrectly allowed an unauthorized request")
except urllib.error.HTTPError as error:
    if error.code!=404: raise
print("Unauthorized request rejected.")
PY
openssl pkeyutl -encrypt -pubin -inkey debug-session-public.pem -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256 -in "$SESSION_DIR/connection.txt" -out session/connection.enc
printf 'Temporary browser desktop prepared. Credentials are encrypted; remote control is not yet verified.\n' > diagnostics/session-status.txt
