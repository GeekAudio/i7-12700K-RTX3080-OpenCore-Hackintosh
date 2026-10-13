#!/bin/bash
# verify-iop-flip-ab.sh —— 判定「重影/黑块」是驱动内部路径问题还是用户设置问题
#
# 原理：debug.nvaccel_iop_flip 是**运行时开关**，可来回切，不用重启。
#   0 = 拷贝路径（屏幕读一份完整拷贝）—— 等效 -nvrmnoflip
#   1 = 零拷贝（屏幕直接读 GPU 正在画的缓冲）—— 可能读到「画了一半」的帧
#
# 用法（需要 root，会弹一次密码框）：
#   bash verify-iop-flip-ab.sh 0      # 切到拷贝路径
#   bash verify-iop-flip-ab.sh 1      # 切到零拷贝
#   bash verify-iop-flip-ab.sh        # 只看当前状态
#
# 判读：若只切这一个开关就能让黑块出现/消失，则与用户的任何设置无关，
#       是驱动的输出路径选择问题。

set -u
WANT="${1:-}"
K=debug.nvaccel_iop_flip

show() {
  echo "----------------------------------------------"
  echo "  $K = $(sysctl -n $K 2>/dev/null)   $( [ "$(sysctl -n $K 2>/dev/null)" = 0 ] && echo '（拷贝路径 / 等效 -nvrmnoflip）' || echo '（零拷贝）' )"
  echo -n "  刷新率: "
  CLK=$(ioreg -r -n NVRMFramebuffer -d 1 -l -w0 2>/dev/null | grep -oE '"IOFBCurrentPixelClock" = [0-9]+' | grep -oE '[0-9]+')
  CNT=$(ioreg -r -n NVRMFramebuffer -d 1 -l -w0 2>/dev/null | grep -oE '"IOFBCurrentPixelCount" = [0-9]+' | grep -oE '[0-9]+')
  [ -n "$CLK" ] && [ -n "$CNT" ] && [ "$CNT" != 0 ] && awk -v c="$CLK" -v n="$CNT" 'BEGIN{printf "%.2f Hz\n", c/n}'
  echo "  iop_flips=$(sysctl -n debug.nvaccel_iop_flips 2>/dev/null)  flip_hit=$(sysctl -n debug.nvaccel_iop_flip_hit 2>/dev/null)  flip_miss=$(sysctl -n debug.nvaccel_iop_flip_miss 2>/dev/null)  fail=$(sysctl -n debug.nvaccel_iop_fail 2>/dev/null)"
  echo "----------------------------------------------"
}

if [ -z "$WANT" ]; then show; echo; echo "用法: bash \"$0\" 0|1   （0=拷贝路径 1=零拷贝）"; exit 0; fi
case "$WANT" in 0|1) ;; *) echo "参数只能是 0 或 1"; exit 1;; esac

echo "切换前："; show
echo "设置 $K = $WANT ..."
osascript -e "do shell script \"sysctl -w $K=$WANT\" with administrator privileges" >/dev/null 2>&1
sleep 1
echo "切换后："; show
echo
echo "★ 现在去看屏幕：打开「系统设置」，看左侧边栏文字是否变成黑块。"
echo "  等 10–20 秒再判断（窗口需要重绘）。"
echo "  想复原就再跑一次相反的参数。"
