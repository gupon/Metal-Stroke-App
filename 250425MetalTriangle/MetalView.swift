import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    @EnvironmentObject var renderer: Renderer
    
    func makeCoordinator() -> Renderer {
        renderer
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {}
    
    func makeNSView(context: Context) -> MTKView {
        let view = MyMTKView(frame:NSRect.zero , device: context.coordinator.device)
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
    private var points:[SIMD2<Float>] = []
    weak var renderer: Renderer?
    
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
        renderer?.vertices = points
        renderer?.isDirty = true
    }
    
    private func addPoint(pos: NSPoint) {
        var texPos = SIMD2<Float>(
            Float(pos.x) / Float(bounds.width),
            Float(pos.y) / Float(bounds.height)
        )
        
        texPos = texPos * 2 - SIMD2<Float>(1,1)
        
        points.append(texPos)
        
        renderer?.vertices = points
        renderer?.isDirty = true
//        print(points)
    }
    
}

#Preview {
    MetalView()
        .frame(minWidth: 640, minHeight: 640)
        .environmentObject(Renderer())
}
