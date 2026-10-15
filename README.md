# ASUS TUF GAMING Z690-PLUS WIFI D4 + i7-12700K + RTX 3080 — OpenCore EFI

一台 Alder Lake + NVIDIA RTX 3080 黑苹果的 OpenCore EFI 备份，SMBIOS 为 **iMac20,1**，系统 **macOS 26.7.1 (25G241 / Darwin 25.6.0)**。
显卡由 **NullMoth NVIDIA 驱动 2.0.x** 驱动（Turing 及以后），核显无驱动、已屏蔽；无线改用 **Broadcom BCM943602CDP**。

> ⚠️ **发布前已做两件事：脱敏 + 移除机器特有内容**
>
> **① 脱敏**：`SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` 以及蓝牙控制器地址
> 已替换为**明显的占位值**（全 `X` / 全 `0`，见下表）。
>
> **② 移除**：下面两段**已整段删除**（它们只影响「系统报告」里的外观，且会带出本机硬件信息）：
> - `DeviceProperties → Add` —— PCI 槽位名注入（含本机独有设备：UA UAD-2 DUO 等）
> - `PlatformInfo → Memory` —— 内存条视图注入（含内存条序列号 / 型号），`CustomMemory` 已改回 `false`
>
> 使用前请用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 生成属于你自己的 **iMac20,1** 三码，
> 否则 iMessage / FaceTime / iCloud 无法激活，也可能与他人冲突。
>
> | 字段 | 本仓库占位值 |
> |---|---|
> | `SystemSerialNumber` | `XXXXXXXXXXXX` |
> | `MLB` | `XXXXXXXXXXXXXXXXXX` |
> | `SystemUUID` | `00000000-0000-0000-0000-000000000000` |
> | `ROM` | `000000000000`（6 字节 0） |
> | `bluetoothInternalControllerInfo` | 全 `0` |

> 🛠 **自检 / 取证脚本在 [`scripts/`](scripts/)** —— 一条 `curl` 就能跑，不用 clone：
> ```bash
> curl -fsSL https://raw.githubusercontent.com/GeekAudio/i7-12700K-RTX3080-OpenCore-Hackintosh/main/scripts/check-rebar-state.sh | bash
> ```
> 详见 [scripts/README.md](scripts/README.md)。

> ⚠️ **本 EFI 是「驱动装好之后」的运行配置，不是装机配置。**
> 它使用大 BAR（`ResizeGpuBars = 13` ⇒ 8 GB）并且排除了 `IONDRVSupport` —— 这两项会让**没有 NVIDIA 驱动**的 macOS 安装器黑屏。
> 全新安装请走下面的 **1401 流程**（1401 会为安装器自动生成小 BAR 的配置）。

---

## 一、硬件配置

| 部件 | 型号 | 驱动 / 说明 |
|---|---|---|
| CPU | Intel Core i7-12700K (Alder Lake, 8P+4E) | `SSDT-PLUG-ADL.aml`（12 代 XCPM 处理器表）；`ProcessorType=3841` |
| 主板 | **ASUS TUF GAMING Z690-PLUS WIFI D4** | BIOS 中 **ReBAR 已开启**、Above 4G Decoding ON、CSM OFF、**Intel Speed Shift Technology = Enabled**（见下方 ⚠️） |
| 内存 | 2 × 16 GB DDR4-3600 Kingston `KHX2666C16/16G`（插在 A2 / B2） | 走真实 SMBIOS，**不做内存注入**（本仓库已把 `PlatformInfo/Memory` 整段移除，见顶部 ⚠️） |
| 显卡 | NVIDIA GeForce RTX 3080 10 GB (`10de:2206`) | **NullMoth NVIDIA 驱动 2.0.x**；BAR1 = 8 GB（`ResizeGpuBars = 13`）。`/Library/NullMoth/driver-version` = `2.0.1`；官方 2.0.1 / 2.0.2 的 release notes 均写 **"No changes to the driver or the Mac app since 2.0.0"** ⇒ **驱动本体 = v2.0.0 = 最新**（2.0.1/2.0.2 只改 1401 for Windows） |
| 核显 | Intel UHD 770 (`8086:4680`) | **无驱动，`-wegnoigpu` 屏蔽** |
| 有线网卡 | Intel I225-V 2.5GbE | `AppleIGC.kext` —— **本机 `Enabled = false`**（刻意的：让无线抢到 `en0`，见 §九） |
| 无线 / 蓝牙 | **Broadcom BCM943602CDP**（Wi-Fi `14e4:43ba` / 蓝牙 BCM20703，USB） | `IO80211FamilyLegacy` + **`AirPortBrcmNIC-Tahoe.kext`** + `BlueToolFixup`（**需 OCLP 根补丁**，见 §九） |
| 存储 | NVMe | `NVMeFix.kext` |
| 显示器 | Redmi 215 NF，1920×1080 @ 60 Hz | 建议 60 Hz；驱动侧已修「被识别成 30.5″ 电视」（**PR #199 已被上游收编进 v2.0.0**） |
| 系统 | **macOS 26.7.1 (25G241)** | OpenCore 1.0.8 RELEASE |

> ⚠️ **BIOS 硬前提：`Intel(R) Speed Shift Technology` 必须是 `Enabled`（`Auto` 也可能等效关闭）。**
> `iMac20,1` 机型 profile 会强制启用 HWP，OpenCore 启动时执行 `wrmsr(MSR IA32_PM_ENABLE=0x770, 1)`；
> 若固件下 HWP 不可用，会在 `X86PlatformShim → xcpm_hwp_enable` 触发 **type 13 general protection panic**。
> 把这一项设为 Enabled 后即通过。**遇到 `X86PlatformShim` / `xcpm_hwp_enable` 相关 panic，第一件事查这里。**
> （本机另用 `CPUFriendDataProvider` 注入**不带 `hwp` 变量**的频率表，绕开 HWP —— 见 §六。）

> **原装 Intel Wi-Fi 6 AX201 已弃用**（Intel 网卡做不了 AirDrop / 接力 / 通用剪贴板 / Apple Watch 解锁 —— 缺 AWDL）。
> 相关的 `itlwm` / `IntelBluetoothFirmware` / `IntelBTPatcher` 三个 kext 已从本 EFI 中**移除**（不再需要）。

> ⚠️ **`AppleIGC.kext` 是刻意禁用的**：内核按**驱动挂载先后**分配 `en0` / `en1`。
> 保留有线驱动会让 I225-V 抢到 `en0`，而 AirDrop / 接力要求 **`en0` 是无线**。
> 本机做法 = `AppleIGC.kext` 设 `Enabled = false` + 删掉 `NetworkInterfaces.plist` 后重启 ⇒ 无线拿到 `en0`。
> **代价：有线网卡不可用**；`Generic → ROM` 也应改成**无线的 MAC**（本机已是）。

---

## 二、相关仓库与驱动引用

