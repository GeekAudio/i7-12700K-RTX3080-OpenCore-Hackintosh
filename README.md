# ASUS TUF GAMING Z690-PLUS WIFI D4 + i7-12700K + RTX 3080 — OpenCore EFI

一台 Alder Lake + NVIDIA RTX 3080 黑苹果的 OpenCore EFI 备份，SMBIOS 为 **iMacPro1,1**，系统 **macOS 15.8.1 (24H32)**。
显卡由 **NullMoth NVIDIA 驱动 1.14.2** 驱动（Turing 及以后），核显无驱动、已屏蔽；无线改用 **Broadcom BCM943602CDP**。

> ⚠️ **序列号已脱敏**：`config.plist` 中的 `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` 已替换为随机占位值。
> 使用前请用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 生成属于你自己的 **iMacPro1,1** 三码，
> 否则 iMessage / FaceTime / iCloud 无法激活，也可能与他人冲突。

> ⚠️ **本 EFI 是「驱动装好之后」的运行配置，不是装机配置。**
> 它使用大 BAR（`ResizeGpuBars = 13`）并且排除了 `IONDRVSupport` —— 这两项会让**没有 NVIDIA 驱动**的 macOS 安装器黑屏。
> 全新安装请走下面的 **1401 流程**（1401 会为安装器自动生成小 BAR 的配置）。

---

## 一、硬件配置

| 部件 | 型号 | 驱动 / 说明 |
|---|---|---|
| CPU | Intel Core i7-12700K (Alder Lake, 8P+4E) | `SSDT-PLUG-MADT.aml` |
| 主板 | **ASUS TUF GAMING Z690-PLUS WIFI D4** | BIOS 中 **ReBAR 已开启**、Above 4G Decoding ON、CSM OFF |
| 内存 | 32 GB DDR4 | — |
| 显卡 | NVIDIA GeForce RTX 3080 10 GB (`10de:2206`) | **NullMoth NVIDIA 驱动 1.14.2**；BAR1 = 8 GB |
| 核显 | Intel UHD 770 (`8086:4680`) | **无驱动，`-wegnoigpu` 屏蔽** |
| 有线网卡 | Intel I225-V 2.5GbE | `AppleIGC.kext` |
| 无线 / 蓝牙 | **Broadcom BCM943602CDP**（Wi-Fi `14e4:43ba` / 蓝牙 BCM20703，USB） | `IO80211FamilyLegacy` + `AirPortBrcmNIC` + `BlueToolFixup`（**需 OCLP 根补丁**，见 §九） |
| 存储 | NVMe | `NVMeFix.kext` |
| 显示器 | 1920×1080 @ 60 Hz | 建议 60 Hz |
| 系统 | macOS 15.8.1 (24H32) | OpenCore 1.0.8 RELEASE |

> **原装 Intel Wi-Fi 6 AX201 已弃用**（Intel 网卡做不了 AirDrop / 接力 / 通用剪贴板 / Apple Watch 解锁 —— 缺 AWDL）。
> 相关的 `itlwm` / `IntelBluetoothFirmware` / `IntelBTPatcher` 三个 kext 仍留在 `Kexts/` 里，但**已禁用**。

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
| `UEFI → Quirks → ResizeGpuBars` | `13` | 8 GB BAR，完整显存带宽 |
| `Booter → Quirks → ResizeAppleGpuBars` | `-1` | 让 macOS 看到完整 BAR |
| `Kernel → Block` | `com.apple.iokit.IONDRVSupport`，Strategy `Exclude` | 否则固件帧缓冲会抢走 NVRMFB 的显示 index 0 |
| `Misc → Security → SecureBootModel` | `Disabled` | Apple Secure Boot 会拒绝非 Apple 签名的 kext |
| `Misc → Security → ExposeSensitiveData` | `7` | 让 1401 Mac app 能确认 OpenCore 是从哪个分区启动的（7 而非 15，刻意不含 OEM 信息） |

### 还必须满足

- **BIOS**：Above 4G Decoding ON、CSM OFF
- **SMBIOS**：能跑 macOS 15 且用独显的机型（已测试：`iMacPro1,1`）
- **删掉** `nv_disable=1`、WhateverGreen 的 NVIDIA patch、`agdpmod=pikera`
- NVIDIA 卡**不需要** `DeviceProperties`

---

## 五、boot-args（本仓库当前值）

```
-v amfi_get_out_of_my_way=0x1 amfi=0x80 -wegnoigpu nvrmsettle=1500 nvfbsample=1 ipc_control_port_options=0 nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth
```

| 参数 | 作用 |
|---|---|
| `nvfb=1 nvaccel=1 nvfbheads=4` | NullMoth 驱动：帧缓冲 / 加速 / 4 个显示头 |
| `-nvkmsnosmooth` | 关闭 KMS 平滑 |
| `amfi_get_out_of_my_way=0x1 amfi=0x80` | 让 WindowServer 能加载驱动 bundle（配合 AMFIPass） |
| `ipc_control_port_options=0` | 配合上面的 AMFI 参数；**缺了它**，加固过的应用（Firefox / Chromium 系）会在启动时因任务控制端口被杀 |
| `-wegnoigpu` | WhateverGreen：屏蔽无驱动的 Intel 核显 |
| `nvrmsettle=1500` | 驱动 settle 时间；**必须保留**，否则 ReBAR 关闭时开机会卡 2 分钟 |
| `nvfbsample=1` | 诊断用：每 10 s 校验一次帧缓冲 |
| `-v` | 详细启动日志 |

