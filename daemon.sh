#!/system/bin/sh

MODDIR=${0%/*}
DATA_DIR=${DEVMODE_CLOAK_DATA_DIR:-/data/adb/devmode-cloak}
RUNTIME_DIR="$DATA_DIR/runtime"
CONFIG="$DATA_DIR/config.conf"
TARGETS="$DATA_DIR/targets.txt"
STATE_FILE="$RUNTIME_DIR/original-state.conf"
PID_FILE="$RUNTIME_DIR/daemon.pid"
PAUSE_FILE="$DATA_DIR/pause"
LOG_FILE="$DATA_DIR/devmode-cloak.log"

mkdir -p "$RUNTIME_DIR"
chmod 0700 "$DATA_DIR" "$RUNTIME_DIR"

log_msg() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

normalize_setting() {
  case "$1" in
    ''|'null') printf '%s' '__DELETE__' ;;
    *) printf '%s' "$1" ;;
  esac
}

restore_one() {
  namespace=$1
  key=$2
  value=$3
  if [ "$value" = '__DELETE__' ]; then
    settings delete "$namespace" "$key" >/dev/null 2>&1
  else
    settings put "$namespace" "$key" "$value" >/dev/null 2>&1
  fi
}

restore_state() {
  [ -f "$STATE_FILE" ] || return 0

  original_developer='__DELETE__'
  original_usb='__DELETE__'
  original_wifi='__DELETE__'
  # shellcheck disable=SC1090
  . "$STATE_FILE"

  restore_one global development_settings_enabled "$original_developer"
  if [ "${saved_usb:-0}" = '1' ]; then
    restore_one global adb_enabled "$original_usb"
  fi
  if [ "${saved_wifi:-0}" = '1' ]; then
    restore_one global adb_wifi_enabled "$original_wifi"
  fi

  rm -f "$STATE_FILE"
  log_msg "RESTORE developer=$original_developer usb_saved=${saved_usb:-0} wifi_saved=${saved_wifi:-0}"
}

load_config() {
  WATCHDOG_INTERVAL=15
  HIDE_USB_ADB=0
  HIDE_WIRELESS_ADB=0
  RESTORE_ON_EXIT=1
  if [ -f "$CONFIG" ]; then
    # shellcheck disable=SC1090
    . "$CONFIG"
  fi
  case "$WATCHDOG_INTERVAL" in
    ''|*[!0-9]*) WATCHDOG_INTERVAL=15 ;;
  esac
  [ "$WATCHDOG_INTERVAL" -ge 5 ] 2>/dev/null || WATCHDOG_INTERVAL=5
}

is_target() {
  package_name=$1
  [ -n "$package_name" ] || return 1
  [ -f "$TARGETS" ] || return 1
  sed 's/[[:space:]]*$//' "$TARGETS" \
    | sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' \
    | grep -Fqx "$package_name"
}

extract_package() {
  printf '%s\n' "$1" \
    | grep -oE '[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+/[A-Za-z0-9_.$]+' \
    | head -n 1 \
    | cut -d/ -f1
}

apply_cloak() {
  target_package=$1
  [ -f "$PAUSE_FILE" ] && return 0
  [ -f "$STATE_FILE" ] && return 0

  load_config
  current_developer=$(normalize_setting "$(settings get global development_settings_enabled 2>/dev/null)")
  current_usb=$(normalize_setting "$(settings get global adb_enabled 2>/dev/null)")
  current_wifi=$(normalize_setting "$(settings get global adb_wifi_enabled 2>/dev/null)")

  umask 077
  {
    printf "original_developer='%s'\n" "$current_developer"
    printf "original_usb='%s'\n" "$current_usb"
    printf "original_wifi='%s'\n" "$current_wifi"
    printf "saved_usb='%s'\n" "$HIDE_USB_ADB"
    printf "saved_wifi='%s'\n" "$HIDE_WIRELESS_ADB"
  } > "$STATE_FILE"

  settings put global development_settings_enabled 0 >/dev/null 2>&1
  if [ "$HIDE_USB_ADB" = '1' ]; then
    settings put global adb_enabled 0 >/dev/null 2>&1
  fi
  if [ "$HIDE_WIRELESS_ADB" = '1' ]; then
    settings put global adb_wifi_enabled 0 >/dev/null 2>&1
  fi

  actual=$(settings get global development_settings_enabled 2>/dev/null)
  log_msg "CLOAK package=$target_package developer=$current_developer->${actual:-unknown} hide_usb=$HIDE_USB_ADB hide_wifi=$HIDE_WIRELESS_ADB"
}

current_foreground_package() {
  dumpsys window displays 2>/dev/null \
    | sed -n 's/.*mCurrentFocus=.* u[0-9][0-9]* \([^/ ]*\)\/.*/\1/p' \
    | head -n 1
}

handle_package() {
  package_name=$1
  [ -n "$package_name" ] || return 0

  if [ "$package_name" = 'com.android.settings' ]; then
    restore_state
  elif is_target "$package_name"; then
    apply_cloak "$package_name"
  else
    restore_state
  fi
}

cleanup() {
  load_config
  if [ "$RESTORE_ON_EXIT" = '1' ]; then
    restore_state
  fi
  rm -f "$PID_FILE"
}

if [ -f "$PID_FILE" ]; then
  old_pid=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
    exit 0
  fi
fi

echo $$ > "$PID_FILE"
trap cleanup EXIT HUP INT TERM
load_config
restore_state

foreground=$(current_foreground_package)
handle_package "$foreground"
log_msg "START pid=$$ foreground=${foreground:-unknown}"

while true; do
  start_time=$(date '+%m-%d %H:%M:%S.000')
  logcat -b events -v tag -T "$start_time" \
    wm_create_activity:I wm_set_resumed_activity:I am_proc_start:I '*:S' 2>/dev/null \
    | while IFS= read -r event_line; do
        event_package=$(extract_package "$event_line")
        [ -n "$event_package" ] || continue

        case "$event_line" in
          *wm_create_activity*)
            if is_target "$event_package"; then
              apply_cloak "$event_package"
            fi
            ;;
          *am_proc_start*next-top-activity*)
            if is_target "$event_package"; then
              apply_cloak "$event_package"
            fi
            ;;
          *wm_set_resumed_activity*)
            handle_package "$event_package"
            ;;
        esac
      done

  log_msg "EVENT_STREAM_STOPPED retry_in=$WATCHDOG_INTERVAL"
  restore_state
  sleep "$WATCHDOG_INTERVAL"
  foreground=$(current_foreground_package)
  handle_package "$foreground"
done
