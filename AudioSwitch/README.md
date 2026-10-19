# AudioSwitch

菜单栏音频切换工具，为 ASUS TUF Z690-PLUS WIFI D4 的板载 ALC897 写的，
但 CoreAudio 部分通用，只改 `panelColumns()` / `sortRank()` 里的映射即可用于其他机器。

需要 **macOS 13+**（登录自启动走 `SMAppService`）。

## 功能

- 点菜单栏图标即切默认输出 / 输入
- 四栏对齐：`中文名 · 方向符号 · 接口名 · 颜色`，颜色字用插孔真实颜色渲染
  - 方向符号用 `←` / `→` 而不是 `IN` / `OUT`：两者在系统字体里 advance 完全相同（10.45pt），
    比例字体下符号列和接口名才能同时对齐（`LINE OUT` 与 `MIC IN` 宽度差 24pt，怎么调 tab 都歪）
- 每 120 秒补一次前置麦克风 VREF 80%（AppleHDA 只给第一个麦克风引脚加偏置）
- 「登录时启动」菜单项（`SMAppService.mainApp`，macOS 13+ 官方 API）

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

## 命令行

```bash
AudioSwitch --dump                # 只打印菜单会显示的内容，核对名称映射用
AudioSwitch --autostart-status    # 查登录项状态
AudioSwitch --enable-autostart    # 开登录自启动（等价于菜单里勾选）
AudioSwitch --disable-autostart   # 关
```

> `SMAppService` 要求 app 在稳定路径（`/Applications`）；从 `~/Downloads` 里直接跑注册会失败。

## 结构

```
src/main.swift      全部逻辑（约 440 行）
src/Info.plist      LSUIElement = true（不占 Dock），LSMinimumSystemVersion = 13.0
build-audiobar.sh   编译 + 打包 + ad-hoc 签名
make-icon.swift     Core Graphics 画图标
preview-menu.swift  渲染菜单预览图（改 tab 停靠位时先用它看效果）
AppIcon.icns        图标
```

## 名称映射

按设备 UID 里的引擎序号（`AppleHDAEngineInput:1F,3,0,1,<idx>:n` 的 `<idx>`）：

```
输入 0 = 后置话筒 ← MIC  粉      输出 3 = 线路输出 → LINE  绿
输入 1 = 前置话筒 ← MIC  粉      输出 4 = 前置耳机 → HP    绿
输入 2 = 线路输入 ← LINE 蓝      输出 5 = 光纤输出 → SPDIF 光纤
```

## 对齐参数

```swift
let kArrowX: CGFloat = 66     // 方向符号
let kConnX:  CGFloat = 84     // 接口名
let kColorX: CGFloat = 128    // 颜色
style.defaultTabInterval = 0  // 必须为 0，非 0 会生成隐式停靠位把后面几列顶出画布
```
