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
        return Renderer(data)
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        data.setStrokeWidth(strokeWidth)
        context.coordinator.setWireframe(showWireFrame)
    }
    
    func makeNSView(context: Context) -> MTKView {
        let view = MyMTKView(frame:NSRect.zero , device: context.coordinator.device, data: self.data)
        view.clearColor = MTLClearColor(red: 0.1, green: 0, blue: 0.2, alpha: 1.0)
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

class MyMTKView: MTKView {
    weak var renderer: Renderer?
    
    private var points:[SIMD2<Float>] = []
    private var data: StrokeBufferManager
    
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
        addPoint(pos: convert(event.locationInWindow, from: nil))
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        addPoint(pos: convert(event.locationInWindow, from: nil))
    }
    
    override func rightMouseDown(with event: NSEvent) {
        super.rightMouseDown(with: event)
        clearPoints()
    }
    
    /*
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
    }
    */
    
    private func clearPoints() {
        points.removeAll()
        data.vertices = points
        data.isDirty = true
    }
    
    private func addPoint(pos: NSPoint) {
        var texPos = SIMD2<Float>(
            Float(pos.x) / Float(bounds.width),
            Float(pos.y) / Float(bounds.height)
        )
        
        texPos = texPos * 2 - SIMD2<Float>(1,1)
        
        points.append(texPos)
        
        data.vertices = points
        data.isDirty = true
//        print(points)
    }
    
}

/*
#Preview {
    MetalView()
        .frame(minWidth: 640, minHeight: 640)
        .environmentObject(Renderer())
}
*/
