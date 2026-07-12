#!/system/bin/sh

MODDIR=${0%/*}
DISABLE_FLAG=/data/adb/cler1818_full_system_overlayfs.disable

if grep -q 'cler1818_full_overlayfs' /proc/mounts; then
  touch "$DISABLE_FLAG"
  sh "$MODDIR/unmount.sh"
  echo "全系统可写层已关闭；修改数据仍保留在 ext4 镜像中。"
else
  rm -f "$DISABLE_FLAG" "$MODDIR/disable"
  sh "$MODDIR/service.sh"
  echo "全系统可写层已请求启用，请查看 overlay.log。"
fi