> 上游驱动文档的推荐串为：`nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0`
> —— 本机串与之等价（多了 `-v` / `-wegnoigpu` / `nvrmsettle=1500` / `nvfbsample=1` 四项本机必需的）。

---

## 六、Kexts

### 已启用

| Kext | 版本 | 来源 |
|---|---|---|
| Lilu | 1.7.3 | acidanthera |
| VirtualSMC | 1.3.9 | acidanthera |
| SMCProcessor | 1.3.9 | acidanthera |
| SMCSuperIO | 1.3.9 | joedm |
| WhateverGreen | 1.7.2 | acidanthera |
| AppleIGC | 1.9d2 | sxx |
| NVMeFix | 1.1.4 | acidanthera |
| RestrictEvents | 1.1.7 | acidanthera |
| USBToolBox | 1.2.0 | dhinakg |
| XHCI-unsupported | 0.9.2 | RehabMan |
| UTBMap | 1.1 | dhinakg |
| AMFIPass | 1.4.1 | dhinakg |
| BlueToolFixup | 2.7.3 | acidanthera |
| **IOSkywalkFamily** | 1.0 | **OCLP**（必须排在 IO80211FamilyLegacy 之前加载） |
| **IO80211FamilyLegacy** | 12.0 | **OCLP**（内含 `AirPortBrcmNIC.kext`，BCM43602 驱动） |

> **注意**：NullMoth 驱动的 4 个 kext（NVRM / NVAccel / NVRMFB / NVRMAGDC）**不在这里**，
> 它们装在 `/Library/Extensions`，由 Auxiliary Kernel Collection 加载。

### 已放置但**禁用**（`Enabled = false`）

| Kext | 版本 | 说明 |
|---|---|---|
| AppleALC | 1.9.9 | 板载音频，本机为排查隔离而禁用 |
| itlwm | 2.3.0 | Intel 无线（已换 Broadcom，不再需要） |
| IntelBluetoothFirmware | 2.5.0 | Intel 蓝牙（同上） |
| IntelBTPatcher | 2.5.0 | Intel 蓝牙（同上） |
| CpuTopologyRebuild | 2.0.2 | **本机启用会开不了机，务必保持禁用** |

## 七、Drivers / ACPI / Tools

- **Drivers**：`OpenRuntime.efi`、`OpenHfsPlus.efi`、`ResetNvramEntry.efi`、`OpenCanopy.efi`、**`NullMothLogo.efi`**
- **ACPI**（启用 4 个）：`SSDT-EC.aml`、`SSDT-PLUG-MADT.aml`、`SSDT-RTCAWAC.aml`、`SSDT-USBX.aml`（`SSDT-SBUS-MCHC.aml` 存在但**禁用**）
- **Tools**：`OpenShell.efi`、`NullMothSafe.efi` ×2 条 —— 分别对应启动菜单里的
  **「NullMoth: remove the NVIDIA driver at the next start」** 与 **「NullMoth: start macOS once without the NVIDIA driver」**（救援入口）

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
- `Kernel → Add` 新增 `IOSkywalkFamily` 与 `IO80211FamilyLegacy`（内含 `AirPortBrcmNIC.kext`）—— **顺序不能反**
- `Kernel → Block` 屏蔽 `com.apple.iokit.IOSkywalkFamily`（让 OCLP 的版本生效）
- 启用 `BlueToolFixup`
- `NVRAM` 新增 `bluetoothExternalDongleFailed` / `bluetoothInternalControllerInfo`

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
| **USB3 拿不到** | 🟡 已接受 | Sequoia 下本机 USB3 无解（15 端口上限 + 端口图铁律）。现状用 T3 图：后置 6×USB-A + 2×Type-C **全部可用，但只有 USB2 速率** |
| ~~蓝牙同步调用死锁~~ | ✅ **已解决** | 原 `IOBluetoothFamily` 被屏蔽但 `bluetoothd` 在跑 ⇒ 同步 XPC 永久等待，严重时连 USB 输入一起卡死。**换 BCM943602CDP 后根除** |
| ~~mediaanalysisd 崩溃~~ | ✅ **已修** | 驱动 1.14.0 起不再出现 |

- 显示器**建议使用 60 Hz**，但**不要**把这些现象归因于 50 Hz —— 它们是驱动侧（NVIDIA 显示 / 合成路径）的问题。
- 上游问题跟踪：<https://github.com/nullmoth/nvidia-macos-driver/issues>

## 十二、更新日志

| 日期 | 变更 |
|---|---|
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
- `IOSkywalkFamily.kext` / `IO80211FamilyLegacy.kext` 来自 **OpenCore Legacy Patcher**（遵循其自身许可）。
- NullMoth 名称与飞蛾 logo 属 NullMoth Systems，不在许可范围内。
