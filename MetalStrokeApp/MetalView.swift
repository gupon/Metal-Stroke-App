import SwiftUI
import MetalKit

/*
 Bridge for SwiftUI <-> AppKit
 
 MetalView: SwiftUI(NSViewRepresentable)
 MyMTKView: AppKit(NSView)
 
*/

struct MetalView: NSViewRepresentable {
    @EnvironmentObject var data: StrokeBufferManager
    
    // draw properties from contentView
    @Binding var strokeWidth: Float
    @Binding var showWireFrame: Bool
    
    func makeCoordinator() -> Renderer {
        Renderer(data)
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        data.setStrokeWidthScale(strokeWidth)
        context.coordinator.setWireframe(showWireFrame)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let view = InteractiveMTKView(frame:NSRect.zero , device: context.coordinator.device, data: self.data)
        view.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        view.delegate = context.coordinator
        view.renderer = context.coordinator
        view.framebufferOnly = true  // which is default
        
        // default values
        /*
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        */
        
        return view
    }
    
}

class InteractiveMTKView: MTKView {
    weak var renderer: Renderer?
    
    private var points:[SIMD2<Float>] = []
    private var data: StrokeBufferManager
    
    private var baseHue: CGFloat = 0.5
    private var minRadius: Float = 0.015
    private var dragStartPos: SIMD2<Float>?
    
    init(frame frameRect: CGRect, device: (any MTLDevice)?, data:StrokeBufferManager) {
        self.data = data
        super.init(frame: frameRect, device: device)
    }
    
    required init(coder: NSCoder) {
        self.data = StrokeBufferManager()
        super.init(coder: coder)
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        var hue = CGFloat.random(in: 0...0.2) + baseHue
        hue = hue.truncatingRemainder(dividingBy: 1.0)
        
        let color = NSColor(hue: hue, saturation: 0.75, brightness: 0.75, alpha: 1.0)
            .usingColorSpace(.deviceRGB)!
        
        let pos = toMetalPos(event.locationInWindow)
        
        data.addPoint(
            pos: pos,
            color: colorToSIMD4(color),
            radius: minRadius
        )
        
        self.dragStartPos = pos
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        
        if let startPos = dragStartPos {
            let localPos = toMetalPos(event.locationInWindow)
            let dist = simd_length(localPos - startPos)
            data.setFinalRadius(max(dist, minRadius))
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
        data.clearAll()
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        // end drag
        dragStartPos = nil
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        print(event.keyCode)
        if event.keyCode == 36 {
            data.endStroke()
        }
        
        baseHue = CGFloat.random(in: 0...1)
    }
    
    override func viewDidMoveToWindow() {
        self.window?.makeFirstResponder(self)
    }
    
    private func toMetalPos(_ pos: NSPoint) -> SIMD2<Float> {
        let localpos = convert(pos, from:nil)
        return SIMD2<Float>(
            Float(localpos.x) / Float(bounds.width),
            Float(localpos.y) / Float(bounds.height)
        ) * 2.0 - SIMD2<Float>(1.0, 1.0)
    }
    
    private func colorToSIMD4(_ color:NSColor) -> SIMD4<Float> {
        return SIMD4<Float> (
            Float(color.redComponent),
            Float(color.greenComponent),
            Float(color.blueComponent),
            Float(color.alphaComponent)
        )
    }
}

/*
#Preview {
    MetalView()
        .frame(minWidth: 640, minHeight: 640)
        .environmentObject(Renderer())
}
*/
