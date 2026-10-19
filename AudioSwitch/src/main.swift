import Cocoa
import CoreAudio
import ServiceManagement

// MARK: - CoreAudio 辅助

struct AudioDev {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let index: Int        // UID 里的引擎序号
    let isInput: Bool
}

func propString(_ obj: AudioObjectID, _ sel: AudioObjectPropertySelector) -> String {
    var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var size = UInt32(MemoryLayout<CFString?>.size)
    var cf: CFString? = nil
    let st = withUnsafeMutablePointer(to: &cf) { p -> OSStatus in
        AudioObjectGetPropertyData(obj, &addr, 0, nil, &size, p)
    }
    return (st == noErr && cf != nil) ? (cf! as String) : ""
}

func channels(_ dev: AudioDeviceID, _ scope: AudioObjectPropertyScope) -> Int {
    var a = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    var s: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(dev, &a, 0, nil, &s) == noErr, s > 0 else { return 0 }
    let buf = UnsafeMutableRawPointer.allocate(byteCount: Int(s), alignment: 16)
    defer { buf.deallocate() }
    guard AudioObjectGetPropertyData(dev, &a, 0, nil, &s, buf) == noErr else { return 0 }
    var total = 0
    for b in UnsafeMutableAudioBufferListPointer(buf.assumingMemoryBound(to: AudioBufferList.self)) {
        total += Int(b.mNumberChannels)
    }
    return total
}

/// UID 形如 AppleHDAEngineInput:1F,3,0,1,0:3 —— 倒数第一个逗号后的数字是引擎序号
func engineIndex(from uid: String) -> Int {
    guard let colon = uid.firstIndex(of: ":") else { return -1 }
    let body = uid[uid.index(after: colon)...]
    let firstField = body.split(separator: ":").first.map(String.init) ?? ""
    let parts = firstField.split(separator: ",")
    guard let last = parts.last, let v = Int(last) else { return -1 }
    return v
}

func allAudioDevices() -> [AudioDev] {
    var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var size: UInt32 = 0
    AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size)
    var devs = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &devs)

    var result: [AudioDev] = []
    for d in devs {
        let uid = propString(d, kAudioDevicePropertyDeviceUID)
        let name = propString(d, kAudioObjectPropertyName)
        let idx = engineIndex(from: uid)
        if channels(d, kAudioObjectPropertyScopeOutput) > 0 {
            result.append(AudioDev(id: d, name: name, uid: uid, index: idx, isInput: false))
        }
        if channels(d, kAudioObjectPropertyScopeInput) > 0 {
            result.append(AudioDev(id: d, name: name, uid: uid, index: idx, isInput: true))
        }
    }
    return result
}

func defaultDevice(_ input: Bool) -> AudioDeviceID {
    let sel = input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
    var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var dev = AudioDeviceID(0)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev)
    return dev
}

func setDefault(_ dev: AudioDeviceID, input: Bool) -> Bool {
    let sel = input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
    var addr = AudioObjectPropertyAddress(mSelector: sel, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var d = dev
    return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &d) == noErr
}

// MARK: - 面板丝印映射（按 codec 引擎序号）

/// 本机 ALC897：输入 0=0x18 后置粉、1=0x19 前置粉、2=0x1a 蓝；
/// 输出 3=0x14 后置绿、4=0x1b 前置耳机、5=0x1e 光纤
/// 返回：(中文名, 方向符号, 接口名, 颜色)
///
/// 用 → / ← 代替 OUT / IN 当方向标记，因为它们在系统字体里 **advance 完全相同（10.45pt）**：
/// 符号本身宽度一致 ⇒ 符号列对齐、后面的接口名起点也一致，
/// 于是「符号对齐 + 接口名对齐」两件事在**比例字体**下同时成立。
/// 直接写 "LINE OUT" / "MIC IN" 做不到——两个词的宽度差 24pt，怎么调 tab 都会歪。
func panelColumns(index: Int, isInput: Bool) -> (String, String, String, String)? {
    if isInput {
        switch index {
        case 0: return ("后置话筒", "←", "MIC", "粉")
        case 1: return ("前置话筒", "←", "MIC", "粉")
        case 2: return ("线路输入", "←", "LINE", "蓝")
        default: return nil
        }
    } else {
        switch index {
        case 3: return ("线路输出", "→", "LINE", "绿")
        case 4: return ("前置耳机", "→", "HP", "绿")
        case 5: return ("光纤输出", "→", "SPDIF", "光纤")
        default: return nil
        }
    }
}

