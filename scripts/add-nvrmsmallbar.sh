#!/bin/bash
# 给 OpenCore boot-args 加上 -nvrmsmallbar（或撤销）。
#
# 作用：让 NVRM::placeLargeBar1() 在函数开头直接 return false
#   ⇒ 驱动不做 BAR1 的「放大到 4–8GB」与「重定位到宿主桥 64 位窗口」
#   ⇒ BAR1 留在 IOPCIFamily 放的位置（小 BAR 体制，若固件本来就放得小）
# 用途：诊断/对照（作者注释原文 "for testing and diagnosis"），**不是修复**。
#
# 用法：
#   sudo bash add-nvrmsmallbar.sh            # 加上
#   sudo bash add-nvrmsmallbar.sh --revert   # 撤销
#   bash add-nvrmsmallbar.sh --check         # 只看当前状态（不需要 root）
#
# 改完必须重启才生效。重启后判据：
#   sysctl debug.nvrmfb_vram_budget_bytes
#     掉到 ~201326592（192 MB） ⇒ 真的进了小 BAR 体制
#     仍是 4294967296（4096 MB）⇒ 尺寸由固件/OpenCore 决定，本开关只管重定位
set -u
FLAG="-nvrmsmallbar"
MODE="${1:-apply}"

find_efi() {
  diskutil list 2>/dev/null | awk '/ EFI /{print $NF; exit}'
}

read_ba() {
  /usr/libexec/PlistBuddy -c "Print :NVRAM:Add:7C436110-AB2A-4BBB-A880-FE41995C9F82:boot-args" "$1" 2>/dev/null
}

EFI=$(find_efi)
[ -z "$EFI" ] && { echo "找不到 EFI 分区"; exit 1; }

if [ "$MODE" = "--check" ]; then
  echo "EFI 分区：$EFI"
  if ! mount | grep -q "/Volumes/EFI"; then
    echo "（EFI 未挂载；用 sudo 跑一次以查看内容）"
    exit 0
  fi
  BA=$(read_ba /Volumes/EFI/EFI/OC/config.plist)
  echo "boot-args: $BA"
  echo "$BA" | tr ' ' '\n' | grep -qx -- "$FLAG" && echo "状态：$FLAG 已存在" || echo "状态：$FLAG 不存在"
  echo "nvram:     $(nvram boot-args 2>/dev/null | sed 's/^boot-args[[:space:]]*//')"
  echo "budget:    $(sysctl -n debug.nvrmfb_vram_budget_bytes 2>/dev/null)"
  exit 0
fi

echo "== EFI 分区：$EFI"
osascript -e "do shell script \"diskutil mount $EFI\" with administrator privileges" >/dev/null 2>&1
sleep 1
C=/Volumes/EFI/EFI/OC/config.plist
[ -f "$C" ] || { echo "挂载后找不到 $C"; exit 1; }

BA=$(read_ba "$C")
[ -z "$BA" ] && { echo "读不到 boot-args"; exit 1; }
echo "== 当前 boot-args："
echo "   $BA"

case "$MODE" in
  apply)
    if echo "$BA" | tr ' ' '\n' | grep -qx -- "$FLAG"; then
      echo "== $FLAG 已存在，无需改动"
    else
      BAK="$C.bak-before-nvrmsmallbar-$(date +%Y%m%d-%H%M%S)"
      cp "$C" "$BAK" && echo "== 已备份：$BAK"
      NEW="$BA $FLAG"
      /usr/libexec/PlistBuddy -c "Set :NVRAM:Add:7C436110-AB2A-4BBB-A880-FE41995C9F82:boot-args $NEW" "$C" || exit 1
      echo "== 已写入"
    fi
    ;;
  --revert)
    if ! echo "$BA" | tr ' ' '\n' | grep -qx -- "$FLAG"; then
      echo "== $FLAG 不存在，无需改动"
    else
      BAK="$C.bak-before-nvrmsmallbar-revert-$(date +%Y%m%d-%H%M%S)"
      cp "$C" "$BAK" && echo "== 已备份：$BAK"
      NEW=$(echo "$BA" | tr ' ' '\n' | grep -vx -- "$FLAG" | tr '\n' ' ' | sed 's/ *$//')
      /usr/libexec/PlistBuddy -c "Set :NVRAM:Add:7C436110-AB2A-4BBB-A880-FE41995C9F82:boot-args $NEW" "$C" || exit 1
      echo "== 已移除"
    fi
    ;;
  *) echo "未知参数：$MODE（用 --revert 或 --check）"; exit 1;;
esac

echo "== 校验"
plutil -lint "$C"
BA2=$(read_ba "$C"); echo "   读回：$BA2"

# 说明：EFI config 是权威来源 —— OpenCore 每次开机都会把 NVRAM/Add 的 boot-args 写进 NVRAM
# （10-13 17:56 核对：EFI config 与当时的 nvram 值逐字符相同）。
# macOS 26 (Tahoe) 起 `nvram boot-args=...` 从系统内写入会被拒（"(iokit/common) general error"），
# 所以这里只尝试、失败不算错。
if ! osascript -e "do shell script \"nvram boot-args='$BA2'\"" >/dev/null 2>&1; then
  echo "   （提示：本系统不允许从 macOS 内写 boot-args —— 正常，重启后由 OpenCore 写入）"
fi
echo "   nvram（当前 boot，重启前不会变）：$(nvram boot-args | sed 's/^boot-args[[:space:]]*//')"

# 卸载 → 重挂 → 再读（持久化验证）
sync
osascript -e 'do shell script "diskutil unmount /Volumes/EFI" with administrator privileges' >/dev/null 2>&1
sleep 1
osascript -e "do shell script \"diskutil mount $EFI\" with administrator privileges" >/dev/null 2>&1
sleep 1
echo "== 重挂后读回：$(read_ba "$C")"
sync
osascript -e 'do shell script "diskutil unmount /Volumes/EFI" with administrator privileges' >/dev/null 2>&1
echo "== EFI 已卸载。**重启后生效。**"
echo "== 重启后判据： sysctl debug.nvrmfb_vram_budget_bytes"
