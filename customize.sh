SKIPUNZIP=0

IMG=/data/adb/cler1818_full_system_overlayfs.img
OLDMOD=/data/adb/modules/zenlua_etc_ext4
DISABLE_FLAG=/data/adb/cler1818_full_system_overlayfs.disable

DEVICE="$(getprop ro.product.device)"
ANDROID="$(getprop ro.build.version.release)"

[ "$DEVICE" = "fuxi" ] || abort "! 本版本仅验证小米 13（fuxi），当前设备：$DEVICE"
[ "$ANDROID" = "14" ] || abort "! 本版本仅验证 Android 14，当前版本：$ANDROID"

if [ -d "$OLDMOD" ] && [ ! -f "$OLDMOD/remove" ]; then
  abort "! 检测到旧 zenlua_etc_ext4 模块。请先卸载旧模块并重启后再安装。"
fi

rm -f "$DISABLE_FLAG"

ui_print "- 创建 4 GiB 稀疏 ext4 持久化写入层"
if [ ! -f "$IMG" ]; then
  /system/bin/truncate -s 4294967296 "$IMG" || abort "! 无法创建 ext4 镜像"
  /system/bin/mkfs.ext4 -F "$IMG" >/dev/null 2>&1 || abort "! 无法格式化 ext4 镜像"
fi

chown 0:0 "$IMG"
chmod 600 "$IMG"
chcon u:object_r:magisk_file:s0 "$IMG"

ui_print "- 挂载将在 Android 完成开机 30 秒后启用"
ui_print "- 不覆盖根目录、基带/DSP/蓝牙固件及虚拟文件系统"