func panelLabel(index: Int, isInput: Bool) -> String? {
    guard let c = panelColumns(index: index, isInput: isInput) else { return nil }
    return c.0
}

/// 菜单里的显示顺序：前置优先
func sortRank(index: Int, isInput: Bool) -> Int {
    if isInput {
        switch index {
        case 1: return 0        // 前置话筒
        case 0: return 1        // 后置话筒
        case 2: return 2        // 线路输入
        default: return 99
        }
    } else {
        switch index {
        case 4: return 0        // 前置耳机
        case 3: return 1        // 线路输出
        case 5: return 2        // 光纤输出
        default: return 99
        }
    }
}

// 三栏的 tab 停靠位（点）
//   66 = 方向符号（← / → 宽度恒定）
//   84 = 接口名（LINE / SPDIF / MIC）
//  128 = 颜色
// ★ defaultTabInterval 必须是 0：设成非 0 会生成额外的隐式停靠位，
//   把后面几列顶到画布外（实测宽度从 151 变成 264）
let kArrowX: CGFloat = 66
let kConnX: CGFloat  = 84
let kColorX: CGFloat = 128

/// 颜色字用真实颜色渲染，不用读就知道是哪个口
func jackColor(_ c: String) -> NSColor {
    switch c {
    case "绿":   return NSColor(srgbRed: 0.13, green: 0.62, blue: 0.24, alpha: 1)
    case "粉":   return NSColor(srgbRed: 0.85, green: 0.28, blue: 0.55, alpha: 1)
    case "蓝":   return NSColor(srgbRed: 0.11, green: 0.44, blue: 0.85, alpha: 1)
    default:    return NSColor.secondaryLabelColor
    }
}

/// 中文 13pt 主色 / 方向符号 11.5pt 三级灰 / 接口名 11.5pt 次要灰 / 颜色字用插孔真实颜色
func alignedTitle(_ cn: String, _ arrow: String, _ conn: String, _ color: String) -> NSAttributedString {
    let style = NSMutableParagraphStyle()
    style.tabStops = [NSTextTab(textAlignment: .left, location: kArrowX),
                      NSTextTab(textAlignment: .left, location: kConnX),
                      NSTextTab(textAlignment: .left, location: kColorX)]
    style.defaultTabInterval = 0

    let s = NSMutableAttributedString()
    s.append(NSAttributedString(string: cn, attributes: [
        .font: NSFont.systemFont(ofSize: 13),
        .foregroundColor: NSColor.labelColor,
        .paragraphStyle: style]))
    s.append(NSAttributedString(string: "\t" + arrow, attributes: [
        .font: NSFont.systemFont(ofSize: 11.5),
        .foregroundColor: NSColor.tertiaryLabelColor,
        .paragraphStyle: style]))
    s.append(NSAttributedString(string: "\t" + conn, attributes: [
        .font: NSFont.systemFont(ofSize: 11.5),
        .foregroundColor: NSColor.secondaryLabelColor,
        .paragraphStyle: style]))
    s.append(NSAttributedString(string: "\t" + color, attributes: [
        .font: NSFont.systemFont(ofSize: 12),
        .foregroundColor: jackColor(color),
        .paragraphStyle: style]))
    return s
}

