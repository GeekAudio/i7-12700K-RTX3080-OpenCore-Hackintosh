#!/bin/bash
# check-rebar-state.sh —— 开机后检查 BAR1 / ReBAR 到底落在哪
#
# 用途：每次改完 BIOS 或 OpenCore 的 GPU BAR 设置重启后，先跑这个，
#       不用翻日志就知道 BAR1 实际是 256 MB / 4 GB / 8 GB / 16 GB。
#
# 背景（2026-10-09 查明）：
#   - 本机 RTX 3080 的**当前生效 VBIOS** 只声明 64/128/256 MB
#     （驱动日志：`sizes supported mask 0x1c0`）→ 光开 BIOS 的 ReBAR 没用。
#   - 刷了 ReBAR 版 VBIOS 后，固件会按 VBIOS 声明的最大值给 BAR1（常见 16 GB）。
#   - 驱动只在 BAR1 < 4 GB 时才会自己 resize，且**上限压到 8 GB**：
#       kexts/NVRM/NVRM.cpp: `for (int k = 13; k >= 12; k--)`  → 8 GB / 4 GB
#     作者原话：BAR1 放到 16 GB 会在 bring-up（GSP boot / NVAccel start）停住。
#   - 所以目标是让 BAR1 落在 **8 GB**。
#
# 只读，不需要 root。

set -u
echo "=============================================="
echo " BAR1 / ReBAR 状态自检"
echo "=============================================="

echo
echo "--- 1) 驱动看到的 BAR（base + size）---"
BARS=$(ioreg -r -n NVRM -d 1 -l -w0 2>/dev/null | grep -oE '"nvrm-bars" = "[^"]*"')
echo "  $BARS"
python3 - <<'PY'
import re, subprocess
raw = subprocess.run(['ioreg','-r','-n','NVRM','-d','1','-l','-w0'],
                     capture_output=True, text=True).stdout
m = re.search(r'"nvrm-bars" = "([^"]*)"', raw)
if not m:
    print("  （拿不到 nvrm-bars）"); raise SystemExit
for tok in m.group(1).split():
    mm = re.match(r'(bar\d)@0x[0-9a-f]+:(0x[0-9a-f]+)\+0x([0-9a-f]+)', tok)
    if not mm: continue
    size = int(mm.group(3), 16)
    name = mm.group(1)
    human = ("%d MB" % (size >> 20)) if size < (1 << 30) else ("%d GB" % (size >> 30))
    tag = ""
    if name == 'bar1':
        if size < (4 << 30): tag = "  ← 太小，ReBAR 没生效（VBIOS 不支持或 BIOS 没开）"
        elif size == (8 << 30): tag = "  ← ✅ 8 GB，作者验证过能跑的尺寸"
        elif size > (8 << 30): tag = "  ← ⚠️ 大于 8 GB（16 GB 会在 bring-up 停住！）"
        else: tag = "  ← 4 GB，可用但不是最优"
    print("  %s = %s (0x%x)%s" % (name, human, size, tag))
PY

echo
echo "--- 2) BAR1 预算与用量（驱动侧）---"
python3 - <<'PY'
import subprocess
def g(k):
    try: return int(subprocess.check_output(['sysctl','-n','debug.'+k], stderr=subprocess.DEVNULL))
    except Exception: return None
b = g('nvrmfb_vram_budget_bytes'); m = g('nvrmfb_vram_mapped_bytes')
if b: print("  预算 budget = %.0f MB" % (b/1048576))
if m is not None: print("  已用 mapped = %.0f MB (%.1f%%)" % (m/1048576, 100.0*m/b if b else 0))
for k in ('nvrmfb_agdc','nvrmfb_agdc_refused','nvaccel_iop_flip'):
    v = g(k)
    if v is not None: print("  %-24s = %s" % (k, v))
PY

echo
echo "--- 3) 驱动是否正常 arm 了显示 ---"
ioreg -r -n NVRM -d 1 -l -w0 2>/dev/null \
  | grep -oE '"(nvrm-display|nvrm-boot-hold|nvrm-autogo|nvrm-autogo-settle-ms|nvrm-boot-raster)" = [^,}]*' \
  | sed 's/^/  /'

echo
echo "--- 4) 显示器与帧缓冲 ---"
system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Resolution|UI Looks like|Main Display|Online|Chipset Model" | sed 's/^/  /'
echo -n "  IOFramebuffer 数量: "
ioreg -c IOFramebuffer -r -w0 2>/dev/null | grep -c "^+-o"

echo
echo "--- 5) AGDC 里的 GPU 列表（应该只有 NVIDIA 一个）---"
/System/Library/Extensions/IOGraphicsFamily.kext/iogdiagnose 2>/dev/null \
  | sed -n '/GPUWrangler/,/End: GPUWrangler/p' | grep -E "^gpu " | sed 's/^/  /'

echo
echo "--- 6) 本次开机到桌面花了多久 ---"
python3 - <<'PY'
import re, datetime, subprocess
out = subprocess.check_output(['sysctl','-n','kern.boottime'], text=True)
sec = int(re.search(r'sec = (\d+)', out).group(1))
t0 = datetime.datetime.fromtimestamp(sec)
print("  开机: %s" % t0.strftime('%H:%M:%S'))
L = "/var/log/com.apple.xpc.launchd/launchd.log"
pat = re.compile(r"^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})")
want = {'SecurityAgent':'登录界面','WindowManager':'桌面','Finder':'桌面'}
seen = {}
with open(L, encoding="utf-8", errors="replace") as f:
    for line in f:
        m = pat.match(line)
        if not m: continue
        t = datetime.datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S")
        off = int((t - t0).total_seconds())
        if off < 0 or off > 300: continue
        for k, lbl in want.items():
            if k in line and k not in seen and re.search(r"WILL_SPAWN|Successfully spawned|job state = running", line):
                seen[k] = (off, lbl)
for k, (off, lbl) in sorted(seen.items(), key=lambda x: x[1][0]):
    print("  +%3ds  %s（%s）" % (off, k, lbl))
PY
echo
echo "=============================================="
echo " 判读：bar1 那一行是 8 GB 就对了；>8 GB 会卡；<4 GB 说明 ReBAR 没生效。"
echo "=============================================="
