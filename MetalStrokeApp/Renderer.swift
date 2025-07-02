import MetalKit

class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let cmdQueue: MTLCommandQueue
    
    private var mainPipeline: MTLRenderPipelineState?
    private var debugPipeline: MTLRenderPipelineState?

    private var tLastDraw: CFTimeInterval = CACurrentMediaTime()
    @Published private(set) var fps: Double = 0
    
    private var buffer: StrokeBuffer
    private var model: StrokeModel
    
    private var rect: Rectangle
    
    private var drawModeWireBuffer: MTLBuffer?
    private var drawModeFillBuffer: MTLBuffer?
    private var drawModeCenterBuffer: MTLBuffer?

    // Stroke Attributes
    private var showWireFrame: Bool = true
    
    init(_ model: StrokeModel) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let cmdQueue = device.makeCommandQueue() else {
            fatalError("Metal device or command queue creation failed")
        }
        self.device = device
        self.cmdQueue = cmdQueue
        self.model = model
        
        self.buffer = StrokeBuffer()
        
        self.rect = Rectangle()
        
        // init super after self member initialization
        super.init()
        
        self.mainPipeline =  buildPipeline(vertfunc: "vtx_main", fragfunc: "frag_main")
        self.debugPipeline =  buildPipeline(vertfunc: "vtx_debug", fragfunc: "frag_main")
        rect.createBuffers(device)
        
        drawModeFillBuffer = device.makeBuffer(bytes:[UInt32(0)], length: MemoryLayout<UInt32>.size)
        drawModeWireBuffer = device.makeBuffer(bytes:[UInt32(1)], length: MemoryLayout<UInt32>.size)
        drawModeCenterBuffer = device.makeBuffer(bytes:[UInt32(2)], length: MemoryLayout<UInt32>.size)
    }
    
    private func buildPipeline(vertfunc: String, fragfunc: String) -> MTLRenderPipelineState {
        let desc = MTLRenderPipelineDescriptor()
        let library = device.makeDefaultLibrary()
        
        desc.vertexFunction = library?.makeFunction(name: vertfunc)
        desc.fragmentFunction = library?.makeFunction(name: fragfunc)
        desc.vertexDescriptor = buffer.getVertexDescriptor()
        
        // enable alpha blending
        if let colorDesc = desc.colorAttachments[0] {
            colorDesc.pixelFormat = MTLPixelFormat.bgra8Unorm
            colorDesc.isBlendingEnabled = true
            colorDesc.rgbBlendOperation = .add
            colorDesc.alphaBlendOperation = .add
            colorDesc.sourceRGBBlendFactor = .sourceAlpha
            colorDesc.sourceAlphaBlendFactor = .sourceAlpha
            colorDesc.destinationRGBBlendFactor = .oneMinusSourceAlpha
            colorDesc.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }

        do {
            return try device.makeRenderPipelineState(descriptor: desc)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func setWireframe (_ value:Bool) {
        self.showWireFrame = value
    }
    
    private func updateFPS() {
        fps = 1.0 / (CACurrentMediaTime() - tLastDraw)
        tLastDraw = CACurrentMediaTime()
        //        print(String(format:"%.2f", fps))
    }
    
    func draw(in view: MTKView) {
        updateFPS()
        buffer.updateBuffer(from: self.model, device: device)
        
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let cmdBuffer = cmdQueue.makeCommandBuffer(),
              let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: descriptor),
              let pipelineState = mainPipeline
        else {return}
        
        defer {
            // always execute before return
            encoder.endEncoding()
            cmdBuffer.present(drawable)
            cmdBuffer.commit()
        }
        
        encoder.setRenderPipelineState(pipelineState)
        
        if let vbuffer = buffer.getVertexBuffer()
        {
            
            encoder.setVertexBuffer(vbuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(rect.vertexBuffer, offset: 0, index: 1)
            
            // draw fill
            encoder.setVertexBuffer(drawModeFillBuffer!, offset:0, index:2)
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: 6,
                indexType: .uint16,
                indexBuffer: rect.indexBufferTriangle!,
                indexBufferOffset: 0,
                instanceCount: buffer.vertexCount - 1
            )
            
            if (showWireFrame)
            {
                // draw wireframe
                encoder.setVertexBuffer(drawModeWireBuffer!, offset:0, index:2)
                encoder.drawIndexedPrimitives(
                    type: .line,
                    indexCount: 10,
                    indexType: .uint16,
                    indexBuffer: rect.indexBufferWireframe!,
                    indexBufferOffset: 0,
                    instanceCount: buffer.vertexCount - 1
                )
                
                // draw center line (not working)
                if let pipeline = debugPipeline,
                   let idxbuffer = buffer.centerLineIndexBuffer {
                    
                    encoder.setRenderPipelineState(pipeline)
                    
                    var pointStep:UInt32 = 0
                    encoder.setVertexBytes(&pointStep, length: MemoryLayout<UInt32>.size, index: 3)
                    
                    encoder.drawIndexedPrimitives(
                        type: .line,
                        indexCount: buffer.centerLineIndexCount,
                        indexType: .uint16,
                        indexBuffer: idxbuffer,
                        indexBufferOffset: 0
                    )
                    
                    encoder.setVertexBytes(&pointStep, length: MemoryLayout<UInt32>.size, index: 3)
                    encoder.drawPrimitives(
                        type: .point,
                        vertexStart: 0,
                        vertexCount: buffer.vertexCount
                    )
                    
                    pointStep = 1
                    encoder.setVertexBytes(&pointStep, length: MemoryLayout<UInt32>.size, index: 3)
                    encoder.drawPrimitives(
                        type: .point,
                        vertexStart: 0,
                        vertexCount: buffer.vertexCount
                    )
                }
            }
        }
    }
}
