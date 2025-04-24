#!/system/bin/sh
rm -rf /data/adb/docker

SERVICE_DIR="/data/adb/service.d"
if [ -f "$SERVICE_DIR/dockerd_service.sh" ]; then
    rm -f "$SERVICE_DIR/dockerd_service.sh"
fi