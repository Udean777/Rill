import AppKit

/// Places the palette on the screen under the pointer.
enum PanelPositioner {
    /// Frame for `size` centred horizontally, its top edge 22 % down the screen.
    static func frame(for size: CGSize, on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let originX = visible.midX - size.width / 2
        let originY = visible.maxY - size.height - visible.height * 0.22
        return NSRect(origin: CGPoint(x: originX, y: originY), size: size)
    }

    /// The screen containing the mouse pointer, falling back to the main screen.
    static func screenUnderPointer() -> NSScreen? {
        let pointer = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
    }
}