| 项目 | 仓库 | 用途 |
|---|---|---|
| **1401** | https://github.com/nullmoth/1401 | **装机主线工具**：在 Windows 上检测硬件、生成 OpenCore 配置、制作 macOS 安装 U 盘 |
| **NullMoth NVIDIA 驱动** | https://github.com/nullmoth/nvidia-macos-driver | RTX 3080 的 Metal / 显示驱动（kexts + NVMTLDriver.bundle） |
| 驱动发布页 | [nvidia-macos-driver Releases](https://github.com/nullmoth/nvidia-macos-driver/releases) | `1401-Mac-<版本>.dmg`、`nullmoth-nvidia-<版本>.tar.gz` |
| **OpenCore Legacy Patcher** | https://github.com/dortania/OpenCore-Legacy-Patcher | Broadcom Wi-Fi 的**系统侧**补丁（§九） |
| OpCore-Simplify | https://github.com/lzhoang2801/OpCore-Simplify | 1401 底层使用的 OpenCore 配置生成引擎 |
| OpenCorePkg | https://github.com/acidanthera/OpenCorePkg | OpenCore 本体 |
| 手搓指南 | https://dortania.github.io/OpenCore-Install-Guide/ | 1401 不适用时的兜底方案 |

### 驱动架构

```
Metal 应用 ─► NVMTLDriver.bundle ─► 翻译器 (Apple AIR → SPIR-V) ─► NVK (Mesa Vulkan + NAK) ─► kexts ─► GPU
```

| 组件 | 落盘路径 | 来源 |
|---|---|---|
| Metal 驱动插件 | `/Library/GPUBundles/NVMTLDriver.bundle` | `plugin/` |
| 着色器翻译器 | 插件内 `libnvmtl_translate.dylib` | `translator/`（LGPL-3.0，基于 metal2vulkan） |
| Vulkan 后端 (NVK) | `/Library/GPUBundles/nvmtl/` | `nvk/nvk-macos.patch`（Mesa `17ca6174`） |
| 内核扩展 | `/Library/Extensions/NVRM, NVAccel, NVRMFB, NVRMAGDC` | `kexts/` |
| GPU 固件 (GSP) | `/Users/Shared/nvfw/nvidia/610.57.04` | NVIDIA 原厂，未修改 |

> **kext 装在 `/Library/Extensions` 并由 Auxiliary Kernel Collection 加载，不要再从 `EFI/OC/Kexts` 注入。**
> OpenCore 这边只需要负责 **SIP 和 boot-args**。

---

## 三、构建流程（主线：1401 U 盘的制作与启动）

1401 是 NullMoth 出的装机工具，把「检测硬件 → 生成 OpenCore → 做安装盘 → 装驱动」串成一条流水线。
它是 **Boot Camp 的反向操作**：在 PC 上装 macOS。免费，禁止售卖。

### 步骤 0 · 前置准备

- 一台**能正常运行的 Windows**（用于制作 U 盘）
- **≥ 4 GB 的 U 盘**（会被清空），以及联网
- 目标机器 BIOS 需支持 **Above 4G Decoding** 与 **关闭 CSM**
- **先做好备份**：动分区之前准备好 Windows 与数据的可恢复介质

### 步骤 1 · 在 Windows 上制作 macOS 安装 U 盘

1. 解压 `1401-Windows-1.0.24.zip`，**保持 `1401` 文件夹完整**，运行 `1401.exe`（会请求管理员权限 —— 它要读硬件、写 U 盘）。
2. 依次点：
   - **Check this PC** —— 检测硬件
   - **Build the Mac setup** —— 生成 OpenCore 配置
   - 阅读 **Your BIOS steps** —— 记下它要求你改的 BIOS 项
   - **Create the macOS stick** —— 写入 U 盘

> 1401 基于 OpCore-Simplify 构建，然后套用自己的规则。每次触发的规则都会记录在构建结果里。与本机相关的规则：
> - `nullmoth-boot-args` / `nullmoth-sip` —— 命中驱动设备表：写入驱动的 boot-args，SIP 设为 `0x0A43`
> - `nullmoth-installer-bar` —— **安装器用小 BAR**（`ResizeAppleGpuBars 0`、`ResizeGpuBars -1`），让没有驱动的安装器屏幕能活下来
> - `boot-logs-on-stick` —— OpenCore / Apple 启动日志 / macOS panic 全写到 U 盘，方便排障
> - `keep-boot-args` —— 不覆盖已经在跑 macOS 的机器的 boot-args

### 步骤 2 · BIOS 设置

重启进 BIOS，按 1401 列出的项修改。本机（TUF GAMING Z690-PLUS WIFI D4）对应：

| 项目 | 值 |
|---|---|
| Above 4G Decoding | **Enabled** |
| ReSizable BAR / ReBAR | **Enabled**（本机已开） |
| CSM (Compatibility Support Module) | **Disabled** |
| Secure Boot | **Disabled** |
| VT-d | 视情况（本配置用 `DisableIoMapper`） |

### 步骤 3 · 从 U 盘启动并安装 macOS

1. 插上 U 盘，从 U 盘启动，在 **OpenCore 菜单里选 macOS 安装器**。
2. 在安装器里**只选你要装 macOS 的那个分区/卷**。**不要**抹掉任何含 Windows 或其他数据的整块磁盘。
3. 用「磁盘工具」把目标分区格式化为 **APFS**，然后选 **Reinstall macOS**。剩下的系统文件从 Apple 下载。
4. 安装完成后，**每次开机都要插着这根 U 盘** —— OpenCore 在这根 U 盘上，它就是启动 macOS 的配置。

### 步骤 4 · 安装 NVIDIA 驱动

macOS 跑起来后（Turing 及以后、设备表内的卡）：

**方式 A（推荐，最简单）—— 1401 Mac app**
1. 打开 U 盘上的 `NullMoth` 文件夹，解压 `1401-Mac-<版本>.zip` 并运行 **1401.app**；或直接下载 `1401-Mac-<版本>.dmg`（驱动包就在镜像里，不用另外下）。
2. 跟着它的步骤走。它会：
   - 找到**启动你这台 Mac 的那个 OpenCore 分区**（`EFI/OC` 或 `EFI/BOOT`）
   - 改动前**逐条展示**、并备份 config
   - 安装驱动
   - 往 OpenCore 启动菜单里加一项 **「1401: Remove NVIDIA driver」** —— 选它可在下次启动时干净卸载驱动、还原 config，然后自动重启
3. **运行期间以及之后每次开机，都保持这根 U 盘插着**（它改的就是这根 U 盘上的 config）。
4. 装完重启。**第一次带驱动启动会在 `PCI configuration end` 停最多一分钟**，等 GPU 起来，属正常。

**方式 B —— 预编译包（手动）**

```bash
tar -xzf nullmoth-nvidia-*.tar.gz && cd pkgroot
shasum -a 256 -c SHA256SUMS          # 每个文件都要显示 OK
sudo ./install.sh                    # 拷贝文件并重建 Auxiliary Kernel Collection
sudo shutdown -r now                 # 必须重启，注销不会加载驱动
```

首次 macOS 会要求在 **系统设置 → 隐私与安全性** 里「允许」扩展；允许后**再重启一次**。

**卸载**

```bash
sudo ./uninstall.sh && sudo shutdown -r now
```

### 步骤 5 · 验证

```bash
kmutil showloaded --list-only | grep nullmoth      # 应有 4 行
system_profiler SPDisplaysDataType | head -20      # 应看到 GeForce，Metal: supported
```

### 出问题了怎么办

如果 macOS 从 U 盘起不来：回到 Windows，插上 U 盘，打开 1401，或点 **Scan for logs and send them**。
U 盘上有 OpenCore 和 macOS 的启动日志，1401 会把它们发出去（**姓名、序列号、地址会被移除**，网站用 SHA-256 校验），
然后给你一个 **report ID** —— 求助时引用这个 ID。也可以在 NullMoth Discord 里问。

---

## 四、本 EFI 与驱动的对接（关键配置）

如果不用 1401 的自动流程，而是把这个 EFI 接到一个已有的 OpenCore 上，下面这些**必须一致**。
**本仓库的 `config.plist` 已经全部对齐**（下表为核对结果）。

### `NVRAM → Add → 7C436110-AB2A-4BBB-A880-FE41995C9F82`

| 键 | 值 | 作用 |
|---|---|---|
| `csr-active-config` | `<430A0000>` (Data) | 已测试值：允许未签名 kext + root patch 所需 |
| `boot-args` | 见 §五 | 帧缓冲 + 加速 + 4 显示头；AMFI 参数让 WindowServer 能加载驱动 bundle |

> 你设置的每个键**都要同时加到 `NVRAM → Delete`**，保证每次启动都重写。

### 各项设置

| 位置 | 值 | 原因 |
|---|---|---|
| `UEFI → Quirks → ResizeGpuBars` | `13` | 8 GB BAR1，**作者验证过的值**（作者把驱动上限压死在 8 GB，理由是「16 GB 会在 bring-up 停住」）。⚠️ 代价：开机 ~21 s 死画面（停在 ACPI 页）。回退条件：开机卡 >2 分钟 ⇒ 改 `12`（4 GB）或关 ReBAR |
| `Booter → Quirks → ResizeAppleGpuBars` | `-1` | 让 macOS 看到完整 BAR |
| `Kernel → Block` | `com.apple.iokit.IONDRVSupport`，Strategy `Exclude` | 否则固件帧缓冲会抢走 NVRMFB 的显示 index 0 |
| `Kernel → Block` | `com.apple.iokit.IOSkywalkFamily`，Strategy `Exclude` | 让 OCLP 的 IOSkywalkFamily 生效（见 §九） |
| `Kernel → Add` | **`CPUFriend.kext` 必须排在 `Lilu.kext` 之后**，随后是 `CPUFriendDataProvider.kext` | CPUFriend 依赖 Lilu 完成 patch |
| `ACPI → Delete` | `SSDT` / `OemTableId = xh_adls3`（`All=false`） | 移除 BIOS 原始 `xh_adls3`，改加载修正版（见 §七） |
| `NVRAM → Add → 4D1FDA02-…-B30102` | `revpatch=sbvmm,cpuname`、`revcpu=1`、`revcpuname=<CPU 名称>` | 让「关于本机」显示自定义 CPU 名称（本机 = `8-Core Intel Core i7-12700K`，见下） |
| `Misc → Security → SecureBootModel` | `Disabled` | Apple Secure Boot 会拒绝非 Apple 签名的 kext |
| `Misc → Security → ExposeSensitiveData` | `7` | 让 1401 Mac app 能确认 OpenCore 是从哪个分区启动的（7 而非 15，刻意不含 OEM 信息） |

> **本仓库已移除的两段（发布用）**：
> - `DeviceProperties → Add` 置空 —— 原本有 3 条 `AAPL,slot-name`（`Slot-1` / `Slot-3` / `Slot-4`），
>   只让「系统报告 → PCI」显示真实槽位名，**纯外观**；但它会带出本机独有设备（Broadcom 卡、**UA UAD-2 DUO**）。
>   想恢复：按自己的 PCI 路径加回 `AAPL,slot-name`；**不要动 Wi-Fi 的 `IOName`**（会失配驱动）。
> - `PlatformInfo → Memory` 整段删除、`CustomMemory = false` —— 原本注入 12 槽内存视图（含内存条序列号 / 型号）。

> **CPU 名称显示**：用 `RestrictEvents` 修 ——
> boot-args 需含 **`revpatch=sbvmm,cpuname`**，并加 **`revcpu=1`**，名称放在 NVRAM
> `4D1FDA02-38C7-4A6A-9CC6-4BCCA8B30102:revcpuname`。
> **★ 坑：同名的 NVRAM 变量优先级低于 boot-args**，只写 NVRAM 会被 boot-args 的 `revpatch=sbvmm` 覆盖、等于没生效。
> **`ProcessorType` 保持 `0x0F01`（= 3841，8 核及以上），不要改。**

### 还必须满足

- **BIOS**：Above 4G Decoding ON、CSM OFF、**Intel Speed Shift Technology = Enabled**
- **SMBIOS**：能跑 macOS 26 且用独显的机型（**本机 = `iMac20,1`**；`iMacPro1,1` / `MacPro7,1` 都是已验证过的可回退基线）
- **删掉** `nv_disable=1`、WhateverGreen 的 NVIDIA patch、`agdpmod=pikera`
- NVIDIA 卡**不需要**任何功能性 `DeviceProperties`（本仓库的 `DeviceProperties → Add` 已置空）

---

## 五、boot-args（本仓库当前值）

```
-v amfi_get_out_of_my_way=0x1 amfi=0x80 -wegnoigpu nvrmsettle=1500 nvfbsample=1 ipc_control_port_options=0 nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth -no_compat_check revpatch=cpuname keepsyms=1 debug=0x144 revcpu=1 brcmfx-country=#a
```

| 参数 | 作用 |
|---|---|
| `nvfb=1 nvaccel=1 nvfbheads=4` | NullMoth 驱动：帧缓冲 / 加速 / 4 个显示头 |
| `-nvkmsnosmooth` | 关闭 KMS 平滑 |
| `amfi_get_out_of_my_way=0x1 amfi=0x80` | 让 WindowServer 能加载驱动 bundle（配合 AMFIPass） |
| `ipc_control_port_options=0` | 配合上面的 AMFI 参数；**缺了它**，加固过的应用（Firefox / Chromium 系）会在启动时因任务控制端口被杀 |
| `-wegnoigpu` | WhateverGreen：屏蔽无驱动的 Intel 核显 |
| `nvrmsettle=1500` | 驱动 settle 时间；**必须保留** —— 去掉它、且 BAR1 未放置（ReBAR 关）时，驱动会盲睡 100 秒（≈2 分钟开机）。**注意：只关 ReBAR 但保留本参数，不会有这个延迟。**（见下方说明） |
| `nvfbsample=1` | 诊断用：每 10 s 校验一次帧缓冲 |
| `-no_compat_check` | 让 macOS 26 在**不在白名单的机型**上跳过兼容性检查（`iMac20,1` 不在 Tahoe 白名单，靠它启动） |
| `brcmfx-country=#a` | `AirportBrcmFixup` 用的国家码覆盖（`#a` = 由 `BRCM` 固件自行决定）；配合 OCLP 的 Broadcom Wi-Fi |
| `revpatch=sbvmm,cpuname` + `revcpu=1` | RestrictEvents：修 CPU 名称显示为 `8-Core Intel Core i7-12700K`（见 §四） |
| `keepsyms=1 debug=0x144` | panic 时保留符号 + 打开调试输出（排障用） |
| `-v` | 详细启动日志 |

> 上游驱动文档的推荐串为：`nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0`
> —— 本机串与之等价（多了 `-v` / `-wegnoigpu` / `nvrmsettle=1500` / `nvfbsample=1` 等本机必需的项）。
> **注意**：本机 boot-args 中**没有** `-nvrmnoflip` —— 大 BAR1 体制下用默认的零拷贝路径。

#### 关于 `nvrmsettle`：那 100 秒盲睡的解法（上游 issue [#23](https://github.com/nullmoth/nvidia-macos-driver/issues/23)，已 closed / DONE）

- **根因**：`kexts/NVRM/NVRM.cpp:328` —— `fAutoGoSettleMs = bar1Placed ? 500 : 100000;`。
  下一行就是覆盖口：`PE_parse_boot_argn("nvrmsettle", …)`。**BAR1 放不下（256 MB 原厂档）时，每次启动都先盲睡 100 秒**（实测 101–103 s，精确到秒，连续 5 次）。
- **解法**：boot-args 加 `nvrmsettle=<毫秒>`。**#23 实测同机前后对比：到桌面可用 +197 s → +94 s（省 103 秒）**，`5000` 就够。
- **1.14 起安装器会自动加，但只对 Turing 卡**：`app/Resources/nullmoth-setup.sh` 里
  `case "$NVDEV" in 1[eEfF]??|21[89a-fA-F]?) TURING=1;; *) TURING=0;; esac`，命中才加 `nvrmsettle=10000`；且**用户自己设过就尊重用户的值**（`# the user's own value wins`）。
  ⚠️ **本机是 Ampere（`10de:2206`），不在自动范围内 ⇒ 必须手工保留。**
- **1.14 另修了两件「同族」的事，但没删掉这 100 秒本身**：
  ① boot-hold 的 40 秒上限原先从驱动启动算起、会在 `autoGo` 之前到期，导致回退路径上 display-arm 永远失败；现在上限 = **settle + 40 秒**（`NVRM.cpp:334-343`，`docs/CARD-SUPPORT.md` "Startup correction"）。
  ② 老 Intel 主板（B150 等）「约 100 秒后黑屏」（`docs/TROUBLESHOOTING.md`，标注 Fixed in 1.14）。
  **`100000` 这个默认值在 1.15.0 里仍然原封不动** ⇒ 上述修复**不能替代** `nvrmsettle`。
- **那 102 秒之外还有约 60 秒**是另一件事，见 [#35](https://github.com/nullmoth/nvidia-macos-driver/issues/35)（同样 closed / DONE）：
  是主板枚举的**无驱动 Intel UHD 770** 让 `IOGraphicsFamily` 等待；`-wegnoigpu` 藏掉它后 **91 s → 27 s**（本机 boot-args 已含）。#23 的最终结论：**137 s → 28 s**。

### 可选：`-nvrmsmallbar`（驱动 1.15.0 新增，**本机当前未使用**）

| 参数 | 作用 |
|---|---|
| `-nvrmsmallbar` | 让 `NVRM::placeLargeBar1()` 一进函数就 `return false` ⇒ **驱动既不放大小 BAR1，也不把它搬到高地址**，于是 ReBAR 卡改走「小 BAR 卡」的代码路径（小预算 / 拷贝路径 / 私有 surface）。 |

- 作者原话（`kexts/NVRM/NVRM.cpp`，提交 `ab740c2fce`）：**"for testing and diagnosis"** —— 它是**诊断/对照开关，不是修复**，因此**不进** 1.15.0 的 CHANGELOG 正文。
- **实测（本机，2026-10-13）**：加该参数后驱动日志为 `bar1: -nvrmsmallbar set — BAR1 left as IOPCIFamily placed it`，BAR1 从 8 GB 掉到 **32 MB**（`0x2000000`）；去掉后回到 8 GB 并出现 `placing` / `PLACED` 两行（那两行就是开机 ~21 s 死画面的来源）。
- **它不是「关 ReBAR」的等价物**：拨杆切原厂档得到的是 **256 MB**，这个开关得到的是 **32 MB**，别把两者的结论互相套用。
- 用途：想验证「某症状是不是大 BAR1 引起的」时，**不用断电、不用拨杆**即可做 A/B；实验完请撤掉（32 MB 比原厂 256 MB 还小，等于主动放弃 ReBAR 全部好处）。
- 判读：`sysctl debug.nvrmfb_vram_budget_bytes` 应变成 **201326592**（192 MB）；若仍是 4096/8192 MB，说明没进小 BAR 体制。
- ⚠️ **macOS 26 起无法在系统内写 boot-args**（`nvram boot-args=…` 报 `(iokit/common) general error (1)`），只能改 EFI 的 `config.plist`，改完必须重启。
- ⚠️ **它只掐掉「放大 + 重定位」，不保证修好下游任何问题。** 上游 [#185](https://github.com/nullmoth/nvidia-macos-driver/issues/185) 里加了它，
  重定位 / 光圈表重建确实不再执行，但 `RmInitAdapter()` 仍以完全相同的方式失败。⇒ 当成**变量隔离工具**，别当万能修复（详见 §十一）。

---

## 六、Kexts

### 已启用

| Kext | 版本 | 来源 |
|---|---|---|
| Lilu | 1.7.3 | **Dortania build-repo**（`Lilu-0515f40`） |
| **CpuTopologyRebuild** | 2.0.2 | b00t0x（重建 Alder Lake P/E 核拓扑；本机 **E 核开启**） |
| **CPUFriend** | **1.3.0** | acidanthera（**必须排在 Lilu 之后**） |
| **CPUFriendDataProvider** | — | 数据 = **`iMacPro1,1` 的完整机型 plist（已删掉 `hwp` 变量）**（见下） |
| VirtualSMC | 1.3.9 | **Dortania build-repo**（`VirtualSMC-b5c62c2`） |
| SMCProcessor | 1.3.9 | **Dortania build-repo** |
| SMCSuperIO | 1.3.9 | **Dortania build-repo** |
| WhateverGreen | 1.7.2 | **Dortania build-repo**（`WhateverGreen-093e76f`） |
| AppleIGC | 1.9d2 | sxx（**本机 `Enabled=false`**，见 §一） |
| NVMeFix | 1.1.4 | acidanthera |
| RestrictEvents | 1.1.7 | **Dortania build-repo**（`RestrictEvents-9265e78`） |
| USBToolBox | 1.2.0 | dhinakg |
| XHCI-unsupported | 0.9.2 | RehabMan |
| UTBMap | 1.1 | dhinakg |
| AMFIPass | 1.4.1 | dhinakg |
| BlueToolFixup | 2.7.3 | **Dortania build-repo**（`BrcmPatchRAM-6538902`） |
| **IOSkywalkFamily** | 1.0 | **OCLP**（必须排在 IO80211FamilyLegacy 之前加载） |
| **IO80211FamilyLegacy** | 12.0 | **OCLP**（BCM43602 的基础驱动） |
| **AirPortBrcmNIC-Tahoe** | OCLP 3.0.0-rc.3 | **OCLP**（`MinKernel = 25.0.0`，Darwin 25 / macOS 26 上的 `pci14e4,43ba` 驱动） |

> **★ 为什么版本号比官方 release 高一位（2026-10-16 查证）**：`Lilu 1.7.3` / `VirtualSMC 1.3.9` /
> `WhateverGreen 1.7.2` / `RestrictEvents 1.1.7` / `BlueToolFixup 2.7.3` 这些**不是**上游的 release 版本
> （上游 tag 里查不到），而是 **[Dortania `build-repo`](https://github.com/dortania/build-repo)** 按
> **具体 commit** 构建的产物 —— 上游在最后一次 release 之后又有提交，Dortania 就把补丁号 +1。
>
> **这是厂商指定要用的版本**：NullMoth 的安装脚本 `app/Resources/nullmoth-setup.sh` 里 `kurl()`
> 把 `Lilu.kext` 固定到 `dortania/build-repo/…/Lilu-0515f40/Lilu-1.7.3-RELEASE.zip`，
> 并**逐个校验 SHA-256**（`261aebb9dc83adb6…`）；`RestrictEvents` 同理。注释原话：
> *"Kexts the driver's OpenCore setup needs, pinned to the same files 1401 builds with."*
>
> ⇒ **不要把这些换成上游的 release** —— 那是**降级**（release 对应的是更早的 commit）。
> 本仓库的这 8 个 kext 与 Dortania 的产物**逐字节相同**（已逐个 sha256 比对）。

> **★ CPUFriend 是干什么的**：`MacPro7,1` / `iMac20,1` 这类机型 profile 的数据里带 `hwp="on"`，
> 会让 macOS 在 Alder Lake 上走 **HWP 硬件调频**，配合一张不对口的频率表产生**低频振荡**
> （本机实测单线程只有 2.24–2.54 GHz，八个核频率忽高忽低 → 表现就是「卡顿 / 掉帧」）。
> 用 `CPUFriendDataProvider` 注入 **`iMacPro1,1` 的完整 plist（**已删掉 `hwp` 变量**，走传统 XCPM P-state）** 后，
> 单线程回到 **~4.15 GHz**、八核稳定在 **~4.19 GHz（+85%）**，振荡消失。
>
> **★ 机型与 CPUFriend 数据是解耦的两件事**：机型决定「关于本机 / 内存图 / iServices 身份」，
> CPUFriend 数据决定「频率行为」。本机刻意组合 = **`iMac20,1` 的外壳 + `iMacPro1,1` 的频率表**。
> 回退 = 把这两条 `Kernel → Add` 条目设为 `Enabled=false`（或删掉两个 kext）。

> **注意**：NullMoth 驱动的 4 个 kext（NVRM / NVAccel / NVRMFB / NVRMAGDC）**不在这里**，
> 它们装在 `/Library/Extensions`，由 Auxiliary Kernel Collection 加载。

### 已放置但**禁用**（`Enabled = false`）

| Kext | 版本范围 | 说明 |
|---|---|---|
| `IO80211FamilyLegacy.kext/Contents/PlugIns/AirPortBrcmNIC.kext` | `MinKernel 23.0.0` / `MaxKernel 24.99.99` | 同一条 BCM43602 驱动的 **Sequoia 版**。macOS 26 走单独的 `AirPortBrcmNIC-Tahoe.kext`（`MinKernel 25.0.0`）⇒ 这里保持禁用 |

> `AppleALC` / `itlwm` / `IntelBluetoothFirmware` / `IntelBTPatcher` 已从本 EFI 中**完全移除**。

## 七、Drivers / ACPI / Tools

- **Drivers**：`OpenRuntime.efi`、`OpenHfsPlus.efi`、`ResetNvramEntry.efi`、`OpenCanopy.efi`
  - 目录里另有 `NullMothLogo.efi`（NullMoth 开机 logo，**当前未启用**；不想要可在 `UEFI → Drivers` 里关掉）
- **ACPI**（启用 6 个）：`SSDT-EC.aml`、`SSDT-RTC-AWAC.aml`、`SSDT-USBX.aml`、`SSDT-SBUS-MCHC.aml`、**`SSDT-PLUG-ADL.aml`**（12 代 XCPM 处理器表）、**`SSDT-XHADLS3.aml`**
  - 目录里另有 `disabled/` 子目录：`SSDT-PLUG-MADT.aml`、`SSDT-PLUG-DRTNIA.aml`，**均禁用**（CPU 命名空间不对 / 12 代对比用的 Dortania 版）。
  - **`ACPI → Delete`**：`TableSignature = SSDT`、`OemTableId = xh_adls3`、`All = false` ——
    先移除 ASUS Z690 BIOS 自带的 `xh_adls3`，再加载修正版 `SSDT-XHADLS3.aml`，
    否则原表引用了不存在的 `\_SB.PC00.XHCI.RHUB.HS06`，启动时刷 `AE_NOT_FOUND`。
- **Tools**：`OpenShell.efi`、`NullMothSafe.efi` ×2 条 —— 分别对应启动菜单里的
  **「NullMoth: remove the NVIDIA driver at the next start」** 与 **「NullMoth: start macOS once without the NVIDIA driver」**（救援入口）

## 自检 / 取证脚本（[`scripts/`](scripts/)）

配套 [ReBAR 完全指南] 的一组诊断脚本。**不依赖本仓库的 EFI**，任何装了 NullMoth 驱动的机器都能跑；
**不需要装任何东西**（除 macOS 自带的 `bash` / `python3` / `screencapture`），脚本里**没有写死用户名或路径**。

```bash
# 直接跑（不用 clone）
curl -fsSL https://raw.githubusercontent.com/GeekAudio/i7-12700K-RTX3080-OpenCore-Hackintosh/main/scripts/check-rebar-state.sh | bash
```

| 脚本 | 干什么 | root？ |
|---|---|---|
| **`check-rebar-state.sh`** | ★ 开机后先跑这个：BAR1 实际大小、预算、用量、显示 arm 状态、AGDC GPU 列表、开机耗时 | 否 |
| `verify-iop-flip-ab.sh` | 在拷贝路径 / 零拷贝之间来回切，判定重影/黑块是不是驱动输出路径问题 | 是（弹一次密码框） |
| `check-surfdirty.sh` | 统计 WindowServer surface **脏标记被拒绝**的比例 | 否 |
| `capture-ghost-pack.sh` | 重影**出现时**跑一次，把整屏/窗口截图 + 驱动计数器 + 按启动分段的 surfvram 统计收进一个目录 | 否 |
| `watch-ghost.sh` | 重影**自动连拍**，你只管复现，事后按时间点回看 | 否 |
| `cpu-freq-probe.sh` | 实测 CPU 真实核心频率（`mulsd` 依赖链 + 内联汇编，防编译器折叠） | 否 |

- 输出目录默认取**当前目录**，可用 `OUTDIR=~/Desktop bash capture-ghost-pack.sh` 覆盖。
- 每个脚本的详细用法、判读口诀见 **[scripts/README.md](scripts/README.md)**。

## 八、Kernel → Block

```
com.apple.iokit.IONDRVSupport      ← 驱动要求 Exclude：否则固件帧缓冲抢走显示 index 0
com.apple.iokit.IOSkywalkFamily    ← OCLP Modern Wireless：允许降级到 OCLP 的 IOSkywalkFamily
```

> 早期版本还屏蔽过 `IOBluetoothFamily` / `IO80211Family` 一族；换成 **BCM943602CDP** 之后已全部解除（见 §九）。

## 九、无线与蓝牙（BCM943602CDP + OCLP）

本机已把原装 Intel AX201 换成 **Broadcom BCM943602CDP**，以拿到完整的 Continuity（AirDrop / 接力 / 通用剪贴板 / Apple Watch 解锁）。
这套方案**分 EFI 侧和系统侧两部分，缺一不可**：

**EFI 侧（本仓库已含）**
- `Kernel → Add` 新增 `IOSkywalkFamily` 与 `IO80211FamilyLegacy` —— **顺序不能反**
- `Kernel → Add` 新增 **`AirPortBrcmNIC-Tahoe.kext`**（`MinKernel = 25.0.0`，OCLP 3.0.0-rc.3）——
  **macOS 26 / Darwin 25 需要它**：`IO80211FamilyLegacy` 内自带的那个 `AirPortBrcmNIC` 插件
  `MaxKernel = 24.99.99`，在 Darwin 25 上不生效，所以要单独挂一个 Tahoe 版。
- `Kernel → Block` 屏蔽 `com.apple.iokit.IOSkywalkFamily`（让 OCLP 的版本生效）
- 启用 `BlueToolFixup`
- `NVRAM` 新增 `bluetoothExternalDongleFailed` / `bluetoothInternalControllerInfo`
  （**本仓库里后者的蓝牙地址已清零**，macOS 会自行重填）

**系统侧（不在本仓库，必须自己做）**
- 用 [OpenCore Legacy Patcher](https://github.com/dortania/OpenCore-Legacy-Patcher) 打 **Post-Install Root Patch**，
  它会替换 `IO80211.framework` / `WiFiPeerToPeer.framework` 并启用 `wifip2pd`。
- **没有这一步，Wi-Fi 搜不到网络**（内核 kext 已加载，但用户态框架还是原版）。

> ⚠️ **任何 OCLP 操作前，先跑本机的 `prep-oclp-rootpatch.sh`。**
> 否则 OCLP 的 `clean_auxiliary_kc()` 会把 mtime=1970-01-01 的 **NullMoth 4 个 kext 从 `/Library/Extensions` 搬走** ⇒ NVIDIA 驱动失效。

## 十、从源码构建驱动（可选）

需要 **Xcode 16**、**Rust (stable)**、**Meson/Ninja**，以及 NVIDIA `open-gpu-kernel-modules` 的 **tag `610.57.04`**。

```bash
build/build_xlate.sh                 # 翻译器 → libnvmtl_translate.dylib
RELEASE=1 build/build_plugin.sh      # 插件 → NVMTLDriver.bundle（RELEASE=1 会去掉全部诊断）
build/build263.sh                    # NVK：先把 nvk/nvk-macos.patch 打到 Mesa 17ca6174
build/accel_build.sh <src> <out>     # kexts
```

## 十一、已知问题

这套配置**存在若干已知 bug**，需要先说清楚：**它们与显示器刷新率无关，不是「50 Hz 黑屏」**。

| 现象 | 状态 | 说明 |
|---|---|---|
| **窗口重影** | 🔴 仍存在 | 鼠标划过**未激活**窗口时，窗口内的文字/框线会被重复绘制（同一条线画在相距数像素的多处）；鼠标停下后重影仍在，点一下聚焦即恢复 |
| **黑窗 / 黑块扩散** | 🔴 仍存在 | 重影区域在**切换刷新率**后会变成纯黑并向周围扩散；桌面本身不受影响。1.14.0 只修了「色块」那一路，全黑那一路还在 |
| **偶发「黑一下」** | 🔴 仍存在 | 短暂黑屏，但**屏幕上仍有鼠标光标** —— 说明 WindowServer 还活着、只是合成器画不出来，即 Metal 设备尚未就绪 |
| **USB3 拿不到** | 🟡 已接受 | 本机 USB3 无解（15 端口上限 + 端口图铁律）。现状用 T3 图：后置 6×USB-A + 2×Type-C **全部可用，但只有 USB2 速率** |
| ~~蓝牙同步调用死锁~~ | ✅ **已解决** | 原 `IOBluetoothFamily` 被屏蔽但 `bluetoothd` 在跑 ⇒ 同步 XPC 永久等待，严重时连 USB 输入一起卡死。**换 BCM943602CDP 后根除** |
| ~~mediaanalysisd 崩溃~~ | ✅ **已修** | 驱动 1.14.0 起不再出现 |
| ~~显示器被识别成 30.5″ 电视~~ | ✅ **已修**（本机自打补丁） | 1.15.0 自带的补丁**本机实测无效**（仍报 30.5959″）。**真因 = 驱动没填 `IODisplayModeInformation.imageWidth / imageHeight`** ⇒ 已修好并生效（现报 **21.4041″**）。⚠️ **PR #199 已被上游收编进 v2.0.0**（changelog 署名），本机驱动已是 2.0.x ⇒ **不需要本地补丁** |

> **HiDPI**：macOS / CoreGraphics **自带**能力，不需要额外补丁 —— 装上修好尺寸的驱动后，
> 「系统设置 → 显示器」里即可选 HiDPI 模式。
> ⚠️ **枚举判据有坑**：必须带 `kCGDisplayShowDuplicateLowResolutionModes` 才能看全；
> **只有切过去之后，当前模式才报 `pw = 2 × w`**。

- 显示器**建议使用 60 Hz**，但**不要**把这些现象归因于 50 Hz —— 它们是驱动侧（NVIDIA 显示 / 合成路径）的问题。
- 上游问题跟踪：<https://github.com/nullmoth/nvidia-macos-driver/issues>
- **1.15.0 的状态**：重影 / 黑窗 bug **仍列在其 CHANGELOG 的 Known issues 里**（"Ghost or black areas after windows overlap with a BAR of 4 GB or more (#127)"）⇒ 1.15.0 **没有修**这个问题。

### 与本机无关、但换卡/换机前该知道的一类失败：上游 #185

上游 [#185](https://github.com/nullmoth/nvidia-macos-driver/issues/185)（2026-10-13 报出，**open，作者未回复**）是一台
**RTX 4060 Laptop + Ryzen 9 7945HX** 笔记本，症状是**连驱动都起不来** —— 与本机的重影 bug **不是一回事**：

```text
bar1: Resizable BAR capability @0xbb0 says BAR1 = 8192 MB          ← 本来就已经是 8 GB
bar1: placing BAR1 8192 MB @0x3ffa00000000, BAR3 32 MB …           ← 驱动仍去做重定位
bar1: placed in hardware but the aperture list could not be built (no memory)
auto-go: go(2) in 100000 ms on its own thread (BAR1 not placed)    ← 于是又吃满 100 秒盲睡
… RmInitAdapter() →
NVRM: kbusVerifyBar2_GM107: MMUTest BAR0 window offset 0x70e000 returned garbage 0x0
NVRM: NV_ERR_MEMORY_ERROR (0x00000072) … RmInitAdapter failed! (0x24:0x72:1281)
```

三个要点：

1. **「已经是大 BAR1」≠「驱动就放过它」。** 驱动跳过的是「放大」那一步，「搬到 ≥4 GB 高地址 + 重建光圈表」照做 —— 这台机器就死在这一步。
2. **`-nvrmsmallbar` 在这台机器上没救回来。** 升到 1.15.0 加了这个参数后，重定位 / 光圈表重建确实不再执行，但 `RmInitAdapter()` **仍以完全相同的方式失败** ⇒ 光圈表重建失败**不是**复现该 BAR2 失败的必需条件。
3. **100 秒盲睡的判据是 `placeLargeBar1()` 的返回值，不只是「BAR1 放没放上」。** 这里硬件上放成功了，但函数因光圈表建不起来而返回 `false`，驱动照样判「BAR1 not placed」。⇒ `nvrmsettle` 对这类情况**同样有效**（它覆盖的是等待时长）。

**本机的对照**：本机 `ioreg` 读数为 `bar0@0x10` / **`bar1@0x14`** / `bar2@0x1c` —— 三个槽各就各位、`0x14`（FB）在；
且本机全部历史日志中 `aperture list could not be built` / `kbusVerifyBar2` / `0x72` 的命中数均为 **0**。
⇒ 这是一台正常机器与该故障机器之间最直接的分界证据。

> 报告中提到的 `readBARs()` 槽位错配（`0x14` 缺失时 `0x1c` 顶替进 FB 槽）**是报告者自己写明的假设，尚未证实**，请勿当作结论。

### 上游已验证的解法（成功案例速查）

按「症状 → 别人是怎么解决的」整理，全部出自上游 issue 里报告者自己的话。**照抄前先看自己的 BAR1**（`ioreg -r -n NVRM -d 1 -l | grep nvrm-bars`）。

**A. 已正式关闭（`[DONE]` / completed）**

| 症状 | 机器 / BAR1 | 解法 | 出处 |
|---|---|---|---|
| 每次开机多等 ~102 秒 | RTX 3080，原厂 256 MB | boot-args 加 `nvrmsettle=<ms>`（+197 s → +94 s） | [#23](https://github.com/nullmoth/nvidia-macos-driver/issues/23) |
| 剩下 ~60 秒开机延迟 | 主板带**无驱动** Intel 核显 | `-wegnoigpu`（91 s → 27 s；最终 137 s → 28 s） | [#35](https://github.com/nullmoth/nvidia-macos-driver/issues/35) |
| 光标一动就闪屏 / 画面冻结 | RTX 3080，256 MB | `-nvrmnoflip` | [#20](https://github.com/nullmoth/nvidia-macos-driver/issues/20) |
| WindowServer 崩溃循环 `Failed to create MetalDevice` | GTX 1650，**BAR1 4 GB** | 升到 **1.2.0**；真因 = `/Library/GPUBundles/nvmtl-allow.txt` 权限 `0600` → `0644 root:wheel`（另一台 RTX 4060 Laptop 独立复现） | [#38](https://github.com/nullmoth/nvidia-macos-driver/issues/38) |
| 装完驱动后 verbose 画面冻住 | RTX 3070 Ti，`13`（8192 MiB） | 升到 **1.1.0** | [#12](https://github.com/nullmoth/nvidia-macos-driver/issues/12) |
| 屏幕持续闪烁（多卡） | 2070S / 4050 Laptop / 5070 Ti / 3050 Ti Laptop | 升到 **1.14.2** | [#124](https://github.com/nullmoth/nvidia-macos-driver/issues/124) |
| 100 Hz 只跑 ~49 fps（75 Hz 反而正常） | GTX 1650，BAR1 4 GB，双屏 | 升到 **1.10.0**（100 Hz → ~98 fps） | [#67](https://github.com/nullmoth/nvidia-macos-driver/issues/67) |
| 开机 ~3 分钟后桌面卡到 ~6 fps | RTX 5060 Ti 16 GB，4K 144 Hz | 升到 **1.15.0**（`79e1c2f`「Reclaim pending surface slots」） | [#143](https://github.com/nullmoth/nvidia-macos-driver/issues/143) |

**B. 未关闭但报告者已确认「这台机器好了」**

| 症状 | 机器 / BAR1 | 解法 | 出处 |
|---|---|---|---|
| `rm_init_adapter -> FAILED` | RTX 3050 Ti Laptop（AMD 核显 + dGPU-only） | **PAT 补丁换成 `Algrey / Zormeister` 变体**，禁用 Shaneee 那几条 —— 报告者认为影响**所有 AMD iGPU + NVIDIA dGPU 笔记本** | [#69](https://github.com/nullmoth/nvidia-macos-driver/issues/69) / [#15](https://github.com/nullmoth/nvidia-macos-driver/issues/15) |
| 外接屏黑 / 画面冻结（`Display Hash table is FULL`） | RTX 2070 Super Laptop，**BAR1 256 MB（卡无 ReBAR 能力）** | **`-nvrmnoflip` 必需**；100 秒等待属预期（#23）。标题直接写 "(works)" | [#82](https://github.com/nullmoth/nvidia-macos-driver/issues/82) |
| 按 README 设 `13/-1` 直接冻死启动 | RTX 4090，固件 BAR1 = **32 GB** | 改 `ResizeGpuBars=-1` + `ResizeAppleGpuBars=0`，让 NVRM 自己放 | [#93](https://github.com/nullmoth/nvidia-macos-driver/issues/93) |
| 610 次 8 MB 分配被拒 + headless 误判 | RTX 3090，BAR1 **64 MB** | **先查 BIOS**：开 `Above 4G Decoding` + `Resizable BAR` | [#117](https://github.com/nullmoth/nvidia-macos-driver/issues/117) |

**规律**：**小 BAR（< 4 GB）靠 boot-args**（`-nvrmnoflip` + `nvrmsettle`）；
**大 BAR（≥ 4 GB）靠升级驱动版本**（#38 / #12 / #124 / #143 全是版本升级修好的，说明症状多半来自驱动 bug 而非配置）；
**固件 BAR1 > 8 GB 靠放手**（`-1` / `0`，别让 OpenCore 硬钉）；
**卡无 ReBAR 能力靠 BIOS**（OpenCore 的 `ResizeGpuBars` 无从可调）。
另有一个容易误判的跨机器根因：**`nvmtl-allow.txt` 的文件权限**（#38）—— BAR1 和 RM 都正常，却没有桌面。

> **★ 重影 / 黑窗由 BAR1 大小门控**（本机 A/B + 四档二分实测，上游 issue #127）：
> 只要驱动看到的 `fBarLen >= 4 GB`（4 / 8 / 16 GB 都算），重影就可能出现；
> **256 MB 原厂档不会出现**。与之相对，`< 4 GB` 时图形内存预算被写死 192 MB，
> 会出现「拒绝洪水」和闪黑帧。**预算公式**（`kexts/NVRM/fb/nvrm-fb.cpp`）：
> `budget = (BAR1 >= 4GB) ? BAR1/2 : 192 MB`。
> 换句话说：**「有重影」和「预算宽松」是同一个开关的两面**，不能只要其一。

> **macOS 26 (Tahoe) 上的复测状态**：升级到 macOS 26.7.1 后，
> **#73 的窗口遮挡重影暂未复现**（kext 与升级前逐字节相同，样本不足，尚不能下结论）；
> **#74 的 Preview 纯色黑块仍能复现**。

## 十二、更新日志

| 日期 | 变更 |
|---|---|
| 2026-10-16 | **kext 溯源查清（订正）**：`Lilu 1.7.3` / `VirtualSMC 1.3.9` / `WhateverGreen 1.7.2` / `RestrictEvents 1.1.7` / `BlueToolFixup 2.7.3` 这些「比官方 release 高一位」的版本号，是 **[Dortania build-repo](https://github.com/dortania/build-repo) 按具体 commit 构建**的产物，且**被 NullMoth 安装器 `kurl()` 固定 + SHA-256 校验**。⚠️ **不要换成上游 release（那是降级）**。已逐个 sha256 与 Dortania 产物比对确认相同（详见 §六） |
| 2026-10-16 | **驱动版本订正**：本机实际为 **2.0.x**（`/Library/NullMoth/driver-version` = `2.0.1`；驱动本体 = v2.0.0 = 最新），**不是** 1.15.0；**PR #199 已被上游收编进 v2.0.0** ⇒ 不再需要本地补丁。**`AppleIGC` 改为启用**（用户要求开启有线网；`en0` 已钉给 Wi-Fi，有线应得 `en1`） |
| 2026-10-16 | **SMBIOS 换 `iMac20,1`**（三码随之更换；`iMacPro1,1` / `MacPro7,1` 保留为已验证的回退基线）；**`CPUFriendDataProvider` 换回 `iMacPro1,1` 的频率表**（删 `hwp`）⇒ 刻意组合 = **iMac20,1 外壳 + iMacPro1,1 频率表**；**`CpuTopologyRebuild` 回归启用**；**`AppleIGC` 禁用**（让无线拿到 `en0`）；boot-args 增 `brcmfx-country=#a`；`Generic → ROM` = **无线 MAC**；显示器尺寸问题**已修**（PR #199） |
| 2026-10-14 | **同步到当前 ESP + 发布前清理**：EFI 全量同步（ACPI 改名 `SSDT-PLUG-ADL` / `SSDT-RTC-AWAC` / `SSDT-XHADLS3` + `disabled/` 子目录；移除 `CpuTopologyRebuild`；`NullMothLogo.efi` 未启用）。**移除 `DeviceProperties → Add`（PCI 槽位名注入）与 `PlatformInfo → Memory`（内存条视图注入）**，`CustomMemory = false` —— 两者只影响「系统报告」外观且携带本机硬件信息 |
| 2026-10-13 | **跟随作者**：`ResizeGpuBars` **`-1` → `13`**（8 GB，作者验证范围）；同时把 ESP 的 `Kernel/Block → IONDRVSupport` 从 `false` 补成 **`true`**（装 Tahoe 后漏做的回填）。ESP / 桌面部署母本 / 本仓库三方现已一致 |
| 2026-10-13 | **EFI 同步**：`ResizeGpuBars` `13` → **`-1`**（16 GB）；`config.plist` 与当前 `~/Desktop/EFI/OC/config.plist` 部署母本逐项对齐（仅脱敏字段不同）；README 正文的驱动版本 / BAR1 数值订正 |
| 2026-10-13 | 驱动升到 **1.15.0**（`-nvrmsmallbar` 等）；补记当时 `ResizeGpuBars` 实测为 `-1`（16 GB）——**当晚 22:46 已改回 `13`，以本行下方的最终行为准**；`ResizeAppleGpuBars = -1`；已知问题补 30.5″ 电视误报；§五 增 `-nvrmsmallbar` 说明 |
| 2026-10-13 深夜 | 补记上游 **#185**（RTX 4060 Laptop：BAR1 本来已是 8 GB 仍被重定位 ⇒ 光圈表重建失败 ⇒ `RmInitAdapter failed! (0x24:0x72:1281)`）；§十一 增一条「与本机无关但值得知道」的条目 |
| 2026-10-14 凌晨 | §十一 增 **「上游已验证的解法（成功案例速查）」**：12 个 ReBAR/BAR1 相关成功案例（#23/#35/#20/#38/#12/#124/#67/#143 已关闭；#69/#82/#93/#117 报告者已确认可用），并抽出「小 BAR 靠参数 · 大 BAR 靠版本 · 超大 BAR 靠放手 · 没能力靠 BIOS」这条规律 |
| 2026-10-13 | 系统升到 **macOS 26.7.1 (25G241)**；SMBIOS 换 **`MacPro7,1`**（BIOS 需 `Intel Speed Shift Technology = Enabled`）；加 **CPUFriend + CPUFriendDataProvider** 修 CPU 限频；ACPI 换 `SSDT-PLUG-ALT` + `SSDT-XH_ADLS3`（配 `ACPI → Delete`）；加 `AirPortBrcmNIC-Tahoe.kext`（Darwin 25 Wi-Fi）；`DeviceProperties` 加 PCI 槽位名；boot-args 加 `-no_compat_check` / `revpatch` / `revcpu`；瘦身（移除 AppleALC / itlwm / Intel 蓝牙三件套）；**新增 [`scripts/`](scripts/) 诊断脚本** |
| 2026-10-12 | 驱动升到 **1.14.2**；换 **BCM943602CDP**（EFI 加 IOSkywalkFamily + IO80211FamilyLegacy，Block 收敛为 2 条，启用 BlueToolFixup）；`SSDT-SBUS-MCHC` 禁用；新增 `NullMothLogo.efi` 与两条 `NullMothSafe.efi` 救援项；boot-args 归位为当前串 |
| 2026-10-11 | 对齐 1401 / 驱动文档：boot-args 增 `ipc_control_port_options=0`；`ExposeSensitiveData` 0 → 7 |
| 2026-10-11 | 首次发布：主板更正为 TUF GAMING Z690-PLUS WIFI D4（ReBAR 已开）；补 1401 构建流程、驱动引用、已知问题、致谢 |

## 十三、致谢

本配置完全建立在别人的工作上，在此一并致谢。

**核心**

- **[NullMoth Systems](https://github.com/nullmoth)** —— 没有他们，这台机器根本跑不起来：
  - [**1401**](https://github.com/nullmoth/1401)：装机流水线（检测硬件 / 生成 OpenCore / 制作安装盘 / 装驱动）
  - [**nvidia-macos-driver**](https://github.com/nullmoth/nvidia-macos-driver)：RTX 3080 的 Metal 与显示驱动
- **[acidanthera](https://github.com/acidanthera)** —— [OpenCorePkg](https://github.com/acidanthera/OpenCorePkg)、[Lilu](https://github.com/acidanthera/Lilu)、[VirtualSMC](https://github.com/acidanthera/VirtualSMC)、[WhateverGreen](https://github.com/acidanthera/WhateverGreen)、[NVMeFix](https://github.com/acidanthera/NVMeFix)、[AppleALC](https://github.com/acidanthera/AppleALC)、[RestrictEvents](https://github.com/acidanthera/RestrictEvents)、BlueToolFixup
- **[Dortania](https://dortania.github.io/OpenCore-Install-Guide/)** —— OpenCore 安装指南；**[OpenCore Legacy Patcher](https://github.com/dortania/OpenCore-Legacy-Patcher)** —— Broadcom Wi-Fi 的系统侧补丁

**Kext 作者**

- **[dhinakg](https://github.com/dhinakg)** —— [AMFIPass](https://github.com/dhinakg/AMFIPass)、[USBToolBox](https://github.com/USBToolBox/tool)（`USBToolBox.kext` + `UTBMap.kext`）
- **[zxystd / OpenIntelWireless](https://github.com/OpenIntelWireless)** —— [itlwm](https://github.com/OpenIntelWireless/itlwm)、[IntelBluetoothFirmware](https://github.com/OpenIntelWireless/IntelBluetoothFirmware)、IntelBTPatcher
- **sxx** —— AppleIGC（Intel I225/I226 网卡驱动）
- **[b00t0x](https://github.com/b00t0x)** —— [CpuTopologyRebuild](https://github.com/b00t0x/CpuTopologyRebuild)
- **joedm** —— SMCSuperIO
- **RehabMan** —— XHCI-unsupported
- **[corpnewt](https://github.com/corpnewt)** —— [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS)

**驱动底层**

- **[Mesa](https://gitlab.freedesktop.org/mesa/mesa)** 的 **NVK** 与 **NAK** 编译器
- **metal2vulkan** —— 着色器翻译器（`libnvmtl_translate.dylib`）的基础
- **NVIDIA** —— `open-gpu-kernel-modules` r610 与 GSP 固件

**文档与工具**

- **[lzhoang2801](https://github.com/lzhoang2801)** —— [OpCore-Simplify](https://github.com/lzhoang2801/OpCore-Simplify)（1401 的配置生成引擎）
- NullMoth Discord 社区里各位报告者与验证者

---

## 许可

- 本仓库的 OpenCore 配置：个人配置备份，仅供参考。
- 1401 / NullMoth 驱动：**PolyForm Noncommercial License 1.0.0**，免费但**禁止任何商业用途**；翻译器为 LGPL-3.0，NVK 部分为 Mesa (MIT)。
- `IOSkywalkFamily.kext` / `IO80211FamilyLegacy.kext` / `AirPortBrcmNIC-Tahoe.kext` 来自 **OpenCore Legacy Patcher**（遵循其自身许可）。
- NullMoth 名称与飞蛾 logo 属 NullMoth Systems，不在许可范围内。
