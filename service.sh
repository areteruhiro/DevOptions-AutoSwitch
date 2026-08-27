#!/system/bin/sh

MODDIR=${0%/*}
DATA_DIR=/data/adb/devmode-cloak

while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 2
done

mkdir -p "$DATA_DIR/runtime"
[ -f "$DATA_DIR/config.conf" ] || cp -f "$MODDIR/defaults/config.conf" "$DATA_DIR/config.conf"
[ -f "$DATA_DIR/targets.txt" ] || cp -f "$MODDIR/defaults/targets.txt" "$DATA_DIR/targets.txt"
chmod 0700 "$DATA_DIR" "$DATA_DIR/runtime"
chmod 0600 "$DATA_DIR/config.conf" "$DATA_DIR/targets.txt" 2>/dev/null

nohup sh "$MODDIR/daemon.sh" >> "$DATA_DIR/devmode-cloak.log" 2>&1 &

