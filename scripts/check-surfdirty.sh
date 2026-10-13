#!/bin/bash
# 查「surface 脏标记被拒绝」的比例 —— 来自 issue #92 的线索
#
# ★ 背景（2026-10-10 从 #92 与源码 `kexts/NVRM/accel/nvrm-accel.cpp:1088-1131` 挖到）
#
#   窗口内容更新的流程：
#     ① App 渲染 → GPU 写进窗口的 IOSurface
#     ② 驱动被请求「把这块 surface 标记为脏」（NVRM_ESC_SURF_DIRTY）
#     ③ 成功的话，`nvAccelSurfDirty()` 会：
#          valid[6] |= (1 << plane)      ← 标记「有效」
#          valid[0] &= ~(1 << plane)     ← 【清掉脏位】
#     ④ WindowServer 才知道「这块内容变了」，去重新读它
#
#   ★ 如果第 ② 步被【拒绝】，脏位没被设置/清除 → WindowServer 不知道内容变了
#     → 它继续用【旧内容】合成 → 屏幕上就是【旧内容】（重影！）
#     → 而且【不会自己好】，直到有东西强制整块重新呈现（点一下窗口）
#
#   拒绝条件（源码 1094 行）：
#       type != 0xc0 || (fl & 0x8000) || !valid || plane > 15
#   以及 1096 行：nvSVPend() 的 pending 表（512 槽）满了
#
#   ★ #92（RTX 2060 SUPER）实测：`dirty 55001, refused 31015` = 【56% 被拒】
#     他的症状：「窗口 raise/lower、鼠标移动时出现黑块」← 和我们一模一样
#
# 日志行（每次开机前 6 次 + 之后每 4096 次打印一次，计数是【累计值】）：
#   NVAccel: surfvram dirty: surface N plane 0 type 0xc0 -> 0x0 (dirty X, refused Y)
#
# 用法：  bash check-surfdirty.sh
# 无需 sudo（读日志）。慢是正常的，它在遍历日志库。

echo "=============================================="
echo " surface 脏标记：成功 / 被拒绝"
echo "=============================================="
echo
echo "抓取中（可能要几十秒）..."
echo

OUT=$(mktemp)
/usr/bin/log show --style compact --predicate 'eventMessage CONTAINS "surfvram dirty"' > "$OUT" 2>/dev/null

N=$(wc -l < "$OUT" | tr -d ' ')
if [ "${N:-0}" -eq 0 ]; then
    echo "  没抓到 surfvram dirty 行。"
    echo "  可能：① 日志已轮转；② 本机还没触发过这条路径"
    rm -f "$OUT"; exit 0
fi

echo "  共抓到 $N 行"
echo
echo "=== 最早 3 行 ==="
head -3 "$OUT" | sed 's/^/  /'
echo
echo "=== ★ 最后 3 行（计数是累计值，最后一行就是总量）==="
tail -3 "$OUT" | sed 's/^/  /'
echo
echo "=== 每次开机批次的累计值（用 python 解析，macOS 的 awk 不支持 3 参数 match）==="
python3 - "$OUT" <<'PYEOF'
import sys, re
seen=[]
for line in open(sys.argv[1], encoding='utf-8', errors='replace'):
    m = re.search(r'^([0-9-]+ [0-9:]+).*\(dirty (\d+), refused (\d+)\)', line)
    if m:
        seen.append((m.group(1), int(m.group(2)), int(m.group(3))))
if seen:
    # 按天分组，每天取最后一个（累计值）
    byday={}
    for ts,d,r in seen:
        byday[ts[:10]] = (ts, d, r)
    for day in sorted(byday):
        ts,d,r = byday[day]
        tot = d+r
        print("  %s  最后一条 %s  dirty=%-8d refused=%-6d 拒绝率=%.2f%%" % (day, ts[11:], d, r, 100.0*r/tot if tot else 0))
PYEOF
echo
echo
echo "=== 判读 ==="
LAST=$(tail -1 "$OUT")
D=$(echo "$LAST" | sed -n 's/.*(dirty \([0-9]*\), refused \([0-9]*\)).*/\1/p')
R=$(echo "$LAST" | sed -n 's/.*(dirty \([0-9]*\), refused \([0-9]*\)).*/\2/p')
if [ -n "${D:-}" ] && [ -n "${R:-}" ]; then
    TOT=$((D+R))
    if [ "$TOT" -gt 0 ]; then
        PCT=$(( R * 100 / TOT ))
        printf "  本机累计：dirty=%s  refused=%s  → 【拒绝率 %d%%】\n" "$D" "$R" "$PCT"
        echo
        if [ "$PCT" -ge 20 ]; then
            echo "  ★★★ 拒绝率很高！这很可能就是【重影/黑块】的根因："
            echo "      窗口内容变了，但脏标记被拒 → WindowServer 不知道 → 继续用旧内容合成。"
        elif [ "$PCT" -gt 0 ]; then
            echo "  拒绝率不高但非 0 —— 每一次拒绝都可能对应一次可见的重影。"
        else
            echo "  拒绝率为 0 → 这条路不是本机的原因（要换方向）。"
        fi
    fi
fi
echo
echo "原始行已保存：$OUT"
rm -f "$OUT"
