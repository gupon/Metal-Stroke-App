import MetalKit

class RenderOptions: ObservableObject {
    @Published var wireFrame: Bool = true
    @Published var debug: Bool = true
    @Published var showFPS: Bool = true
}

class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    private let cmdQueue: MTLCommandQueue
    
    private var mainPipeline: MTLRenderPipelineState?
    private var capsPipeline: MTLRenderPipelineState?
    private var joinPipeline: MTLRenderPipelineState?
    private var debugPipeline: MTLRenderPipelineState?

    private var tLastDraw: CFTimeInterval = CACurrentMediaTime()
    @Published private(set) var fps: Double = 0
    
    private var options: RenderOptions
    
    private var buffer: StrokeBuffer
    private var model: StrokeModel
    
    private var rectShape: Rectangle
    private var roundShape: RoundShape
    
    enum BufferIndex: Int {
        case mainVertex = 0
        case rectShape = 1
        case roundShape = 2
        case roundRes = 3
        case joinIndex = 4
        case capIndex = 5
        case drawMode = 9
        case pointStep = 10
        case debug = 20
    }

    init(_ model: StrokeModel, options: RenderOptions) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let cmdQueue = device.makeCommandQueue() else {
            fatalError("Metal device or command queue creation failed")
        }
        
        self.device = device
        self.cmdQueue = cmdQueue
        self.model = model
        
        self.options = options

        self.buffer = StrokeBuffer()
        
        // init shapes buffer
        self.rectShape = Rectangle()
        rectShape.createBuffers(device)
        
        self.roundShape = RoundShape(roundRes: 16)
        roundShape.createBuffers(device)

        // init super after self member initialization
        // but before member function call
        super.init()

        // build pipelines
        self.mainPipeline = buildPipeline(vertfunc: "vert_main", fragfunc: "frag_main", enableAlpha: true)
        self.joinPipeline = buildPipeline(vertfunc: "vert_join", fragfunc: "frag_main", enableAlpha: true)
        self.debugPipeline = buildPipeline(vertfunc: "vert_debug", fragfunc: "frag_main", enableAlpha: true)
    }
    
    // build Render Pipeline from shader function names
    private func buildPipeline(vertfunc: String, fragfunc: String, enableAlpha: Bool=false) -> MTLRenderPipelineState {
        let desc = MTLRenderPipelineDescriptor()
        let library = device.makeDefaultLibrary()
        
        desc.vertexFunction = library?.makeFunction(name: vertfunc)
        desc.fragmentFunction = library?.makeFunction(name: fragfunc)
        desc.vertexDescriptor = buffer.getVertexDescriptor()
        
        desc.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        
        // enable alpha blending
        if enableAlpha, let colorDesc = desc.colorAttachments[0] {
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
    
    private func updateFPS() {
        fps = 1.0 / (CACurrentMediaTime() - tLastDraw)
        tLastDraw = CACurrentMediaTime()
        //        print(String(format:"%.2f", fps))
    }
    
    func draw(in view: MTKView) {
        updateFPS()
        
        model.markEndVertices()
        buffer.updateBuffer(from: model, device: device)
        
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let cmdBuffer = cmdQueue.makeCommandBuffer(),
              let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {return}
        
        defer {
            // always execute before return
            encoder.endEncoding()
            cmdBuffer.present(drawable)
            cmdBuffer.commit()
        }
        
        
        if let vbuffer = buffer.getVertexBuffer(),
           let mainPipeline = self.mainPipeline
        {
            
            encoder.setRenderPipelineState(mainPipeline)
            encoder.setVertexBuffer(vbuffer, offset: 0, index: BufferIndex.mainVertex.rawValue)
            encoder.setVertexBuffer(rectShape.vertexBuffer, offset: 0, index: BufferIndex.rectShape.rawValue)
            
            setVertexBytes(encoder: encoder, value: UInt8(options.debug ? 1 : 0), index: BufferIndex.debug)

            // draw stroke body
            setVertexBytes(encoder: encoder, value: UInt8(0), index: BufferIndex.drawMode)
            drawInstancedShapes(encoder: encoder, shape: rectShape, count: buffer.vertexCount-1)
            
            if options.wireFrame
            {
                setVertexBytes(encoder: encoder, value: UInt8(1), index: BufferIndex.drawMode)
                drawInstancedShapes(encoder: encoder, shape: rectShape, count: buffer.vertexCount-1, wireframe: true)
            }
            
            // draw joins
            if let joinIdxBuffer = buffer.getJoinIndexBuffer(),
               let joinPipeline = self.joinPipeline
            {
                
                encoder.setRenderPipelineState(joinPipeline)
                
                encoder.setVertexBuffer(roundShape.vertexBuffer, offset:0, index: BufferIndex.roundShape.rawValue)
                encoder.setVertexBuffer(joinIdxBuffer, offset: 0, index: BufferIndex.joinIndex.rawValue)
                
                setVertexBytes(encoder: encoder, value: UInt8(roundShape.roundRes), index: BufferIndex.roundRes)
                setVertexBytes(encoder: encoder, value: UInt8(0), index: BufferIndex.drawMode)
                setVertexBytes(encoder: encoder, value: UInt8(options.debug ? 1 : 0), index: BufferIndex.debug)
                
                drawInstancedShapes(encoder: encoder, shape: roundShape, count: buffer.joinCount)

                if options.wireFrame
                {
                    setVertexBytes(encoder: encoder, value: UInt8(1), index: BufferIndex.drawMode)
                    drawInstancedShapes(encoder: encoder, shape: roundShape, count: buffer.joinCount, wireframe: true)
                }
            }
            
            // center line
            if options.wireFrame
            {
                // draw center line
                if let pipeline = debugPipeline,
                   let idxbuffer = buffer.centerLineIndexBuffer {
                    
                    encoder.setRenderPipelineState(pipeline)
                    setVertexBytes(encoder: encoder, value: UInt8(0), index: BufferIndex.pointStep)

                    // draw center line
                    drawInstancedLines(encoder: encoder, count: buffer.centerLineIndexCount, indexBuffer: idxbuffer)
                    
                    // draw points
                    setVertexBytes(encoder: encoder, value: UInt8(0), index: BufferIndex.pointStep)
                    encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: buffer.vertexCount)
                    
                    setVertexBytes(encoder: encoder, value: UInt8(1), index: BufferIndex.pointStep)
                    encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: buffer.vertexCount )
                }
            }
        }
    }
    
    private func drawInstancedShapes (
        encoder: MTLRenderCommandEncoder,
        shape: BufferedStrokeShape,
        count: Int,
        wireframe: Bool=false
    ) {
        encoder.drawIndexedPrimitives(
            type: wireframe ? .line : .triangle,
            indexCount: wireframe ? shape.indicesWireframe.count : shape.indicesTriangle.count,
            indexType: .uint16,
            indexBuffer: wireframe ? shape.indexBufferWireframe! : shape.indexBufferTriangle!,
            indexBufferOffset: 0,
            instanceCount: count
        )
    }
    
    
    private func drawInstancedLines (encoder: MTLRenderCommandEncoder, count: Int, indexBuffer: any MTLBuffer) {
        encoder.drawIndexedPrimitives(
            type: .line,
            indexCount: count,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
    }
    
    /*
     Set single value Bytes
     */
    private func setVertexBytes<T: FixedWidthInteger> (encoder: MTLRenderCommandEncoder, value: T, index: BufferIndex) {
        var val = value
        encoder.setVertexBytes(&val, length: MemoryLayout<T>.size, index: index.rawValue)
    }
}
