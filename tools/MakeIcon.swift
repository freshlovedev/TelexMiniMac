import AppKit
import Foundation

@main enum MakeIcon {
    static func main() {
        guard CommandLine.arguments.count == 3 else {exit(2)}
        let sourceURL=URL(fileURLWithPath:CommandLine.arguments[1])
        let targetURL=URL(fileURLWithPath:CommandLine.arguments[2])
        guard let source=NSImage(contentsOf:sourceURL),
              let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1024,pixelsHigh:1024,
                  bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,
                  colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0),
              let context=NSGraphicsContext(bitmapImageRep:rep) else {exit(3)}
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current=context
        context.imageInterpolation = .high
        NSColor.clear.setFill()
        NSRect(x:0,y:0,width:1024,height:1024).fill()
        // The generated master is a square icon with a dark rounded-square
        // mark. Clip to the app-icon silhouette so corners stay transparent
        // in Finder, Dock, task switchers and Windows tile surfaces.
        let silhouette=NSBezierPath(roundedRect:NSRect(x:0,y:0,width:1024,height:1024),
                                    xRadius:224,yRadius:224)
        silhouette.addClip()
        source.draw(in:NSRect(x:0,y:0,width:1024,height:1024),
                    from:NSRect(origin:.zero,size:source.size),
                    operation:.copy,fraction:1.0,
                    respectFlipped:false,hints:[.interpolation:NSImageInterpolation.high])
        NSGraphicsContext.restoreGraphicsState()
        guard let data=rep.representation(using:.png,properties:[:]) else {exit(4)}
        do {try data.write(to:targetURL,options:.atomic)} catch {exit(5)}
    }
}
