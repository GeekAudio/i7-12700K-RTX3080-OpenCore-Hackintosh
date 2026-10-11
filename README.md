# ASUS TUF GAMING Z690-PLUS WIFI D4 + i7-12700K + RTX 3080 — OpenCore EFI

一台 Alder Lake + NVIDIA RTX 3080 黑苹果的 OpenCore EFI 备份，SMBIOS 为 **iMacPro1,1**，系统 **macOS 15.8.1 (24H32)**。
显卡由 **NullMoth NVIDIA 驱动**驱动（Turing 及以后），核显无驱动、已屏蔽。

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
| 显卡 | NVIDIA GeForce RTX 3080 10 GB (`10de:2206`) | **NullMoth NVIDIA 驱动**；BAR1 = 8 GB |
| 核显 | Intel UHD 770 (`8086:4680`) | **无驱动，`-wegnoigpu` 屏蔽** |
| 有线网卡 | Intel I225-V 2.5GbE | `AppleIGC.kext` |
| 无线 / 蓝牙 | Intel Wi-Fi 6 AX201 | `itlwm` + `IntelBluetoothFirmware`（**当前禁用**） |
| 存储 | NVMe | `NVMeFix.kext` |
| 显示器 | 1920×1080 @ 60 Hz | 50 Hz 会黑屏 |
| 系统 | macOS 15.8.1 (24H32) | OpenCore 1.0.8 RELEASE |

---

## 二、相关仓库与驱动引用

