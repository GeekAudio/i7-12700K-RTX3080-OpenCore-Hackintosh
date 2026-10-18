# AudioSwitch

菜单栏音频切换工具，为 ASUS TUF Z690-PLUS WIFI D4 的板载 ALC897 写的，
但 CoreAudio 部分通用，只改 `panelColumns()` / `sortRank()` 里的映射即可用于其他机器。

## 功能

- 点菜单栏图标即切默认输出 / 输入
- 三栏对齐：`中文名 · 背板丝印英文 · 颜色`
- 每 120 秒补一次前置麦克风 VREF 80%（AppleHDA 只给第一个麦克风引脚加偏置）

## 构建

```bash
bash build-audiobar.sh
# 产出 AudioSwitch.app（含 alc-verb，自包含）
```

## 改图标

```bash
swift make-icon.swift .          # 生成 png + iconset
iconutil -c icns AudioSwitch.iconset -o AppIcon.icns
bash build-audiobar.sh
```

## 结构

```
src/main.swift      全部逻辑（约 280 行）
src/Info.plist      LSUIElement = true（不占 Dock）
build-audiobar.sh   编译 + 打包 + ad-hoc 签名
make-icon.swift     Core Graphics 画图标
preview-menu.swift  渲染菜单预览图（改 tab 停靠位时先用它看效果）
AppIcon.icns        图标
```

## 名称映射

按设备 UID 里的引擎序号（`AppleHDAEngineInput:1F,3,0,1,<idx>:n` 的 `<idx>`）：

```
输入 0 = 后置话筒 MIC IN 粉      输出 3 = 线路输出 LINE OUT 绿
输入 1 = 前置话筒 MIC IN 粉      输出 4 = 前置耳机          绿
输入 2 = 线路输入 LINE IN 蓝     输出 5 = 光纤输出 SPDIF OUT
```
