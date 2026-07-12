#!/system/bin/sh

MODDIR=${0%/*}
STATE=$MODDIR/mounted.order
SNAPSTATE=$MODDIR/snapshot.order
EXT4=/dev/cler1818_full_overlayfs/ext4

reverse_file() {
  awk '{ line[NR]=$0 } END { for (i=NR; i>0; i--) print line[i] }' "$1"
}

if [ -s "$STATE" ]; then
  reverse_file "$STATE" | while IFS= read -r target; do
    if [ -n "$target" ]; then
      umount "$target" 2>/dev/null || umount -l "$target" 2>/dev/null
    fi
  done
fi

if [ -s "$SNAPSTATE" ]; then
  reverse_file "$SNAPSTATE" | while IFS='|' read -r target snapdir; do
    if [ -n "$snapdir" ]; then
      umount "$snapdir" 2>/dev/null || umount -l "$snapdir" 2>/dev/null
    fi
  done
fi

umount "$EXT4" 2>/dev/null || umount -l "$EXT4" 2>/dev/null
rm -f "$STATE" "$SNAPSTATE"
rmdir /dev/cler1818_full_overlayfs/lock 2>/dev/null