| 项目 | 仓库 | 用途 |
|---|---|---|
| **1401** | https://github.com/nullmoth/1401 | **装机主线工具**：在 Windows 上检测硬件、生成 OpenCore 配置、制作 macOS 安装 U 盘 |
| **NullMoth NVIDIA 驱动** | https://github.com/nullmoth/nvidia-macos-driver | RTX 3080 的 Metal / 显示驱动（kexts + NVMTLDriver.bundle） |
| 1401 驱动发布页 | [nvidia-macos-driver Releases](https://github.com/nullmoth/nvidia-macos-driver/releases) | `1401-Mac-<版本>.dmg`、`nullmoth-nvidia-<版本>.tar.gz` |
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
1. 打开 U 盘上的 `NullMoth` 文件夹，解压 `1401-Mac-1.0.18.zip` 并运行 **1401.app**；或直接下载 `1401-Mac-1.0.18.dmg`（驱动包就在镜像里，不用另外下）。
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
| `boot-args` | 见下 | 帧缓冲 + 加速 + 4 显示头；AMFI 参数让 WindowServer 能加载驱动 bundle |

> 你设置的每个键**都要同时加到 `NVRAM → Delete`**，保证每次启动都重写。

### 各项设置

| 位置 | 值 | 原因 |
|---|---|---|
| `UEFI → Quirks → ResizeGpuBars` | `13` | 8 GB BAR，完整显存带宽 |
| `Booter → Quirks → ResizeAppleGpuBars` | `-1` | 让 macOS 看到完整 BAR |
| `Kernel → Block` | `com.apple.iokit.IONDRVSupport`，Strategy `Exclude` | 否则固件帧缓冲会抢走 NVRMFB 的显示 index 0 |
| `Misc → Security → SecureBootModel` | `Disabled` | Apple Secure Boot 会拒绝非 Apple 签名的 kext |

### 还必须满足

- **BIOS**：Above 4G Decoding ON、CSM OFF
- **SMBIOS**：能跑 macOS 15 且用独显的机型（已测试：`iMacPro1,1`）
- **删掉** `nv_disable=1`、WhateverGreen 的 NVIDIA patch、`agdpmod=pikera`
- NVIDIA 卡**不需要** `DeviceProperties`

---

## 五、boot-args（本仓库当前值）

```
-v -nvkmsnosmooth nvfb=1 nvaccel=1 nvfbheads=4 amfi_get_out_of_my_way=0x1 amfi=0x80 -wegnoigpu nvrmsettle=1500 nvfbsample=1
```

| 参数 | 作用 |
|---|---|
| `nvfb=1 nvaccel=1 nvfbheads=4` | NullMoth 驱动：帧缓冲 / 加速 / 4 个显示头 |
| `-nvkmsnosmooth` | 关闭 KMS 平滑 |
| `amfi_get_out_of_my_way=0x1 amfi=0x80` | 让 WindowServer 能加载驱动 bundle（配合 AMFIPass） |
| `-wegnoigpu` | WhateverGreen：屏蔽无驱动的 Intel 核显 |
| `nvrmsettle=1500` | 驱动 settle 时间；**必须保留**，否则 ReBAR 关闭时开机会卡 2 分钟 |
| `nvfbsample=1` | 诊断用：每 10 s 校验一次帧缓冲 |
| `-v` | 详细启动日志 |

> 上游驱动文档的推荐值里还含 **`ipc_control_port_options=0`**（本机当前未加，可自行补上）。
> 完整推荐串：`nvfb=1 nvaccel=1 nvfbheads=4 -nvkmsnosmooth amfi_get_out_of_my_way=0x1 amfi=0x80 ipc_control_port_options=0`

---

## 六、Kexts

### 已启用

| Kext | 版本 |
|---|---|
| Lilu | 1.7.3 |
| VirtualSMC | 1.3.9 |
| SMCProcessor | 1.3.9 |
| SMCSuperIO | 1.3.9 |
| WhateverGreen | 1.7.2 |
| AppleIGC | 1.9d2 |
| NVMeFix | 1.1.4 |
| RestrictEvents | 1.1.7 |
| USBToolBox | 1.2.0 |
| XHCI-unsupported | 0.9.2 |
| UTBMap | 1.1 |
| AMFIPass | 1.4.1 |

> **注意**：NullMoth 驱动的 4 个 kext（NVRM / NVAccel / NVRMFB / NVRMAGDC）**不在这里**，
> 它们装在 `/Library/Extensions`，由 Auxiliary Kernel Collection 加载。

### 已放置但**禁用**（`Enabled = false`）

| Kext | 版本 | 说明 |
|---|---|---|
| AppleALC | 1.9.9 | 板载音频，本机为排查隔离而禁用 |
| itlwm | 2.3.0 | Intel 无线 |
| IntelBluetoothFirmware | 2.5.0 | Intel 蓝牙 |
| IntelBTPatcher | 2.5.0 | Intel 蓝牙 |
| BlueToolFixup | 2.7.3 | Intel 蓝牙 |
| CpuTopologyRebuild | 2.0.2 | **本机启用会开不了机，务必保持禁用** |

## 七、Drivers / ACPI / Tools

- **Drivers**：`OpenCanopy.efi`、`OpenHfsPlus.efi`、`OpenRuntime.efi`、`ResetNvramEntry.efi`
- **ACPI**：`SSDT-EC.aml`、`SSDT-PLUG-MADT.aml`、`SSDT-RTCAWAC.aml`、`SSDT-USBX.aml`、`SSDT-SBUS-MCHC.aml`
- **Tools**：`NullMothSafe.efi`、`OpenShell.efi`

## 八、Kernel → Block

```
com.apple.iokit.IONDRVSupport          ← 驱动要求 Exclude
com.apple.iokit.IOBluetoothFamily
com.apple.driver.IOBluetoothHIDDriver
com.apple.driver.AppleBluetoothModule
com.apple.driver.AppleBluetoothMultitouch
com.apple.iokit.IO80211Family
```

## 九、从源码构建驱动（可选）

需要 **Xcode 16**、**Rust (stable)**、**Meson/Ninja**，以及 NVIDIA `open-gpu-kernel-modules` 的 **tag `610.57.04`**。

```bash
build/build_xlate.sh                 # 翻译器 → libnvmtl_translate.dylib
RELEASE=1 build/build_plugin.sh      # 插件 → NVMTLDriver.bundle（RELEASE=1 会去掉全部诊断）
build/build263.sh                    # NVK：先把 nvk/nvk-macos.patch 打到 Mesa 17ca6174
build/accel_build.sh <src> <out>     # kexts
```

## 十、注意事项

1. **BAR1 大小**：本机主板 BIOS 的 **ReBAR 已开启**；`ResizeGpuBars = 13` 把 BAR 调到 8 GB。
   安装器阶段必须用小 BAR（`ResizeAppleGpuBars 0` / `ResizeGpuBars -1`），装完驱动再切回大 BAR —— 1401 会自动处理。
2. **SMBIOS `iMacPro1,1` 不在 macOS 26 Tahoe 支持列表**，升级 Tahoe 需换机型或 `-no_compat_check`。
3. 核显无驱动是刻意为之（本机只用独显）；若你的核显可用，请自行调整。
4. 保持 U 盘插着：OpenCore 在 U 盘上，它就是启动配置。在把引导迁到内置 EFI 并复核之前，别拔。

---

## 许可

- 本仓库的 OpenCore 配置：个人配置备份，仅供参考。
- 1401 / NullMoth 驱动：**PolyForm Noncommercial License 1.0.0**，免费但**禁止任何商业用途**；翻译器为 LGPL-3.0，NVK 部分为 Mesa (MIT)。
- NullMoth 名称与飞蛾 logo 属 NullMoth Systems，不在许可范围内。
