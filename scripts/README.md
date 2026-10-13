# scripts —— 一键自检 / 取证脚本

这些脚本配套 [ReBAR 完全指南（小白速查）](https://github.com/GeekAudio/i7-12700K-RTX3080-OpenCore-Hackintosh)，
用来在这台机器（ASUS Z690 + i7-12700K + RTX 3080 + NullMoth 驱动）上**验证 BAR1 / ReBAR 状态**、
**采集重影/黑窗证据**、**切换输出路径做 A/B**。

- 全部是**只读或可逆**操作，**不需要装任何东西**（除了 macOS 自带的 `bash`/`python3`/`screencapture`）。
- **不依赖本仓库的 EFI**：任何一台装了 NullMoth 驱动的机器都能直接跑。
- 脚本里**没有写死任何用户名或路径**；输出目录默认取当前工作目录，可用 `OUTDIR=` 覆盖。

## 直接运行（不用 clone）

```bash
# 例：BAR1 / ReBAR 状态自检
curl -fsSL https://raw.githubusercontent.com/GeekAudio/i7-12700K-RTX3080-OpenCore-Hackintosh/main/scripts/check-rebar-state.sh | bash
```

> 用 `curl | bash` 时脚本的工作目录是你的当前目录，输出会落在当前目录下。

## 或者先下载再跑（推荐，方便看清内容）

```bash
git clone https://github.com/GeekAudio/i7-12700K-RTX3080-OpenCore-Hackintosh.git
cd i7-12700K-RTX3080-OpenCore-Hackintosh/scripts
chmod +x *.sh
bash check-rebar-state.sh
```

---

## 脚本清单

| 脚本 | 干什么 | 需要 root？ | 依赖 |
|---|---|---|---|
| **`check-rebar-state.sh`** | ★ **开机后先跑这个**：打印 BAR1 实际大小、预算、用量、显示 arm 状态、AGDC GPU 列表、开机耗时 | 否 | 无 |
| `verify-iop-flip-ab.sh` | 在**拷贝路径**（`iop_flip=0`）与**零拷贝**（`1`）之间来回切，判定重影/黑块是不是驱动输出路径问题 | 是（弹一次密码框） | 无 |
| `check-surfdirty.sh` | 统计 WindowServer **surface 脏标记被拒绝**的比例（对应 issue #92） | 否 | 无 |
| `capture-ghost-pack.sh` | 重影**现象出现时**跑一次，把那一刻的整屏/窗口截图 + 驱动计数器 + 按启动分段的 surfvram 统计收进一个目录 | 否 | `screencapture`；窗口级抓取需 PyObjC（可选） |
| `watch-ghost.sh` | 重影**自动连拍**：每 N 秒抓一张，你只管复现，事后按时间点回看 | 否 | 同上 |
| `cpu-freq-probe.sh` | 实测 CPU 真实核心频率（用 `mulsd` 4 周期依赖链 + 内联汇编，防止编译器折叠） | 否 | `clang`（Xcode 命令行工具） |

### 典型用法

```bash
# 1) 改完 BIOS / EFI 重启后，先看 BAR1 落在哪
bash check-rebar-state.sh

# 2) 重影出现了（别碰鼠标）
bash capture-ghost-pack.sh
#    或让它自己蹲守 30 分钟
bash watch-ghost.sh 30 5

# 3) 判定是不是驱动的输出路径问题（可逆，不用重启）
bash verify-iop-flip-ab.sh      # 看当前值
bash verify-iop-flip-ab.sh 0    # 切拷贝路径
bash verify-iop-flip-ab.sh 1    # 切回零拷贝

# 4) 看脏标记拒绝率
bash check-surfdirty.sh

# 5) 看 CPU 有没有被限频（本机曾卡在 2.3 GHz）
bash cpu-freq-probe.sh
```

### 输出目录

- `capture-ghost-pack.sh` / `watch-ghost.sh` 默认把结果写到 **当前目录** 下的 `重影取证-<时间戳>/` / `连拍-<时间戳>/`。
- 想换地方：`OUTDIR=~/Desktop bash capture-ghost-pack.sh`
- 想让窗口级抓取用指定的 python：`PYOBJC_PY=/path/to/python3 bash capture-ghost-pack.sh`

---

## 判读口诀（BAR1）

| `bar1` 显示 | 含义 |
|---|---|
| **8 GB** | ✅ 作者验证过的尺寸，正确 |
| 4 GB | 可用，但不是最优 |
| **> 8 GB**（如 16 GB） | ⚠️ 会在显卡 bring-up 阶段卡住 |
| 256 MB / 64 MB | ReBAR 没生效（VBIOS 不支持，或 BIOS 没开 Above 4G / ReBAR） |

> 详细原理、四档配置对比、以及「重影/黑窗」与 BAR1 大小的关系，见 ReBAR 完全指南。