/// tooltip：中文全称 + 颜色 + 位置
func panelHint(index: Int, isInput: Bool) -> String {
    if isInput {
        switch index {
        case 0: return "后置麦克风 · 粉色 3.5mm 插孔"
        case 1: return "前置麦克风 · 粉色 3.5mm 插孔"
        case 2: return "后置线路输入 · 蓝色 3.5mm 插孔"
        default: return ""
        }
    } else {
        switch index {
        case 3: return "后置线路输出 · 绿色 3.5mm 插孔"
        case 4: return "前置耳机 · 绿色 3.5mm 插孔"
        case 5: return "光纤数字输出 · 方口"
        default: return ""
        }
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    let menu = NSMenu()
    var vrefTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // 菜单栏图标：SF Symbol 取系统标准尺寸（WiFi/蓝牙同规格），
        // 模板图模式让系统按菜单栏明暗自动着色
        let symCfg = NSImage.SymbolConfiguration(pointSize: 14.5, weight: .semibold)
        if let img = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "音频切换")?
            .withSymbolConfiguration(symCfg) {
            img.isTemplate = true          // 模板图：随菜单栏明暗自动反色，符合系统风格
            statusItem.button?.image = img
        } else {
            statusItem.button?.title = "音频"
        }
        statusItem.button?.toolTip = "音频输出 / 输入切换"

        menu.delegate = self
        statusItem.menu = menu

        applyFrontMicVref()
        // 每 120 秒补一次前置麦克风偏置（AppleHDA 会覆盖）
        vrefTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.applyFrontMicVref(silent: true)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    func rebuildMenu() {
        menu.removeAllItems()
        let devs = allAudioDevices()
        let curOut = defaultDevice(false)
        let curIn = defaultDevice(true)

        menu.addItem(header("输出设备"))
        for d in devs.filter({ !$0.isInput }).sorted(by: { sortRank(index: $0.index, isInput: false) < sortRank(index: $1.index, isInput: false) }) {
            menu.addItem(deviceItem(d, current: curOut))
        }

        menu.addItem(.separator())
        menu.addItem(header("输入设备"))
        for d in devs.filter({ $0.isInput }).sorted(by: { sortRank(index: $0.index, isInput: true) < sortRank(index: $1.index, isInput: true) }) {
            menu.addItem(deviceItem(d, current: curIn))
        }

        menu.addItem(.separator())
        let open = NSMenuItem(title: "声音设置…", action: #selector(openSoundPrefs), keyEquivalent: "")
        open.target = self
        open.image = nil
        menu.addItem(open)

        let auto = NSMenuItem(title: "登录时启动", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        auto.target = self
        auto.image = nil
        auto.state = isLaunchAtLoginEnabled() ? .on : .off
        auto.toolTip = "开机后自动运行 AudioSwitch（在系统设置 → 通用 → 登录项 里可见）"
        menu.addItem(auto)

        menu.addItem(.separator())
        // 用自己的 action，避免系统给标准 terminate 项加图标
        let quit = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "")
        quit.target = self
        quit.image = nil
        menu.addItem(quit)
    }

    // MARK: - 开机自启动（SMAppService，macOS 13+ 官方 API）

    func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    @objc func toggleLaunchAtLogin() {
        guard #available(macOS 13.0, *) else {
            showAlert("需要 macOS 13 或更高版本", "SMAppService 在 macOS 12 及更早不可用。")
            return
        }
        let svc = SMAppService.mainApp
        do {
            if svc.status == .enabled {
                try svc.unregister()
            } else {
                try svc.register()
            }
        } catch {
            showAlert("设置失败", error.localizedDescription)
        }
        rebuildMenu()
    }

    func showAlert(_ title: String, _ msg: String) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = msg
        a.alertStyle = .warning
        a.runModal()
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    private func header(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.image = nil
        // 标题加深、放大：13pt 粗体 + 主文本色（不再用次要灰）
        item.attributedTitle = NSAttributedString(
            string: text,
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .bold),
                         .foregroundColor: NSColor.labelColor])
        return item
    }

    private func deviceItem(_ d: AudioDev, current: AudioDeviceID) -> NSMenuItem {
        let item = NSMenuItem(title: d.name, action: #selector(selectDevice(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = ["id": Int(d.id), "input": d.isInput]
        item.state = (d.id == current) ? .on : .off
        item.image = nil                     // 不要前置图标，只用勾选标记

        // 三栏对齐：中文 / 英文丝印 / 颜色
        if let c = panelColumns(index: d.index, isInput: d.isInput) {
            item.attributedTitle = alignedTitle(c.0, c.1, c.2, c.3)
        }
        let hint = panelHint(index: d.index, isInput: d.isInput)
        item.toolTip = (hint.isEmpty ? "" : hint + "　") + d.name
        return item
    }

    @objc func selectDevice(_ sender: NSMenuItem) {
        guard let info = sender.representedObject as? [String: Any],
              let raw = info["id"] as? Int,
              let isInput = info["input"] as? Bool else { return }
        _ = setDefault(AudioDeviceID(raw), input: isInput)
        if isInput {
            // 切换输入后 AppleHDA 会重配引脚，VREF 会被冲掉 —— 立刻补一次
            applyFrontMicVref(silent: true)
        }
        rebuildMenu()
    }

    @objc func openSoundPrefs() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 给前置麦克风（0x19）补 VREF 80%
    func applyFrontMicVref(silent: Bool = false) {
        guard let helper = Bundle.main.path(forResource: "alc-verb", ofType: nil) else {
            if !silent { NSLog("alc-verb 未打包进 app") }
            return
        }
        let read = Process()
        read.executableURL = URL(fileURLWithPath: helper)
        read.arguments = ["0x19", "0xF07", "0x00"]
        let pipe = Pipe()
        read.standardOutput = pipe
        read.standardError = FileHandle.nullDevice
        do { try read.run() } catch { return }
        read.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if out.contains("0x00000024") { return }   // 已经是 IN + VREF 80%

        let set = Process()
        set.executableURL = URL(fileURLWithPath: helper)
        set.arguments = ["0x19", "0x707", "0x24"]
        set.standardOutput = FileHandle.nullDevice
        set.standardError = FileHandle.nullDevice
        do { try set.run() } catch { return }
        set.waitUntilExit()
        if !silent { NSLog("已为前置麦克风补 VREF 80%") }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)      // 只在菜单栏，不占 Dock
let delegate = AppDelegate()
app.delegate = delegate

// 开机自启动的 CLI 控制（SMAppService 需要 app 在稳定位置，如 /Applications）
if CommandLine.arguments.contains("--autostart-status") {
    if #available(macOS 13.0, *) {
        print("开机自启动: \(SMAppService.mainApp.status == .enabled ? "已开启" : "未开启")  (\(SMAppService.mainApp.status))")
    } else {
        print("开机自启动: 需要 macOS 13+")
    }
    exit(0)
}
if CommandLine.arguments.contains("--enable-autostart") {
    guard #available(macOS 13.0, *) else { print("需要 macOS 13+"); exit(1) }
    do { try SMAppService.mainApp.register(); print("开机自启动已开启") }
    catch { print("开启失败: \(error.localizedDescription)"); exit(1) }
    exit(0)
}
if CommandLine.arguments.contains("--disable-autostart") {
    guard #available(macOS 13.0, *) else { print("需要 macOS 13+"); exit(1) }
    do { try SMAppService.mainApp.unregister(); print("开机自启动已关闭") }
    catch { print("关闭失败: \(error.localizedDescription)"); exit(1) }
    exit(0)
}

