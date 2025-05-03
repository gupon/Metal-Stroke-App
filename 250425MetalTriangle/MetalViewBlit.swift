import SwiftUI
import MetalKit

struct MetalViewBlit: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame:NSRect.zero , device: context.coordinator.device)
        view.clearColor = MTLClearColor(red: 0.1, green: 0, blue: 0.2, alpha: 1.0)
        view.delegate = context.coordinator
        view.framebufferOnly = false
        
        context.coordinator.loadTexture(view: view)
        
        return view
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {}
    
    class Coordinator: NSObject, MTKViewDelegate {
        let device: MTLDevice
        let cmdQueue: MTLCommandQueue
        
        private var texture: MTLTexture!
        
        override init() {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let cmdQueue = device.makeCommandQueue() else {
                fatalError("Metal device or command queue creation failed")
            }
            self.device = device
            self.cmdQueue = cmdQueue
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // for resize event
        }
        
        func loadTexture(view: MTKView) {
            let textureLoader = MTKTextureLoader(device: device)
            do {
                texture = try textureLoader.newTexture(
                    name: "face",
                    scaleFactor: 1.0,
                    bundle: nil)
            } catch {
                print("Failed to load texture: \(error)")
            }
        }
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor,
                  let cmdBuffer = cmdQueue.makeCommandBuffer(),
                  let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: descriptor)
            else {return}
            
            encoder.endEncoding()
            
            if texture != nil {
                view.colorPixelFormat = texture.pixelFormat
                let w = min(texture.width, drawable.texture.width)
                let h = min(texture.height, drawable.texture.height)
                let blitEncoder = cmdBuffer.makeBlitCommandEncoder()!
                
                blitEncoder.copy(from: texture,
                                 sourceSlice: 0,
                                 sourceLevel: 0,
                                 sourceOrigin: MTLOrigin(),
                                 sourceSize: MTLSizeMake(w, h, texture.depth),
                                 to: drawable.texture,
                                 destinationSlice: 0,
                                 destinationLevel: 0,
                                 destinationOrigin: MTLOrigin()
                )
                blitEncoder.endEncoding()
                cmdBuffer.present(drawable)
                cmdBuffer.commit()
            }
            
        }
    }
}

#Preview {
    MetalView()
        .frame(minWidth: 640, minHeight: 640)
}
