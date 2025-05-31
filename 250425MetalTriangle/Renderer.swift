import MetalKit

class Renderer: NSObject, MTKViewDelegate, ObservableObject {
    let device: MTLDevice
    private let cmdQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    
    private var tLastDraw: CFTimeInterval = CACurrentMediaTime()
    @Published private(set) var fps: Double = 0
    
    // vertex buffer
    public var vertices: [SIMD2<Float>] = []
    private var vertexCount: Int = 0
    private let BFFR_CHNK_SIZE: Int = 300
    private var currChunkNum: Int = 0
    public var isDirty: Bool = false
    
    // rect instance
    private var rectVtxBuffer: MTLBuffer?
    private var rectIdxBuffer: MTLBuffer?
    private var rectWireIdxBuffer: MTLBuffer?
    private var drawModeWireBuffer: MTLBuffer?
    private var drawModeFillBuffer: MTLBuffer?
    
    // Stroke Attributes
    private var strokeWidth: Float = 1
    private var showWireFrame: Bool = true

    struct StrokeVertex {
        // align in 16B
        var position: SIMD2<Float>  // 8B
        var color: SIMD4<Float>     // 16B
        var radius: Float           // 4B
        var end: Float              // 4B
    }
    let VTX_STRIDE = MemoryLayout<StrokeVertex>.stride
    
    override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let cmdQueue = device.makeCommandQueue() else {
            fatalError("Metal device or command queue creation failed")
        }
        self.device = device
        self.cmdQueue = cmdQueue
        
        // init super after self member initialization
        super.init()

        buildPipeline()
        makeRectBuffer()
        
