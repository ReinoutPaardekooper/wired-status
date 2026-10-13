import AppKit

// Apple's classic Ethernet mark, drawn as a tiny AppKit template. The SF
// Symbol named "network" is a globe, not this Ethernet-specific mark.
func ethernetIcon(link: LinkState?, isDefault: Bool) -> NSImage {
    let image = NSImage(size: NSSize(width: 22, height: 16), flipped: false) { _ in
        NSColor.black.setStroke()
        NSColor.black.setFill()
        let brackets = NSBezierPath()
        brackets.lineWidth = 1.8
        brackets.lineCapStyle = .square
        brackets.lineJoinStyle = .miter
        brackets.move(to: NSPoint(x: 5, y: 13))
        brackets.line(to: NSPoint(x: 1, y: 8))
        brackets.line(to: NSPoint(x: 5, y: 3))
        brackets.move(to: NSPoint(x: 17, y: 13))
        brackets.line(to: NSPoint(x: 21, y: 8))
        brackets.line(to: NSPoint(x: 17, y: 3))
        brackets.stroke()
        for x in [8.0, 11.0, 14.0] {
            NSBezierPath(ovalIn: NSRect(x: x - 1.1, y: 6.9, width: 2.2, height: 2.2)).fill()
        }
        if link != .connected {
            let slash = NSBezierPath()
            slash.lineWidth = 1.5
            slash.move(to: NSPoint(x: 7, y: 2))
            slash.line(to: NSPoint(x: 15, y: 14))
            slash.stroke()
        } else if !isDefault {
            // A fourth, lower dot distinguishes link-only from the default route.
            NSBezierPath(ovalIn: NSRect(x: 10.2, y: 1, width: 1.6, height: 1.6)).fill()
        }
        return true
    }
    image.isTemplate = true // Native light/dark menu-bar tint; no bitmap assets.
    return image
}
