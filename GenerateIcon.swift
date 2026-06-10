import CoreGraphics
import ImageIO
import Foundation

let size: CGFloat = 1024

func createBitmapContext(_ width: Int, _ height: Int) -> CGContext {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    return CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func roundedRectPath(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}

func saveCGImageAsPNG(_ image: CGImage, path: String) {
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let ctx = createBitmapContext(Int(size), Int(size))
let colorSpace = CGColorSpaceCreateDeviceRGB()
let cornerRadius: CGFloat = size * 0.2237

// === SwiftUI theme gradient background ===
let bgGradient = CGGradient(colorsSpace: colorSpace, colors: [
    CGColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1.0),  // SwiftUI blue
    CGColor(red: 0.35, green: 0.31, blue: 0.95, alpha: 1.0),  // Indigo
    CGColor(red: 0.68, green: 0.22, blue: 0.93, alpha: 1.0),  // Purple
    CGColor(red: 1.00, green: 0.18, blue: 0.33, alpha: 1.0),  // Pink
] as CFArray, locations: [0.0, 0.35, 0.65, 1.0])!

let iconPath = roundedRectPath(x: 0, y: 0, w: size, h: size, r: cornerRadius)
ctx.addPath(iconPath)
ctx.clip()

// Diagonal gradient from bottom-left to top-right
ctx.drawLinearGradient(bgGradient,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: size, y: 0),
    options: [])

// Top glass highlight
let hlGrad = CGGradient(colorsSpace: colorSpace, colors: [
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.18),
    CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
] as CFArray, locations: [0.0, 0.5])!
ctx.drawLinearGradient(hlGrad, start: CGPoint(x: size/2, y: size), end: CGPoint(x: size/2, y: size * 0.25), options: [])

// (foreground elements removed)

// === Generate all sizes ===
guard let fullImage = ctx.makeImage() else {
    print("Failed to create image")
    exit(1)
}

let outputDir = "/Users/0fisher/workspace/clipclip/clipclip/clipclip/Assets.xcassets/AppIcon.appiconset"

func resizeAndSave(_ srcImage: CGImage, targetSize: CGFloat, filename: String) {
    let targetCtx = createBitmapContext(Int(targetSize), Int(targetSize))
    targetCtx.interpolationQuality = .high
    targetCtx.draw(srcImage, in: CGRect(x: 0, y: 0, width: targetSize, height: targetSize))
    if let resized = targetCtx.makeImage() {
        saveCGImageAsPNG(resized, path: outputDir + "/" + filename)
        print("✅ \(filename) (\(Int(targetSize))x\(Int(targetSize)))")
    }
}

let sizes: [(String, CGFloat, CGFloat)] = [
    ("icon_16x16.png", 16, 1), ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1), ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1), ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1), ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1), ("icon_512x512@2x.png", 512, 2),
]

for (name, pt, scale) in sizes {
    resizeAndSave(fullImage, targetSize: pt * scale, filename: name)
}

saveCGImageAsPNG(fullImage, path: outputDir + "/icon_preview_1024.png")
print("✅ icon_preview_1024.png (1024x1024)")
print("\n🎉 All icons generated!")
