#!/bin/bash
# capture-ghost-pack.sh —— 重影取证包：现象出现时跑一次，把「那一刻」的全部证据收进一个目录。
#
# 为什么需要它：重影一旦被触碰就消失，而且 /Library/NullMoth/display-trace/kernel.txt 是
# 跨启动的滚动日志（8MB 上限）。必须【按启动分段】读，且要抓「现象仍在屏幕上」的那一刻。
#
# 用法：  bash capture-ghost-pack.sh
#         现象出现时（不要点任何东西）在终端里跑它，约 3 秒完成。
#         OUTDIR=~/Desktop bash capture-ghost-pack.sh     # 指定输出目录
#
# 产出：  <输出目录>/重影取证-<时间戳>/
#           screen-full.png        整屏（原尺寸）
#           screen-crop-*.png      左/中/右三段裁切（放大后小字叠影才看得见）
#           window-<id>.png        每个可见窗口单独抓（-l，判断伪影是否在窗口内容里）
#           trace-window.txt       最近 ~120 秒的逐秒计数器
#           kernel-window.txt      最近 ~120 秒的内核消息
#           ws-window.txt          最近 ~120 秒的 WindowServer 消息
#           counters.txt           全部相关 sysctl
#           surfvram-perboot.txt   按启动分段的 dirty/refused 统计（★ 关键，避免跨启动误读）
#           state.txt              版本 / sha256 / boottime / launchctl / 配置
#           surfvram-lines.txt     全部 surfvram 原始行（按启动标注）
#
# 依赖：screencapture / sips / sysctl / ioreg（macOS 自带）、python3（系统自带即可）。
#       窗口级抓取需要 PyObjC（可选）；没有时会跳过该步并明确提示，其余证据照常收集。
set -u

OUT="${OUTDIR:-$PWD}/重影取证-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT" || exit 1
DT=/Library/NullMoth/display-trace
PY=$(command -v python3 2>/dev/null || echo /usr/bin/python3)

# 找一个能 import Quartz（PyObjC）的 python3；找不到就返回非 0。
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

echo "== 收集到 $OUT"

# --- 1. 屏幕：整屏 + 分段裁切（缩图看不出小字叠影，必须原尺寸裁切） ---
screencapture -x "$OUT/screen-full.png" 2>/dev/null
W=$(sips -g pixelWidth "$OUT/screen-full.png" 2>/dev/null | awk '/pixelWidth/{print $2}')
[ -z "${W:-}" ] && W=1920
H=$(sips -g pixelHeight "$OUT/screen-full.png" 2>/dev/null | awk '/pixelHeight/{print $2}')
[ -z "${H:-}" ] && H=1080
seg=$((W / 3))
for i in 0 1 2; do
  screencapture -x -R $((i * seg)),0,$seg,$H "$OUT/screen-crop-$((i + 1)).png" 2>/dev/null
done

# --- 2. 每个可见窗口单独抓一张（判断伪影在窗口内容里还是在合成之后） ---
if [ -n "$VENVPY" ]; then
  "$VENVPY" - <<'PYEOF' > "$OUT/windows.txt" 2>&1
import Quartz
wl = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
    Quartz.kCGNullWindowID)
for w in wl:
    n = w.get('kCGWindowOwnerName', '')
    b = w.get('kCGWindowBounds', {})
    if b.get('Width', 0) < 200 or b.get('Height', 0) < 150:
        continue
    print('%s|%s|%s|%sx%s+%s+%s' % (w.get('kCGWindowNumber'), n, w.get('kCGWindowName', ''),
                                    int(b.get('Width', 0)), int(b.get('Height', 0)),
                                    int(b.get('X', 0)), int(b.get('Y', 0))))
PYEOF
  while IFS='|' read -r wid owner name geom; do
    [ -z "${wid:-}" ] && continue
    safe=$(echo "$owner-$name" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-40)
    screencapture -l "$wid" -x -o "$OUT/window-${wid}-${safe}.png" 2>/dev/null
  done < "$OUT/windows.txt"
else
  echo "（未找到带 PyObjC 的 python3 —— 跳过窗口级抓取；整屏与裁切图已足够看重影）" \
    > "$OUT/windows.txt"
  echo "  想要窗口级抓取：python3 -m pip install --user pyobjc-framework-Quartz"
fi

# --- 3. trace 的三个文件：各取最近 ~120 秒 ---
for f in trace.txt kernel.txt ws.txt; do
  [ -f "$DT/$f" ] && tail -n 400 "$DT/$f" > "$OUT/${f%.txt}-window.txt"
done

