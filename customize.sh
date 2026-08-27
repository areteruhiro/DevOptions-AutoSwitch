#!/system/bin/sh

SKIPMOUNT=true
PROPFILE=false
POSTFSDATA=false
LATESTARTSERVICE=true

DATA_DIR=/data/adb/devmode-cloak
USB_MIGRATION_MARKER="$DATA_DIR/.usb-default-v10001"

ui_print "- DevOptions AutoSwitch"
ui_print "- No LSPosed, Zygisk, native hook, or system mount"
ui_print "- Default target: jp.co.smbc.direct"

mkdir -p "$DATA_DIR/runtime"

if [ ! -f "$DATA_DIR/config.conf" ]; then
  cp -f "$MODPATH/defaults/config.conf" "$DATA_DIR/config.conf"
fi

# v1.0.0 deliberately left USB ADB enabled. SMBC checks adb_enabled separately,
# so migrate that initial configuration once when installing/updating v1.0.1.
if [ ! -f "$USB_MIGRATION_MARKER" ] && [ -f "$DATA_DIR/config.conf" ]; then
  sed -i 's/^HIDE_USB_ADB=.*/HIDE_USB_ADB=1/' "$DATA_DIR/config.conf"
  touch "$USB_MIGRATION_MARKER"
  ui_print "- Migrated HIDE_USB_ADB=1 for SMBC"
fi

if [ ! -f "$DATA_DIR/targets.txt" ]; then
  cp -f "$MODPATH/defaults/targets.txt" "$DATA_DIR/targets.txt"
fi

touch "$DATA_DIR/devmode-cloak.log"

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/daemon.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm_recursive "$DATA_DIR" 0 0 0700 0600

ui_print "- Persistent config: $DATA_DIR"
ui_print "- Reboot is required before monitoring starts"
