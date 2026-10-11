# i7-12700K + RTX 3080 — OpenCore EFI

一套可用的 OpenCore EFI，配置于 **iMacPro1,1** SMBIOS，搭配 **NVIDIA RTX 3080**（走 NullMoth 驱动）+ 无驱动 Intel 核显。

> ⚠️ **序列号已脱敏**：`config.plist` 中的 `SystemSerialNumber` / `MLB` / `SystemUUID` / `ROM` 已替换为随机占位值。
> 直接使用前请用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 生成属于你自己的 **iMacPro1,1** 三码，
> 否则 iMessage / FaceTime / iCloud 无法激活，也可能与他人冲突。

## 硬件配置

| 部件 | 型号 |
|---|---|
| CPU | Intel Core i7-12700K (Alder Lake, 8P+4E) |
| 主板 | LGA1700（未开启 ReBAR，显卡走 ReBAR BIOS 档） |
| 内存 | 32 GB |
| 显卡 | NVIDIA GeForce RTX 3080 10 GB (10de:2206)，BAR1 = 8 GB |
| 核显 | Intel UHD 770 (8086:4680) —— **无驱动，已用 `-wegnoigpu` 屏蔽** |
| 网卡 | Intel I225/I226 (AppleIGC) |
| 存储 | NVMe (NVMeFix) |
| 显示器 | 1920×1080 @ 60 Hz |
| 系统 | macOS 15.8.1 (24H32) |

## 软件版本

- **OpenCore 1.0.8 RELEASE**
- **NVIDIA 驱动**：NullMoth `nvidia-macos-driver`（本机 app 1.9.0 / 驱动 1.8.0）
  - 该驱动**不包含在本仓库内**，需自行从上游安装（kext 装到系统，不在 EFI 里）。

## Kexts

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

### 已放置但**禁用**（`Enabled = false`）
| Kext | 版本 | 说明 |
|---|---|---|
| AppleALC | 1.9.9 | 音频，本机为排查隔离而禁用 |
| itlwm | 2.3.0 | Intel 无线 |
| IntelBluetoothFirmware | 2.5.0 | Intel 蓝牙 |
| IntelBTPatcher | 2.5.0 | Intel 蓝牙 |
| BlueToolFixup | 2.7.3 | Intel 蓝牙 |
| CpuTopologyRebuild | 2.0.2 | 本机启用会开不了机，务必保持禁用 |

## Drivers
`OpenCanopy.efi`、`OpenHfsPlus.efi`、`OpenRuntime.efi`、`ResetNvramEntry.efi`

## ACPI
`SSDT-EC.aml`、`SSDT-PLUG-MADT.aml`、`SSDT-RTCAWAC.aml`、`SSDT-USBX.aml`、`SSDT-SBUS-MCHC.aml`

## Tools
`NullMothSafe.efi`、`OpenShell.efi`

## boot-args

```
-v -nvkmsnosmooth nvfb=1 nvaccel=1 nvfbheads=4 amfi_get_out_of_my_way=0x1 amfi=0x80 -wegnoigpu nvrmsettle=1500
```

- `-wegnoigpu` —— 屏蔽无驱动的 Intel 核显，消除启动时 IOGraphicsFamily 停顿。
- `nvfb=1 nvaccel=1 nvfbheads=4` —— NullMoth 驱动帧缓冲 / 加速 / 头数。
- `nvrmsettle=1500` —— 必须保留，否则 ReBAR 关闭时开机会卡 2 分钟。
- `amfi_get_out_of_my_way=0x1 amfi=0x80` —— 配合 AMFIPass。

## Kernel → Block
```
com.apple.iokit.IONDRVSupport
com.apple.iokit.IOBluetoothFamily
com.apple.driver.IOBluetoothHIDDriver
com.apple.driver.AppleBluetoothModule
com.apple.driver.AppleBluetoothMultitouch
com.apple.iokit.IO80211Family
```

## 关键 Quirks
- `UEFI → Quirks → ResizeGpuBars = 13`（8 GB BAR1）
- `Booter → Quirks → ResizeAppleGpuBars = -1`
- `Misc → Security → SecureBootModel = Disabled`
- `Misc → Boot → Timeout = 1`，PickerMode = External（OpenCanopy 主题）

## 注意事项

1. **BAR1 大小取决于显卡双 BIOS 拨杆**：ReBAR 档 → 8 GB（本配置目标）；原厂档 → 仅 256 MB。
2. 本配置的 SMBIOS 是 **iMacPro1,1**，**不在 macOS 26 Tahoe 支持列表**，升级 Tahoe 需换机型或 `-no_compat_check`。
3. 核显无驱动是刻意为之（该机只用独显）；若你的核显可用，请自行调整。

---

*本仓库为个人黑苹果配置备份，仅供参考。*
