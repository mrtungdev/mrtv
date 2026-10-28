// Vẽ biểu tượng Mr TV (nhận diện 2.0 · Cực quang) bằng CoreGraphics, không cần công cụ ngoài.
//   swift scripts/make-icons.swift
// Sinh: apple/MrTV/Assets.xcassets/AppIcon.appiconset/*.png và apple/MrTVInput/Resources/MenuIcon.pdf
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = root.appendingPathComponent("apple/MrTV/Assets.xcassets/AppIcon.appiconset")
let imkResources = root.appendingPathComponent("apple/MrTVInput/Resources")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: imkResources, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

/// Vẽ biểu tượng vào ô vuông `s` điểm. Toạ độ thiết kế 128×128, gốc trên bên trái như bản SVG trên canvas.
func drawIcon(_ ctx: CGContext, size s: CGFloat) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    // Lưới biểu tượng macOS: hình vuông bo góc 824/1024, bo 185/824.
    let inset = s * 100 / 1024
    let side = s - inset * 2
    let k = side / 128
    ctx.saveGState()
    ctx.translateBy(x: inset, y: s - inset)
    ctx.scaleBy(x: k, y: -k)

    let tile = CGPath(roundedRect: CGRect(x: 0, y: 0, width: 128, height: 128), cornerWidth: 28.6, cornerHeight: 28.6, transform: nil)
    // Bóng đổ nhẹ cho cả viên.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -3), blur: 8, color: color(0x1A1F7A, 0.35))
    ctx.addPath(tile)
    ctx.setFillColor(color(0x3B5BFF))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    let bg = CGGradient(colorsSpace: space, colors: [color(0x8B5CF6), color(0x3B5BFF), color(0x22D3EE)] as CFArray, locations: [0, 0.52, 1])!
    ctx.drawLinearGradient(bg, start: .zero, end: CGPoint(x: 128, y: 128), options: [])
    let glow = CGGradient(colorsSpace: space, colors: [color(0xFF5CA8, 0.9), color(0xFF5CA8, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 15, y: 123), startRadius: 0, endCenter: CGPoint(x: 15, y: 123), endRadius: 92, options: [])

    let small = s <= 64
    if !small {
        // Phím kính.
        let cap = CGPath(roundedRect: CGRect(x: 22, y: 20, width: 84, height: 82), cornerWidth: 22, cornerHeight: 22, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 6), blur: 8, color: color(0x1A1F7A, 0.3))
        ctx.addPath(cap)
        ctx.setFillColor(color(0xFFFFFF, 0.18))
        ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(cap)
        ctx.clip()
        let sheen = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF, 0.45), color(0xFFFFFF, 0.06)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(sheen, start: CGPoint(x: 0, y: 20), end: CGPoint(x: 0, y: 102), options: [])
        ctx.restoreGState()
        ctx.addPath(cap)
        ctx.setStrokeColor(color(0xFFFFFF, 0.75))
        ctx.setLineWidth(1.6)
        ctx.strokePath()
    }

    // Chữ V.
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    let v = CGMutablePath()
    if small {
        v.move(to: CGPoint(x: 38, y: 48)); v.addLine(to: CGPoint(x: 64, y: 96)); v.addLine(to: CGPoint(x: 90, y: 48))
    } else {
        v.move(to: CGPoint(x: 45, y: 49)); v.addLine(to: CGPoint(x: 64, y: 85)); v.addLine(to: CGPoint(x: 83, y: 49))
    }
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 2.5), blur: 2, color: color(0x1A1F7A, 0.3))
    ctx.addPath(v)
    ctx.setStrokeColor(color(0xFFFFFF))
    ctx.setLineWidth(small ? 17 : 11)
    ctx.strokePath()
    ctx.restoreGState()

    // Dấu sắc phát sáng.
    let mark = CGMutablePath()
    if small {
        mark.move(to: CGPoint(x: 70, y: 33)); mark.addLine(to: CGPoint(x: 86, y: 18))
    } else {
        mark.move(to: CGPoint(x: 68, y: 38)); mark.addLine(to: CGPoint(x: 80, y: 27))
    }
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: small ? 3 : 6, color: color(0xFF5CA8, 0.9))
    ctx.addPath(mark)
    ctx.setLineWidth(small ? 15 : 9)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    let pink = CGGradient(colorsSpace: space, colors: [color(0xFF3D8B), color(0xFFB86B)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(pink, start: CGPoint(x: 66, y: 40), end: CGPoint(x: 88, y: 16), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    ctx.restoreGState()
    ctx.restoreGState()
}

func png(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    drawIcon(ctx.cgContext, size: CGFloat(px))
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for pt in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(pt)x\(pt)\(scale == 2 ? "@2x" : "").png"
        try png(pt * scale).write(to: iconset.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(pt)x\(pt)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["version": 1, "author": "mrtv"]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: iconset.appendingPathComponent("Contents.json"))
try #"{ "info" : { "version" : 1, "author" : "mrtv" } }"#.write(to: iconset.deletingLastPathComponent().appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

// Biểu tượng bộ gõ trên thanh menu: ô đặc có chữ V khoét rỗng (ảnh mẫu, macOS tự đổi màu).
let pdfURL = imkResources.appendingPathComponent("MenuIcon.pdf") as CFURL
var box = CGRect(x: 0, y: 0, width: 22, height: 16)
let pdf = CGContext(pdfURL, mediaBox: &box, nil)!
pdf.beginPDFPage(nil)
pdf.addPath(CGPath(roundedRect: CGRect(x: 2, y: 1, width: 18, height: 14), cornerWidth: 3.5, cornerHeight: 3.5, transform: nil))
pdf.setFillColor(color(0x000000))
pdf.fillPath()
pdf.setBlendMode(.clear)
pdf.setLineCap(.round)
pdf.setLineJoin(.round)
pdf.setLineWidth(2.2)
pdf.move(to: CGPoint(x: 7, y: 11.5)); pdf.addLine(to: CGPoint(x: 11, y: 4)); pdf.addLine(to: CGPoint(x: 15, y: 11.5))
pdf.strokePath()
pdf.endPDFPage()
pdf.closePDF()
print("Xong: \(images.count) ảnh biểu tượng + MenuIcon.pdf")
