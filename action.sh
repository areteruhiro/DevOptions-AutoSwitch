#!/system/bin/sh

DATA_DIR=${DEVMODE_CLOAK_DATA_DIR:-/data/adb/devmode-cloak}
PAUSE_FILE="$DATA_DIR/pause"
PID_FILE="$DATA_DIR/runtime/daemon.pid"
LOG_FILE="$DATA_DIR/devmode-cloak.log"
MODDIR=${0%/*}
MODULE_ID=devmode_cloak
WEBUI_URI="ksu://webui/$MODULE_ID"

rm -f "$PAUSE_FILE"
mkdir -p "$DATA_DIR/runtime"

# KernelSU and SukiSU managers expose module WebUI pages through this deep link.
# Keep the terminal action below as a fallback for managers without WebUI support.
if command -v cmd >/dev/null 2>&1 \
  && cmd package resolve-activity --brief \
    -a android.intent.action.VIEW \
    -c android.intent.category.DEFAULT \
    -d "$WEBUI_URI" 2>/dev/null \
    | grep -q '/'; then
  if am start --user 0 -a android.intent.action.VIEW \
    -c android.intent.category.DEFAULT \
    -d "$WEBUI_URI" >/dev/null 2>&1; then
    echo "DevOptions AutoSwitch: opening app list"
    exit 0
  fi
fi

daemon_pid=
[ -f "$PID_FILE" ] && daemon_pid=$(cat "$PID_FILE" 2>/dev/null)

if [ -n "$daemon_pid" ] && kill -0 "$daemon_pid" 2>/dev/null; then
  echo "DevOptions AutoSwitch: already running (pid=$daemon_pid)"
else
  rm -f "$PID_FILE"
  nohup sh "$MODDIR/daemon.sh" >> "$LOG_FILE" 2>&1 &
  sleep 1
  daemon_pid=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$daemon_pid" ] && kill -0 "$daemon_pid" 2>/dev/null; then
    echo "DevOptions AutoSwitch: started (pid=$daemon_pid)"
  else
    echo "DevOptions AutoSwitch: failed to start"
    echo "Log: $LOG_FILE"
    exit 1
  fi
fi

echo "Targets:"
sed 's/[[:space:]]*$//' "$DATA_DIR/targets.txt" 2>/dev/null \
  | sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d'
echo "development_settings_enabled=$(settings get global development_settings_enabled 2>/dev/null)"
echo "adb_enabled=$(settings get global adb_enabled 2>/dev/null)"
