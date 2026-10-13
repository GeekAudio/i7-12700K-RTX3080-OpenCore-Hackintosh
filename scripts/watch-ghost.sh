#!/bin/bash
# watch-ghost.sh —— 重影自动连拍守护：你只管复现，抓取交给它。
#
# 为什么需要它：重影「任何交互就清掉」，但**未被触碰时会一直留在屏幕上**。
# 所以每 N 秒抓一次，就一定能抓到；事后按时间点回看即可，不用掐时机按脚本。
#
# 用法：
#   bash watch-ghost.sh              # 连拍 30 分钟，每 5 秒一张（默认）
#   bash watch-ghost.sh 60           # 连拍 60 分钟
#   bash watch-ghost.sh 30 2         # 30 分钟，每 2 秒一张
#   OUTDIR=~/Desktop bash watch-ghost.sh    # 指定输出目录
#   Ctrl-C 随时停
#
# 产出： <输出目录>/连拍-<时间戳>/
#          frames/<序号>-<时刻>.png   每张系统设置窗口（若不在则抓全屏左三分之一）
#          index.txt                  序号 / 时刻 / 窗口号 / 尺寸
#          reference.png              第一张（= 已知干净参照，用来看是否变化）
#
# 判读：拿 frames/ 里任意一张和 reference.png 并排看（都按原尺寸），
#       或者直接把可疑的几张发给助手做像素差。
#
# 依赖：screencapture / sips（macOS 自带）。窗口号定位需要 PyObjC（可选）——
#       没有 PyObjC 时会退化为「抓全屏左三分之一」，脚本仍可正常跑完。
set -u

MIN=${1:-30}
STEP=${2:-5}
OUT="${OUTDIR:-$PWD}/连拍-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT/frames" || exit 1

# 找一个能 import Quartz（PyObjC）的 python3；找不到就返回非 0，跳过窗口级定位。
find_pyobjc() {
  for c in ${PYOBJC_PY:-} python3 /usr/bin/python3 \
           /opt/homebrew/bin/python3 /usr/local/bin/python3 \
           "$HOME/.workbuddy-ai/binaries/python/envs/default/bin/python3" \
           ./.venv/bin/python3 "$HOME/.venv/bin/python3"; do
    [ -n "$c" ] || continue
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import Quartz' >/dev/null 2>&1; then
      printf '%s\n' "$c"; return 0
    fi
  done
  return 1
}
VENVPY=$(find_pyobjc || true)

echo "== 输出目录 $OUT"
echo "== 每 ${STEP}s 一张，共 ${MIN} 分钟。Ctrl-C 停止。"
if [ -n "$VENVPY" ]; then
  echo "== PyObjC: $VENVPY（可按窗口号精准抓「系统设置」窗口）"
else
  echo "== 未找到带 PyObjC 的 python3 —— 退化为抓全屏左三分之一（不影响判断重影）"
  echo "   想要窗口级抓取：python3 -m pip install --user pyobjc-framework-Quartz"
fi

N=0
END=$(( $(date +%s) + MIN * 60 ))
: > "$OUT/index.txt"
printf "%-6s %-21s %-8s %s\n" "序号" "时刻" "窗口号" "尺寸" >> "$OUT/index.txt"

while [ "$(date +%s)" -lt "$END" ]; do
  N=$((N + 1))
  STAMP=$(date '+%Y%m%d-%H%M%S')
  WID=""
  # 每次重新解析系统设置窗口号（窗口号会变）
  if [ -n "$VENVPY" ]; then
    WID=$("$VENVPY" - <<'PYEOF' 2>/dev/null
import Quartz
wl = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
    Quartz.kCGNullWindowID)
for w in wl:
    n = w.get('kCGWindowOwnerName', '')
    b = w.get('kCGWindowBounds', {})
    if ('Settings' in n or '设置' in n) and b.get('Width', 0) > 400:
        print(w.get('kCGWindowNumber'))
        break
PYEOF
)
  fi
  F=$(printf "%s/frames/%04d-%s.png" "$OUT" "$N" "$STAMP")
  if [ -n "${WID:-}" ]; then
    screencapture -l "$WID" -x -o "$F" 2>/dev/null
    GEOM=$(sips -g pixelWidth -g pixelHeight "$F" 2>/dev/null | awk '/pixel/{printf "%s ", $2}')
    printf "%-6d %-21s %-8s %s\n" "$N" "$STAMP" "$WID" "$GEOM" >> "$OUT/index.txt"
  else
    # 系统设置不在屏幕上 —— 抓左三分之一，覆盖面更广
    screencapture -x -R 0,0,640,1040 "$F" 2>/dev/null
    printf "%-6d %-21s %-8s %s\n" "$N" "$STAMP" "(无)" "左1/3" >> "$OUT/index.txt"
  fi
  [ "$N" = 1 ] && cp "$F" "$OUT/reference.png" 2>/dev/null
  sleep "$STEP"
done

echo
echo "== 完成，共 $N 张"
echo "== 参照图：$OUT/reference.png"
echo "== 索引：$OUT/index.txt"
echo
echo "★ 复现之后，把「症状还在屏幕上」的那几张（看 index.txt 的时刻）告诉我，我做像素差。"