// --dump：不启动界面，只打印菜单会显示的内容（用于核对名称映射）
if CommandLine.arguments.contains("--dump") {
    let devs = allAudioDevices()
    let curOut = defaultDevice(false)
    let curIn = defaultDevice(true)
    func line(_ d: AudioDev, _ cur: AudioDeviceID) -> String {
        let mark = d.id == cur ? "●" : "○"
        guard let c = panelColumns(index: d.index, isInput: d.isInput) else {
            return "  \(mark) \(d.name)  [idx=\(d.index)]"
        }
        let enFull = c.1.isEmpty ? "" : c.1 + " " + c.2
        return "  \(mark) \(c.0.padding(toLength: 14, withPad: " ", startingAt: 0))"
             + "\(enFull.padding(toLength: 14, withPad: " ", startingAt: 0))\(c.3)"
    }
    print("输出设备（当前默认 id=\(curOut)）")
    for d in devs.filter({ !$0.isInput }).sorted(by: { sortRank(index: $0.index, isInput: false) < sortRank(index: $1.index, isInput: false) }) { print(line(d, curOut)) }
    print("输入设备（当前默认 id=\(curIn)）")
    for d in devs.filter({ $0.isInput }).sorted(by: { sortRank(index: $0.index, isInput: true) < sortRank(index: $1.index, isInput: true) }) { print(line(d, curIn)) }
    exit(0)
}

app.run()