# --- 4. 计数器 ---
{
  echo "== $(date '+%F %T')"
  echo "== nvaccel / nvrmfb"
  sysctl debug 2>/dev/null | grep -E '^debug\.(nvaccel|nvrmfb)' | grep -v -E 'nvaccel_vm_|nvaccel_res_|nvaccel_map_'
  echo
  echo "== 显示模式"
  system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Resolution|UI Looks|Refresh|Display Type|Online"
  echo
  echo "== ioreg NVRMNVDAFramebuffer 关键属性"
  ioreg -r -c NVRMNVDAFramebuffer -w0 2>/dev/null | grep -oaE '"(IOFBCurrentPixelClock|IOFBCurrentPixelCount|IOFBDependentIndex|NVRMTrace|NVRMTraceCount|reflips|fVblCalls)" = [^,}]{0,80}'
} > "$OUT/counters.txt" 2>&1

# --- 5. ★ 按启动分段统计 surfvram（跨启动误读是 10-12 犯过的错） ---
if [ -f "$DT/kernel.txt" ]; then
  grep -a "surfvram" "$DT/kernel.txt" > "$OUT/surfvram-lines.txt" 2>/dev/null
  "$PY" - "$DT/kernel.txt" > "$OUT/surfvram-perboot.txt" 2>&1 <<'PYEOF'
import re, sys
rows = []
for line in open(sys.argv[1], encoding='utf-8', errors='replace'):
    if 'surfvram dirty' not in line:
        continue
    m = re.search(r'(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})', line)
    d = re.search(r'dirty (\d+), refused (\d+)', line)
    s = re.search(r'-> 0x([0-9a-f]+)', line)
    if m and d:
        rows.append((m.group(1) + ' ' + m.group(2), int(d.group(1)), int(d.group(2)), s.group(1) if s else '?'))
rows.sort()
# 先按「dirty 回落」切分成每次启动，再统计
boots = []
cur = None
for t, d, r, s in rows:
    if cur is None or d < cur['maxd']:
        cur = {'a': t, 'b': t, 'maxd': 0, 'maxr': 0, 'st': set(), 'n': 0}
        boots.append(cur)
    cur['b'] = t
    cur['maxd'] = max(cur['maxd'], d)
    cur['maxr'] = max(cur['maxr'], r)
    cur['st'].add(s)
    cur['n'] += 1
print('%-21s %-21s %10s %10s %8s  %s' % ('boot 首行', 'boot 末行', 'max dirty', 'max refused', '拒绝率', '状态码'))
print('-' * 96)
for b in boots:
    rate = 100.0 * b['maxr'] / b['maxd'] if b['maxd'] else 0.0
    tag = '  ← 本次启动' if b is boots[-1] else ''
    print('%-21s %-21s %10d %10d %7.2f%%  %s%s' % (b['a'], b['b'], b['maxd'], b['maxr'], rate,
                                                   ','.join(sorted(b['st'])), tag))
PYEOF
fi

# --- 6. 状态 ---
{
  echo "== 时间: $(date '+%F %T')"
  echo "== 驱动版本: $(cat /Library/NullMoth/driver-version 2>/dev/null)"
  echo "== boottime: $(sysctl -n kern.boottime)"
  echo "== boot-args: $(nvram boot-args 2>/dev/null | cut -f2-)"
  echo "== 插件 sha256: $(shasum -a 256 /Library/GPUBundles/NVMTLDriver.bundle/Contents/MacOS/NVMTLDriver 2>/dev/null | cut -d' ' -f1)"
  echo "== NVK sha256: $(shasum -a 256 /Library/GPUBundles/nvmtl/libvulkan_nouveau.dylib 2>/dev/null | cut -d' ' -f1)"
  echo "== tracker: $(launchctl print system/com.nullmoth.displaytrace 2>&1 | grep -E 'state =|runs =|pid =' | tr -s ' ' | tr '\n' ' ')"
  echo "== WindowServer pid: $(pgrep -x WindowServer | head -1)"
  echo "== 加载的 nullmoth kext: $(kmutil showloaded --list-only 2>/dev/null | grep -ci nullmoth)"
  echo "== 加载明细:"
  kmutil showloaded --list-only 2>/dev/null | grep -i nullmoth
} > "$OUT/state.txt" 2>&1

echo
echo "== 完成，共 $(ls -1 "$OUT" | wc -l | tr -d ' ') 个文件："
ls -la "$OUT"
echo
echo "★ 关键看两个："
echo "   surfvram-perboot.txt  —— 按启动分段（最后一行 = 本次启动）"
echo "   window-*.png / screen-crop-*.png —— 伪影是否在窗口内容里"
