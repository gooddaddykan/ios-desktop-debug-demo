#!/bin/bash
set -euo pipefail
mkdir -p diagnostics
{
  sw_vers
  uname -m
  xcodebuild -version
  printf '\nConsole session: '
  stat -f '%Su' /dev/console
  printf '\nDisplay information:\n'
  system_profiler SPDisplaysDataType
} | tee diagnostics/system.txt

# Configure only the current ephemeral runner user. The random credential never
# leaves this machine and is not uploaded. Do not modify TCC or SIP databases.
DESKTOP_TEST_PASSWORD=$(openssl rand -hex 4)
echo "::add-mask::$DESKTOP_TEST_PASSWORD"
ARD=/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart
cleanup() {
  sudo "$ARD" -deactivate >/dev/null 2>&1 || true
  unset DESKTOP_TEST_PASSWORD
}
trap cleanup EXIT

set +e
sudo "$ARD" -activate -configure -access -on -users "$(id -un)" -privs -all -clientopts -setvnclegacy -vnclegacy yes -clientopts -setvncpw -vncpw "$DESKTOP_TEST_PASSWORD" -restart -agent 2>&1 | tee diagnostics/screen-sharing.txt
ARD_RESULT=${PIPESTATUS[0]}
set -e
printf 'Screen Sharing configuration exit status: %s\n' "$ARD_RESULT" | tee -a diagnostics/screen-sharing.txt

python3 - <<'PY' | tee diagnostics/vnc-probe.txt
import socket, time
for attempt in range(6):
    try:
        with socket.create_connection(("127.0.0.1", 5900), timeout=3) as connection:
            connection.settimeout(3)
            banner = connection.recv(12)
            print("VNC protocol banner:", repr(banner))
            if not banner.startswith(b"RFB "):
                raise RuntimeError("Not a VNC server")
            connection.sendall(b"RFB 003.008\n")
            count = connection.recv(1)
            if count:
                print("VNC security types:", list(connection.recv(count[0])))
            print("LOCAL_VNC_HANDSHAKE_OK; desktop access is still unverified.")
            break
    except Exception as error:
        print("Probe", attempt + 1, type(error).__name__, str(error))
        time.sleep(2)
else:
    print("LOCAL_VNC_HANDSHAKE_FAILED")
PY