        drawModeFillBuffer = device.makeBuffer(bytes:[UInt32(0)], length: MemoryLayout<UInt32>.size, options: [])
        drawModeWireBuffer = device.makeBuffer(bytes:[UInt32(1)], length: MemoryLayout<UInt32>.size, options: [])
    }
    
    private func buildPipeline() {
        let library = device.makeDefaultLibrary()
        
        // pipeline
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library?.makeFunction(name: "vtx_main")
        desc.fragmentFunction = library?.makeFunction(name: "frag_main")
        desc.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        
        // vertex descriptor
        let vdesc = MTLVertexDescriptor()
        var offset = 0;
        
        // --position (SIMD2<Float>)
        vdesc.attributes[0].format = .float2
        vdesc.attributes[0].offset = offset
        vdesc.attributes[0].bufferIndex = 0
        offset += MemoryLayout<SIMD2<Float>>.stride

        // --color (SIMD4<Float>)
        vdesc.attributes[1].format = .float4
        vdesc.attributes[1].offset = offset
        vdesc.attributes[1].bufferIndex = 0
        offset += MemoryLayout<SIMD4<Float>>.stride

        // --radius (Float)
        vdesc.attributes[2].format = .float
        vdesc.attributes[2].offset = offset
        vdesc.attributes[2].bufferIndex = 0
        offset += MemoryLayout<Float>.stride
        
        // --end (Float)
        vdesc.attributes[3].format = .float
        vdesc.attributes[3].offset = offset
        vdesc.attributes[3].bufferIndex = 0
        offset += MemoryLayout<Float>.stride

        vdesc.layouts[0].stride = VTX_STRIDE
        
        // set to PipelineDescriptor
        desc.vertexDescriptor = vdesc
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: desc)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }
    
    
    private func makeRectBuffer() {
        // create buffers for rect instance

        let rectVerticies: [SIMD2<Float>] = [
            [-0.5, 0.0], [0.5, 0.0],
            [0.5, 1.0], [-0.5, 1.0]
        ]
        let rectIndicies: [UInt16] = [
            0, 1, 2,
            0, 2, 3
        ]
        
        let rectWireIndicies: [UInt16] = [
            0, 1,
            1, 2,
            2, 3,
            3, 0,
            0, 2
        ]
        
        rectVtxBuffer = device.makeBuffer(
            bytes: rectVerticies,
            length: rectVerticies.count * MemoryLayout<SIMD2<Float>>.stride,
            options: []
        )
        
        rectIdxBuffer = device.makeBuffer(
            bytes: rectIndicies,
            length: rectIndicies.count * MemoryLayout<UInt16>.stride,
            options: []
        )
        
        rectWireIdxBuffer = device.makeBuffer(
            bytes: rectWireIndicies,
            length: rectWireIndicies.count * MemoryLayout<UInt16>.stride,
            options: []
        )
    }
    

    private func updateVertexBuffer() {
        if (!isDirty) {return}
        
        let newChunkNum = (vertices.count + BFFR_CHNK_SIZE - 1) / BFFR_CHNK_SIZE
//        let currChunkNum = (vertexCount + BFFR_CHNK_SIZE - 1) / BFFR_CHNK_SIZE
        let newCapacity = newChunkNum * BFFR_CHNK_SIZE
        
        // expand buffer if necesarry
        if currChunkNum < newChunkNum {
            let oldBuffer = vertexBuffer
            vertexBuffer = device.makeBuffer(length: newCapacity * VTX_STRIDE)
            
            if let oldPtr = oldBuffer?.contents().bindMemory(to: StrokeVertex.self, capacity: vertexCount),
               let newPtr = vertexBuffer?.contents().bindMemory(to: StrokeVertex.self, capacity: newCapacity)
            {
                // copy exsiting points to new buffer
                for i in 0..<vertexCount {
                    newPtr[i] = oldPtr[i]
                }
                
                // initialize new capacity left
                let sv = StrokeVertex(position: .zero, color: .zero, radius: .zero, end: .zero)
                (newPtr + vertexCount).initialize(repeating: sv, count: newCapacity - vertexCount)
            }
            
            currChunkNum = newChunkNum
            print("____BUMP UP CHUNK: \(newCapacity)")
        }
        
        // copy new points
        if (vertices.count > vertexCount + 2) {
//            print("new points: \(vertices.count - vertexCount)")
            print("points: \(vertices.count), new: \(vertices.count - vertexCount)")
        }
        
        if let ptr = vertexBuffer?.contents().bindMemory(to: StrokeVertex.self, capacity: newCapacity)
        {
            let rad: Float = strokeWidth * 0.2
            for i in 0..<vertices.count {
                var end: Float = 0
                if (i == 0) {end = -1} else if (i == vertices.count-1) {end = 1}
                
                ptr[i] = StrokeVertex(
                    position: vertices[i],
                    color: SIMD4<Float>(1,0,0,1),
                    radius: rad,
                    end: end
                )
            }
        }
        
        vertexCount = vertices.count
        isDirty = false
    }
    
    func addPoint(p: NSPoint) {
        isDirty = true
    }
    
    // for resize event
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func setStrokeWidth (_ value:Float){
        self.strokeWidth = value
        self.isDirty = true
    }
    
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
        updateVertexBuffer()
        
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let cmdBuffer = cmdQueue.makeCommandBuffer(),
              let encoder = cmdBuffer.makeRenderCommandEncoder(descriptor: descriptor),
              let pipelineState = pipelineState
        else {return}
        
        defer {
            // always execute before return
            encoder.endEncoding()
            cmdBuffer.present(drawable)
            cmdBuffer.commit()
        }
        
        encoder.setRenderPipelineState(pipelineState)

        if vertexCount > 1, let vbuffer = vertexBuffer
        {
            
            encoder.setVertexBuffer(vbuffer, offset: 0, index: 0)
            encoder.setVertexBuffer(rectVtxBuffer!, offset: 0, index: 1)
            
            // draw fill
            encoder.setVertexBuffer(drawModeFillBuffer!, offset:0, index:2)
            encoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: 6,
                indexType: .uint16,
                indexBuffer: rectIdxBuffer!,
                indexBufferOffset: 0,
                instanceCount: vertexCount - 1
            )
            
            if (showWireFrame)
            {
                // draw wireframe
                encoder.setVertexBuffer(drawModeWireBuffer!, offset:0, index:2)
                encoder.drawIndexedPrimitives(
                    type: .line,
                    indexCount: 10,
                    indexType: .uint16,
                    indexBuffer: rectWireIdxBuffer!,
                    indexBufferOffset: 0,
                    instanceCount: vertexCount - 1
                )
            }
        }
    }
}
