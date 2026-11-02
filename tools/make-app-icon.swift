#!/usr/bin/swift
// Рисует мастер-иконку приложения (1024×1024 PNG).
// Использование: swift tools/make-app-icon.swift out.png

import AppKit

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "app-icon.png"
let size: CGFloat = 1024
let pixels = Int(size)

guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                 pixelsWide: pixels,
                                 pixelsHigh: pixels,
                                 bitsPerSample: 8,
                                 samplesPerPixel: 4,
                                 hasAlpha: true,
                                 isPlanar: false,
                                 colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0,
                                 bitsPerPixel: 0),
      let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
    fputs("Не удалось создать графический контекст\n", stderr)
    exit(1)
}
rep.size = NSSize(width: size, height: size)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let context = graphics.cgContext
context.setShouldAntialias(true)
context.setAllowsAntialiasing(true)

// Фон: скруглённый квадрат в стиле macOS с тёмно-изумрудным градиентом.
let margin: CGFloat = 100
let rect = NSRect(x: margin, y: margin, width: size - margin * 2, height: size - margin * 2)
let corner: CGFloat = 184
let background = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)

NSGraphicsContext.saveGraphicsState()
let dropShadow = NSShadow()
dropShadow.shadowColor = NSColor.black.withAlphaComponent(0.42)
dropShadow.shadowBlurRadius = 42
dropShadow.shadowOffset = NSSize(width: 0, height: -14)
dropShadow.set()
let top = NSColor(srgbRed: 0.13, green: 0.33, blue: 0.25, alpha: 1)
let bottom = NSColor(srgbRed: 0.02, green: 0.06, blue: 0.05, alpha: 1)
NSGradient(starting: bottom, ending: top)?.draw(in: background, angle: 90)
NSGraphicsContext.restoreGraphicsState()

// Мягкое свечение сверху.
NSGraphicsContext.saveGraphicsState()
background.addClip()
let glow = NSGradient(colorsAndLocations:
    (NSColor(srgbRed: 0.34, green: 0.95, blue: 0.60, alpha: 0.34), 0.0),
    (NSColor(srgbRed: 0.34, green: 0.95, blue: 0.60, alpha: 0.0), 1.0))
glow?.draw(fromCenter: NSPoint(x: size * 0.30, y: size * 0.86),
           radius: 0,
           toCenter: NSPoint(x: size * 0.30, y: size * 0.86),
           radius: size * 0.62,
           options: [])
NSGraphicsContext.restoreGraphicsState()

// Тонкая внутренняя рамка.
NSGraphicsContext.saveGraphicsState()
let border = NSBezierPath(roundedRect: rect.insetBy(dx: 2.5, dy: 2.5), xRadius: corner - 2.5, yRadius: corner - 2.5)
border.lineWidth = 3
NSColor.white.withAlphaComponent(0.10).setStroke()
border.stroke()
NSGraphicsContext.restoreGraphicsState()

// Три полоски — как в строке меню.
let barWidth: CGFloat = 150
let gap: CGFloat = 64
let barHeight: CGFloat = 510
let totalWidth = barWidth * 3 + gap * 2
let startX = (size - totalWidth) / 2
let startY = (size - barHeight) / 2
let fractions: [CGFloat] = [0.94, 0.67, 0.42]

for index in 0..<3 {
    let x = startX + CGFloat(index) * (barWidth + gap)
    let trackRect = NSRect(x: x, y: startY, width: barWidth, height: barHeight)
    let track = NSBezierPath(roundedRect: trackRect, xRadius: barWidth / 2, yRadius: barWidth / 2)

    NSColor.white.withAlphaComponent(0.11).setFill()
    track.fill()

    let fillHeight = max(barWidth, barHeight * fractions[index])
    let fillRect = NSRect(x: x, y: startY, width: barWidth, height: fillHeight)
    let fill = NSBezierPath(roundedRect: fillRect, xRadius: barWidth / 2, yRadius: barWidth / 2)

    NSGraphicsContext.saveGraphicsState()
    let barShadow = NSShadow()
    barShadow.shadowColor = NSColor(srgbRed: 0.25, green: 0.95, blue: 0.55, alpha: 0.45)
    barShadow.shadowBlurRadius = 34
    barShadow.shadowOffset = .zero
    barShadow.set()
    let light = NSColor(srgbRed: 0.46, green: 1.0, blue: 0.66, alpha: 1)
    let deep = NSColor(srgbRed: 0.10, green: 0.72, blue: 0.36, alpha: 1)
    NSGradient(starting: deep, ending: light)?.draw(in: fill, angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    // Плавный верхний блик без жёсткой границы.
    NSGraphicsContext.saveGraphicsState()
    fill.addClip()
    let shine = NSGradient(colorsAndLocations:
        (NSColor.white.withAlphaComponent(0.0), 0.0),
        (NSColor.white.withAlphaComponent(0.0), 0.55),
        (NSColor.white.withAlphaComponent(0.30), 1.0))
    shine?.draw(in: fillRect, angle: 90)
    NSGraphicsContext.restoreGraphicsState()
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Не удалось отрисовать иконку\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: output))
print(output)
