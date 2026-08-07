#!/usr/bin/env swift
import AppKit

// Render the brand avatar (wand.and.rays SF Symbol on Petrol Blue gradient)
// to a 1024x1024 PNG.

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size, flipped: false) { _ in

    // Background: rounded rect with gradient
    let rect = NSRect(origin: .zero, size: size)
    let path = NSBezierPath(roundedRect: rect, xRadius: 298, yRadius: 298)

    let gradient = NSGradient(
        colors: [
            NSColor(red: 0.0549, green: 0.4235, blue: 0.6196, alpha: 1.0),
            NSColor(red: 0.0353, green: 0.3059, blue: 0.4510, alpha: 1.0)
        ]
    )!
    gradient.draw(in: path, angle: 315)

    // Overlay: wand.and.rays SF Symbol
    if let symbol = NSImage(systemSymbolName: "wand.and.rays",
                            accessibilityDescription: nil) {
        let cfg = NSImage.SymbolConfiguration(pointSize: 512, weight: .semibold)
            .applying(.init(paletteColors: [.white]))
        let configured = symbol.withSymbolConfiguration(cfg)
        let symbolSize = configured?.size ?? .zero
        let origin = NSPoint(
            x: (size.width - symbolSize.width) / 2,
            y: (size.height - symbolSize.height) / 2
        )
        configured?.draw(in: NSRect(origin: origin, size: symbolSize))
    }

    return true
}

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff) else {
    print("ERROR: conversion failed")
    exit(1)
}

let png = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:])!
let outPath = "Sources/IconGen/AIMacCleaner.png"
try! png.write(to: URL(fileURLWithPath: outPath))
print("OK: \(outPath) (\(png.count) bytes)")
