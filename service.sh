#!/system/bin/sh

MODDIR=${0%/*}
IMG=/data/adb/cler1818_full_system_overlayfs.img
BASE=/dev/cler1818_full_overlayfs
EXT4=$BASE/ext4
SNAP=$BASE/snapshot
STATE=$MODDIR/mounted.order
SNAPSTATE=$MODDIR/snapshot.order
LOG=$MODDIR/overlay.log
LOCK=$BASE/lock
DISABLE_FLAG=/data/adb/cler1818_full_system_overlayfs.disable
BB=/data/adb/magisk/busybox

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }
key_for() { echo "$1" | sed 's#^/##; s#/#__#g'; }

reverse_file() {
  awk '{ line[NR]=$0 } END { for (i=NR; i>0; i--) print line[i] }' "$1"
}

rollback() {
  log "开始反向回滚"
  if [ -s "$STATE" ]; then
    reverse_file "$STATE" | while IFS= read -r target; do
      if [ -n "$target" ]; then
        umount "$target" 2>>"$LOG" || umount -l "$target" 2>>"$LOG"
      fi
    done
  fi
  if [ -s "$SNAPSTATE" ]; then
    reverse_file "$SNAPSTATE" | while IFS='|' read -r target snapdir; do
      if [ -n "$snapdir" ]; then
        umount "$snapdir" 2>>"$LOG" || umount -l "$snapdir" 2>>"$LOG"
      fi
    done
  fi
  umount "$EXT4" 2>>"$LOG" || umount -l "$EXT4" 2>>"$LOG"
  rm -f "$STATE" "$SNAPSTATE"
  rmdir "$LOCK" 2>/dev/null
}

fail() {
  log "失败：$*"
  touch "$MODDIR/disable" "$DISABLE_FLAG"
  rollback
  exit 1
}

[ -f "$DISABLE_FLAG" ] && exit 0

while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 2; done
sleep 30

mkdir -p "$BASE" || exit 1
mkdir "$LOCK" 2>/dev/null || exit 0
: > "$LOG"
: > "$STATE"
: > "$SNAPSTATE"

grep -q 'cler1818_full_overlayfs' /proc/mounts && fail "检测到旧挂载，拒绝重复叠加"
grep -q 'ZenluaEtc' /proc/mounts && fail "检测到旧 /system/etc Overlay，拒绝竞争挂载"

mkdir -p "$EXT4" "$SNAP"
mount -o loop,rw "$IMG" "$EXT4" >>"$LOG" 2>&1 || fail "ext4 镜像挂载失败"

# 在覆盖父目录前，用普通 bind 保存每个目标当时的合成视图。
while IFS= read -r target; do
  case "$target" in ''|'#'*) continue ;; esac
  [ -d "$target" ] || { log "跳过不存在目录：$target"; continue; }
  key="$(key_for "$target")"
  snapdir="$SNAP/$key"
  mkdir -p "$snapdir" || fail "无法创建快照目录 $target"
  mount --bind "$target" "$snapdir" >>"$LOG" 2>&1 || fail "无法快照 $target"
  echo "$target|$snapdir" >> "$SNAPSTATE"
  # Android 的根挂载通常是 shared；快照必须改为 private，防止后续
  # Overlay 事件反向传播到 lowerdir 快照并形成递归挂载。
  [ -x "$BB" ] || fail "找不到 Magisk BusyBox"
  "$BB" mount --make-private "$snapdir" >>"$LOG" 2>&1 || fail "无法隔离快照 $target"
  mount -o remount,bind,ro "$snapdir" >>"$LOG" 2>&1 || fail "无法锁定只读快照 $target"
done < "$MODDIR/mounts.conf"

# 父 Overlay 会遮蔽现有子挂载的卸载路径，因此必须先按最深到最浅
# 卸载 MIUI 的只读 Overlay。原始 lowerdir 已记录在配置文件中，稍后重建。
reverse_file "$MODDIR/miui-overlays.conf" > "$BASE/miui.reverse"
while IFS='|' read -r target lowers; do
  case "$target" in ''|'#'*) continue ;; esac
  while awk -v p="$target" '$2 == p && $3 == "overlay" { found=1 } END { exit !found }' /proc/mounts; do
    umount "$target" >>"$LOG" 2>&1 || umount -l "$target" >>"$LOG" 2>&1 \
      || fail "无法预先卸载原 MIUI 层 $target"
  done
done < "$BASE/miui.reverse"

# 先按父到子顺序建立基础目录 Overlay；Magisk 所在的 /product/bin 留到最后。
while IFS='|' read -r target snapdir; do
  [ "$target" = "/product/bin" ] && continue
  key="$(key_for "$target")"
  layer="$EXT4/layers/$key"
  upper="$layer/upper"
  work="$layer/work"
  mkdir -p "$upper" "$work" || fail "无法创建写入层 $target"
  context="$(ls -Zd "$target" 2>/dev/null | awk '{print $1}')"
  case "$context" in u:object_r:*:s0) chcon "$context" "$layer" "$upper" "$work" 2>/dev/null ;; esac
  chmod 755 "$layer" "$upper" "$work"
  mount -t overlay "cler1818_full_overlayfs_$key" \
    -o "lowerdir=$snapdir,upperdir=$upper,workdir=$work" "$target" >>"$LOG" 2>&1 \
    || fail "Overlay 挂载失败 $target"
  echo "$target" >> "$STATE"
done < "$SNAPSTATE"

# MIUI 的只读子目录本身已经是 Overlay，不能把 Overlay 再直接当作
# lowerdir 叠加。先卸载其只读层，再复用原始 lowerdir 加入可写层。
while IFS='|' read -r target lowers; do
  case "$target" in ''|'#'*) continue ;; esac
  [ -d "$target" ] || { log "跳过不存在的 MIUI 目录：$target"; continue; }
  key="$(key_for "$target")"
  layer="$EXT4/layers/$key"
  upper="$layer/upper"
  work="$layer/work"
  mkdir -p "$upper" "$work" || fail "无法创建 MIUI 写入层 $target"
  context="$(ls -Zd "$target" 2>/dev/null | awk '{print $1}')"
  case "$context" in u:object_r:*:s0) chcon "$context" "$layer" "$upper" "$work" 2>/dev/null ;; esac
  chmod 755 "$layer" "$upper" "$work"
  mount -t overlay "cler1818_full_overlayfs_$key" \
    -o "lowerdir=$lowers,upperdir=$upper,workdir=$work" "$target" >>"$LOG" 2>&1 \
    || fail "MIUI Overlay 重建失败 $target"
  echo "$target" >> "$STATE"
done < "$MODDIR/miui-overlays.conf"

# 最后让 Magisk 的 /product/bin 合成视图可写。
product_bin_snap=""
while IFS='|' read -r target snapdir; do
  [ "$target" = "/product/bin" ] && product_bin_snap="$snapdir"
done < "$SNAPSTATE"
[ -n "$product_bin_snap" ] || fail "缺少 /product/bin 快照"
key=product__bin
layer="$EXT4/layers/$key"
upper="$layer/upper"
work="$layer/work"
mkdir -p "$upper" "$work" || fail "无法创建 /product/bin 写入层"
context="$(ls -Zd /product/bin 2>/dev/null | awk '{print $1}')"
case "$context" in u:object_r:*:s0) chcon "$context" "$layer" "$upper" "$work" 2>/dev/null ;; esac
chmod 755 "$layer" "$upper" "$work"
mount -t overlay "cler1818_full_overlayfs_product__bin" \
  -o "lowerdir=$product_bin_snap,upperdir=$upper,workdir=$work" /product/bin >>"$LOG" 2>&1 \
  || fail "Overlay 挂载失败 /product/bin"
echo /product/bin >> "$STATE"

# /product/bin 是 Magisk 注入位置；显式恢复运行入口。
MAGISKTMP="$(magisk --path 2>/dev/null)"
[ -x "$MAGISKTMP/magisk" ] || MAGISKTMP=/debug_ramdisk
[ -x "$MAGISKTMP/magisk" ] || fail "找不到 Magisk 恢复入口"

touch /product/bin/magisk /product/bin/magiskpolicy 2>/dev/null
mount --bind "$MAGISKTMP/magisk" /product/bin/magisk >>"$LOG" 2>&1 || fail "恢复 Magisk 入口失败"
if [ -x "$MAGISKTMP/magiskpolicy" ]; then
  mount --bind "$MAGISKTMP/magiskpolicy" /product/bin/magiskpolicy >>"$LOG" 2>&1 || fail "恢复 magiskpolicy 失败"
fi
ln -sf ./magisk /product/bin/su
ln -sf ./magisk /product/bin/resetprop

# 最小健康检查；任一失败立即禁用并回滚。
[ -x /system/bin/sh ] || fail "/system/bin/sh 不可执行"
[ "$(getenforce)" = "Enforcing" ] || fail "SELinux 状态异常"
pidof system_server >/dev/null || fail "system_server 不存在"
pidof zygote64 >/dev/null || fail "zygote64 不存在"
pidof netd >/dev/null || fail "netd 不存在"
"$MAGISKTMP/magisk" su -c id 2>/dev/null | grep -q 'uid=0' || fail "直接 Magisk Root 失败"
/product/bin/su -c id 2>/dev/null | grep -q 'uid=0' || fail "普通 su 失败"

log "全部 Overlay 挂载与基础健康检查通过"
rmdir "$LOCK" 2>/dev/null
exit 0
