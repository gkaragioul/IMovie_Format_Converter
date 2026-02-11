#!/usr/bin/env swift
import AppKit
import Foundation

let args = CommandLine.arguments
let outputPath: String
if args.count > 1 {
    outputPath = args[1]
} else {
    outputPath = "Assets/AppIcon-1024.png"
}

let canvasSize = NSSize(width: 1024, height: 1024)
let image = NSImage(size: canvasSize)
image.lockFocus()

let rect = NSRect(origin: .zero, size: canvasSize)
NSColor(calibratedRed: 0.07, green: 0.11, blue: 0.16, alpha: 1).setFill()
rect.fill()

let cardRect = rect.insetBy(dx: 68, dy: 68)
let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 170, yRadius: 170)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.14, green: 0.51, blue: 0.88, alpha: 1),
    NSColor(calibratedRed: 0.08, green: 0.79, blue: 0.60, alpha: 1)
])
gradient?.draw(in: cardPath, angle: 305)

NSColor.white.withAlphaComponent(0.18).setStroke()
cardPath.lineWidth = 10
cardPath.stroke()

let filmRect = NSRect(x: 190, y: 260, width: 644, height: 420)
let filmBody = NSBezierPath(roundedRect: filmRect, xRadius: 54, yRadius: 54)
NSColor(calibratedWhite: 0.08, alpha: 0.9).setFill()
filmBody.fill()

let stripWidth: CGFloat = 86
let leftStrip = NSRect(x: filmRect.minX, y: filmRect.minY, width: stripWidth, height: filmRect.height)
let rightStrip = NSRect(x: filmRect.maxX - stripWidth, y: filmRect.minY, width: stripWidth, height: filmRect.height)
NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
NSBezierPath(rect: leftStrip).fill()
NSBezierPath(rect: rightStrip).fill()

let holeCount = 6
for index in 0..<holeCount {
    let y = filmRect.minY + 42 + CGFloat(index) * 62
    let leftHole = NSBezierPath(roundedRect: NSRect(x: leftStrip.minX + 20, y: y, width: 46, height: 30), xRadius: 8, yRadius: 8)
    let rightHole = NSBezierPath(roundedRect: NSRect(x: rightStrip.minX + 20, y: y, width: 46, height: 30), xRadius: 8, yRadius: 8)
    NSColor(calibratedWhite: 0.75, alpha: 0.7).setFill()
    leftHole.fill()
    rightHole.fill()
}

let playTriangle = NSBezierPath()
playTriangle.move(to: NSPoint(x: 430, y: 370))
playTriangle.line(to: NSPoint(x: 430, y: 570))
playTriangle.line(to: NSPoint(x: 620, y: 470))
playTriangle.close()
NSColor.white.withAlphaComponent(0.95).setFill()
playTriangle.fill()

let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 286, y: 174))
arrowPath.line(to: NSPoint(x: 664, y: 174))
arrowPath.line(to: NSPoint(x: 664, y: 134))
arrowPath.line(to: NSPoint(x: 758, y: 214))
arrowPath.line(to: NSPoint(x: 664, y: 294))
arrowPath.line(to: NSPoint(x: 664, y: 254))
arrowPath.line(to: NSPoint(x: 286, y: 254))
arrowPath.close()
NSColor.white.withAlphaComponent(0.95).setFill()
arrowPath.fill()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let pngData = bitmap.representation(using: .png, properties: [.compressionFactor: 1.0]) else {
    fputs("Failed to generate icon image.\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try pngData.write(to: outputURL)
print("Wrote \(outputURL.path)")
