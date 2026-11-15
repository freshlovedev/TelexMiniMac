import AppKit
import Foundation

// Canonical desktop brand artwork: opposing rounded language-switch arrows.
// Both the Flutter in-app brand mark and packaged native icon use this geometry.
let side: CGFloat = 1024
guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024,
  pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4,
  hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
  bytesPerRow: 0, bitsPerPixel: 0),
  let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
  fatalError("Cannot create icon drawing context")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
defer { NSGraphicsContext.restoreGraphicsState() }

let square = NSRect(x: 0, y: 0, width: side, height: side)
let clip = NSBezierPath(roundedRect: square.insetBy(dx: 15, dy: 15), xRadius: 263, yRadius: 263)
clip.addClip()
NSColor.clear.setFill()
square.fill()

let gradient = NSGradient(starting: NSColor(srgbRed: 8/255, green: 187/255, blue: 169/255, alpha: 1),
                          ending: NSColor(srgbRed: 22/255, green: 117/255, blue: 181/255, alpha: 1))!
gradient.draw(in: clip, angle: -45)

func stroke(_ segments: [[CGPoint]]) {
  let path = NSBezierPath()
  path.lineCapStyle = .round
  path.lineJoinStyle = .round
  path.lineWidth = 108
  for segment in segments {
    guard let first = segment.first else { continue }
    path.move(to: first)
    for point in segment.dropFirst() { path.line(to: point) }
  }
  NSColor.white.setStroke()
  path.stroke()
}
// AppKit's y-axis runs upward; the icon is vertically symmetric.
stroke([
  [CGPoint(x:246, y:666),CGPoint(x:737,y:666)],
  [CGPoint(x:594,y:799),CGPoint(x:747,y:666),CGPoint(x:594,y:533)],
  [CGPoint(x:778,y:358),CGPoint(x:287,y:358)],
  [CGPoint(x:430,y:491),CGPoint(x:277,y:358),CGPoint(x:430,y:225)],
])

guard let png = bitmap.representation(using: .png, properties: [:]) else {
  fatalError("Cannot render brand icon")
}
let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/TelexMini-Icon-Teal.png"
try png.write(to: URL(fileURLWithPath: path), options: .atomic)
print("BRAND_ICON=" + path)
