#!/system/bin/sh
SKIPUNZIP=0
SKIPMOUNT=false

if [ "$BOOTMODE" != true ]; then
  ui_print "! Please install in Magisk Manager or KernelSU Manager"
  ui_print "! Install from recovery is NOT supported"
  abort "-----------------------------------------------------------"
elif [ "$KSU" = true ] && [ "$KSU_VER_CODE" -lt 10670 ]; then
  abort "error: Please update your KernelSU and KernelSU Manager"
fi

SERVICE_DIR="/data/adb/service.d"

CUSTOM_DIR="/data/adb/docker"

#Stop any running dockerd service
if [ -f "$CUSTOM_DIR/scripts/dockerd.service" ]; then
  ui_print "- Stopping dockerd service"
  "$CUSTOM_DIR/scripts/dockerd.service" stop 2>&1 > /dev/null
fi

ui_print "- Creating directories"

mkdir -p "$CUSTOM_DIR" "$SERVICE_DIR"

ui_print "- Extracting docker binaries"

tar -xf "$MODPATH/docker.tar.xz" -C "$CUSTOM_DIR"

rm -f "$MODPATH/docker.tar.xz"

ui_print "- Moving files to $CUSTOM_DIR"

mv -f "$MODPATH/dockerd/scripts" "$CUSTOM_DIR/scripts"
mv -f "$MODPATH/dockerd/settings.ini" "$CUSTOM_DIR/settings.ini"

rm -rf "$MODPATH/dockerd"

ui_print "- Setting permissions"
set_perm_recursive $CUSTOM_DIR 0 0 0755 0755
set_perm_recursive $MODPATH/system/bin 0 0 0755 0755
set_perm $MODPATH/service.sh 0 0 0755
mv -f "$MODPATH/service.sh" "$SERVICE_DIR/dockerd_service.sh"