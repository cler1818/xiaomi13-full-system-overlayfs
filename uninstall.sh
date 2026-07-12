#!/system/bin/sh

MODDIR=${0%/*}
touch /data/adb/cler1818_full_system_overlayfs.disable
sh "$MODDIR/unmount.sh"
# 为避免误删用户的系统修改，卸载模块时保留镜像。
# 确认不再需要后可手动删除：/data/adb/cler1818_full_system_overlayfs.img

