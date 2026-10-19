import Cocoa

// 把菜单项的三栏标题渲染成图片，用来核对对齐效果（与 app 用同一套字体/tab 停靠位）

let rows: [(String, String, String, String, Bool)] = [
    ("输出设备", "", "", "", true),
    ("前置耳机", "", "", "绿", false),
    ("线路输出", "LINE", "OUT", "绿", false),
    ("光纤输出", "SPDIF", "OUT", "光纤", false),
    ("输入设备", "", "", "", true),
    ("前置话筒", "MIC", "IN", "粉", false),
    ("后置话筒", "MIC", "IN", "粉", false),
    ("线路输入", "LINE", "IN", "蓝", false),
]

let tab1: CGFloat = 102
let tab1b: CGFloat = 110
let tab2: CGFloat = 146
let rowH: CGFloat = 26
let pad: CGFloat = 18

func jackColor(_ c: String) -> NSColor {
    switch c {
    case "绿":   return NSColor(srgbRed: 0.13, green: 0.62, blue: 0.24, alpha: 1)
    case "粉":   return NSColor(srgbRed: 0.85, green: 0.28, blue: 0.55, alpha: 1)
    case "蓝":   return NSColor(srgbRed: 0.11, green: 0.44, blue: 0.85, alpha: 1)
    default:     return NSColor.secondaryLabelColor
    }
}

func title(_ cn: String, _ en: String, _ kw: String, _ color: String) -> NSAttributedString {
    let style = NSMutableParagraphStyle()
    style.tabStops = [NSTextTab(textAlignment: .right, location: tab1),
                      NSTextTab(textAlignment: .left, location: tab1b),
                      NSTextTab(textAlignment: .left, location: tab2)]
    style.defaultTabInterval = tab2
    let s = NSMutableAttributedString()
    s.append(NSAttributedString(string: cn, attributes: [
        .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor, .paragraphStyle: style]))
    s.append(NSAttributedString(string: "\t" + en, attributes: [
        .font: NSFont.systemFont(ofSize: 11.5), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: style]))
    s.append(NSAttributedString(string: "\t" + kw, attributes: [
        .font: NSFont.systemFont(ofSize: 11.5), .foregroundColor: NSColor.secondaryLabelColor, .paragraphStyle: style]))
    s.append(NSAttributedString(string: "\t" + color, attributes: [
        .font: NSFont.systemFont(ofSize: 12), .foregroundColor: jackColor(color), .paragraphStyle: style]))
    return s
}

let W: CGFloat = tab2 + 90
let H: CGFloat = rowH * CGFloat(rows.count) + pad * 2

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                           isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.windowBackgroundColor.setFill()
NSRect(x: 0, y: 0, width: W, height: H).fill()

var y = H - pad - rowH
for (cn, en, kw, color, isHeader) in rows {
    let str: NSAttributedString
    if isHeader {
        str = NSAttributedString(string: cn, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .bold),
            .foregroundColor: NSColor.labelColor])
    } else {
        str = title("● " + cn, en, kw, color)
    }
    str.draw(at: NSPoint(x: pad, y: y + 6))
    y -= rowH
}
NSGraphicsContext.restoreGraphicsState()

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "menu-preview.png"
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("已生成 \(out)")
