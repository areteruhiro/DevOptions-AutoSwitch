#!/system/bin/sh

DATA_DIR=/data/adb/devmode-cloak
STATE_FILE="$DATA_DIR/runtime/original-state.conf"

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

if [ -f "$STATE_FILE" ]; then
  original_developer='__DELETE__'
  original_usb='__DELETE__'
  original_wifi='__DELETE__'
  # shellcheck disable=SC1090
  . "$STATE_FILE"
  restore_one global development_settings_enabled "$original_developer"
  [ "${saved_usb:-0}" = '1' ] && restore_one global adb_enabled "$original_usb"
  [ "${saved_wifi:-0}" = '1' ] && restore_one global adb_wifi_enabled "$original_wifi"
fi

rm -rf "$DATA_DIR"

