// Generates the 1024x1024 app icon.
//
//   swift Tools/make-icon.swift
//
// The mark is literally one dit and one dah — the app's name drawn in the
// alphabet it teaches. It stays legible at 24 pt, which a letterform-based icon
// would not, and watchOS's circular mask leaves it untouched because everything
// sits well inside the inscribed circle.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024
let amber = CGColor(red: 1.00, green: 0.70, blue: 0.25, alpha: 1)

guard let context = CGContext(
    data: nil,
    width: side,
    height: side,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("could not create bitmap context")
}

let bounds = CGRect(x: 0, y: 0, width: side, height: side)

// Near-black base so the icon sits comfortably on any watch face.
context.setFillColor(CGColor(red: 0.055, green: 0.043, blue: 0.024, alpha: 1))
context.fill(bounds)

// A warm glow behind the marks, like a lit dial.
if let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        CGColor(red: 0.42, green: 0.28, blue: 0.06, alpha: 1),
        CGColor(red: 0.055, green: 0.043, blue: 0.024, alpha: 1),
    ] as CFArray,
    locations: [0, 1]
) {
    context.drawRadialGradient(
        gradient,
        startCenter: CGPoint(x: side / 2, y: side / 2),
        startRadius: 0,
        endCenter: CGPoint(x: side / 2, y: side / 2),
        endRadius: CGFloat(side) * 0.62,
        options: []
    )
}

// One dit and one dah, in the same 1:3 width ratio the app uses everywhere.
let unit: CGFloat = 150
let gap: CGFloat = 96
let totalWidth = unit + gap + unit * 3
let originX = (CGFloat(side) - totalWidth) / 2
let centerY = CGFloat(side) / 2
let markY = centerY - unit / 2

context.setFillColor(amber)

let dit = CGRect(x: originX, y: markY, width: unit, height: unit)
context.fillEllipse(in: dit)

let dah = CGRect(x: originX + unit + gap, y: markY, width: unit * 3, height: unit)
context.addPath(CGPath(roundedRect: dah, cornerWidth: unit / 2, cornerHeight: unit / 2, transform: nil))
context.fillPath()

guard let image = context.makeImage() else { fatalError("could not render image") }

let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("DitDah Watch App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

guard let destination = CGImageDestinationCreateWithURL(
    output as CFURL, UTType.png.identifier as CFString, 1, nil
) else {
    fatalError("could not create \(output.path)")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("could not write PNG") }

print("wrote \(output.path)")
