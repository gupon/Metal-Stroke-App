import MetalKit

class Renderer: NSObject, MTKViewDelegate, ObservableObject {
    let device: MTLDevice
    private let cmdQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    
    private var tLastDraw: CFTimeInterval = CACurrentMediaTime()
    @Published private(set) var fps: Double = 0
    
    public var vertices: [SIMD2<Float>] = []
    private var vertexCount: Int = 0
    private let BFFR_CHNK_SIZE: Int = 100
    public var isDirty: Bool = false
    
    struct StrokeVertex {
        // align in 16B
        var position: SIMD2<Float>  // 8B
        var color: SIMD4<Float>     // 16B
        var radius: Float           // 4B
        var _pad: Float = 0         // 4B
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
    }
    
    private func buildPipeline() {
        let library = device.makeDefaultLibrary()
        
        // pipeline
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = library?.makeFunction(name: "vtx_main")
        desc.fragmentFunction = library?.makeFunction(name: "frag_main")
        desc.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        
        // vertex
        let vdesc = MTLVertexDescriptor()
        // --position (SIMD2<Float>)
        vdesc.attributes[0].format = .float2
        vdesc.attributes[0].offset = 0
        vdesc.attributes[0].bufferIndex = 0

        // --color (SIMD4<Float>)
        vdesc.attributes[1].format = .float4
        vdesc.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        vdesc.attributes[1].bufferIndex = 0

        // --radius (Float)
        vdesc.attributes[2].format = .float
        vdesc.attributes[2].offset =
            MemoryLayout<SIMD2<Float>>.stride +
            MemoryLayout<SIMD4<Float>>.stride
        vdesc.attributes[2].bufferIndex = 0
        
        vdesc.layouts[0].stride = VTX_STRIDE
        
        // set to PipelineDescriptor
        desc.vertexDescriptor = vdesc
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: desc)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }
    
    private func updateVertexBuffer() {
        if (!isDirty) {return}
        
        let newBulkNum = (vertices.count + BFFR_CHNK_SIZE - 1) / BFFR_CHNK_SIZE
        let currentBulkNum = (vertexCount + BFFR_CHNK_SIZE - 1) / BFFR_CHNK_SIZE
        let newCapacity = newBulkNum * BFFR_CHNK_SIZE
        
        // expand buffer if necesarry
        if currentBulkNum < newBulkNum {
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
                let sv = StrokeVertex(position: .zero, color: .zero, radius: .zero, _pad: 0)
                (newPtr + vertexCount).initialize(repeating: sv, count: newCapacity - vertexCount)
            }
            print("new capacity: \(newCapacity)")
        }
        
        // copy new points
        let prevCount = vertexCount
        if (vertices.count > vertexCount + 2) {
            print("new points: \(vertices.count - vertexCount)")
        }
        if let ptr = vertexBuffer?.contents().bindMemory(to: StrokeVertex.self, capacity: newCapacity)
        {
            for i in prevCount..<vertices.count {
                ptr[i] = StrokeVertex(
                    position: vertices[i],
                    color: SIMD4<Float>(1,0,0,1),
                    radius: 2.0
                )
            }
        }
        
        vertexCount = vertices.count
        isDirty = false
    }
    
    func addPoint(p: NSPoint) {
        
    }
    
    // for resize event
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
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

        if vertexCount > 0, let vbuffer = vertexBuffer
        {
            encoder.setVertexBuffer(vbuffer, offset: 0, index: 0)
            encoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: vertexCount)
        }
    }
}
