import Cocoa

// 生成 macOS 风格 App 图标（squircle + 渐变 + SF Symbol 字形）
// 用法：swift tools/make-icon.swift <输出目录>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let S: CGFloat = 1024
let pad: CGFloat = 100                    // macOS 图标网格留白
let rect = CGRect(x: pad, y: pad, width: S - pad * 2, height: S - pad * 2)
let radius = rect.width * 0.2237          // Apple squircle 近似

func squircle(_ r: CGRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
}

func render(at px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let scale = CGFloat(px) / S
    ctx.scaleBy(x: scale, y: scale)

    // ---- 底色：纯白（不使用任何色相）----
    let path = squircle(rect, radius)
    ctx.saveGState()
    path.addClip()
    NSColor.white.setFill()
    path.fill()

    // 极淡的内阴影：只用黑色低透明度，给白底一点体积感（不引入色相）
    let shade = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [NSColor(white: 0, alpha: 0.10).cgColor,
                                    NSColor(white: 0, alpha: 0.0).cgColor] as CFArray,
                           locations: [0, 0.42])!
    ctx.drawLinearGradient(shade,
                           start: CGPoint(x: rect.midX, y: rect.minY),
                           end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
    ctx.restoreGState()

    // ---- 内描边：极淡，定义边缘 ----
    ctx.saveGState()
    let inner = squircle(rect.insetBy(dx: 3, dy: 3), radius - 3)
    NSColor(white: 0, alpha: 0.09).setStroke()
    inner.lineWidth = 6
    inner.stroke()
    ctx.restoreGState()

    // ---- 字形：纯白，靠阴影与白底分层 ----
    let glyphSize: CGFloat = 520
    if let sym = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: nil)
        ?? NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: nil) {
        let cfg = NSImage.SymbolConfiguration(pointSize: glyphSize, weight: .bold)
        if let sized = sym.withSymbolConfiguration(cfg) {
            // 模板图必须自己上色：画进离屏图后用 sourceIn 填充白色
            let tinted = NSImage(size: sized.size, flipped: false) { r in
                sized.draw(in: r)
                NSColor.white.set()
                r.fill(using: .sourceIn)
                return true
            }
            let gw = tinted.size.width, gh = tinted.size.height
            let target = CGRect(x: rect.midX - gw / 2, y: rect.midY - gh / 2, width: gw, height: gh)

            // 先画一层柔和投影（黑色低透明度），让纯白字形在白底上立起来
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 34,
                          color: NSColor(white: 0, alpha: 0.30).cgColor)
            tinted.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1.0)
            ctx.restoreGState()

            // 再叠一层近距离细影，强化轮廓
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 6,
                          color: NSColor(white: 0, alpha: 0.22).cgColor)
            tinted.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1.0)
            ctx.restoreGState()
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let master = render(at: 1024)
let png = master.representation(using: .png, properties: [:])!
let masterURL = URL(fileURLWithPath: outDir).appendingPathComponent("icon-1024.png")
try! png.write(to: masterURL)
print("已生成 \(masterURL.path)")

// ---- 生成 iconset ----
let iconset = URL(fileURLWithPath: outDir).appendingPathComponent("AudioSwitch.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let spec: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]

let masterImage = NSImage(data: png)!
for (name, px) in spec {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current!.imageInterpolation = .high
    masterImage.draw(in: NSRect(x: 0, y: 0, width: px, height: px),
                     from: .zero, operation: .copy, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: iconset.appendingPathComponent(name))
}
print("iconset 已生成：\(iconset.path)")
