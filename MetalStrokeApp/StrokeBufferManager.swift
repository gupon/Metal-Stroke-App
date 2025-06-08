import MetalKit

class StrokeBufferManager: ObservableObject {
    
    public var vertices: [SIMD2<Float>] = []
    private(set) var vertexCount: Int = 0
    
    public var isDirty: Bool = false
    
    private var strokeWidth: Float = 1
    
    // buffer chunks
    private let BFFR_CHNK_SIZE: Int = 300
    private var currChunkNum: Int = 0
    private var vertexBuffer: MTLBuffer?
    
    struct StrokeVertex {
        // align in 16B
        var position: SIMD2<Float>  // 8B
        var color: SIMD4<Float>     // 16B
        var radius: Float           // 4B
        var end: Float              // 4B
    }
    
    static let VTX_STRIDE = MemoryLayout<StrokeVertex>.stride
    
    public func getVertexDescriptor() -> MTLVertexDescriptor {
        // vertex descriptor
        let desc = MTLVertexDescriptor()
        var offset = 0
        
        // --position (SIMD2<Float>)
        desc.attributes[0].format = .float2
        desc.attributes[0].offset = offset
        desc.attributes[0].bufferIndex = 0
        offset += MemoryLayout<SIMD2<Float>>.stride
        
        // --color (SIMD4<Float>)
        desc.attributes[1].format = .float4
        desc.attributes[1].offset = offset
        desc.attributes[1].bufferIndex = 0
        offset += MemoryLayout<SIMD4<Float>>.stride
        
        // --radius (Float)
        desc.attributes[2].format = .float
        desc.attributes[2].offset = offset
        desc.attributes[2].bufferIndex = 0
        offset += MemoryLayout<Float>.stride
        
        // --end (Float)
        desc.attributes[3].format = .float
        desc.attributes[3].offset = offset
        desc.attributes[3].bufferIndex = 0
        offset += MemoryLayout<Float>.stride
        
        desc.layouts[0].stride = StrokeBufferManager.VTX_STRIDE
        
        return desc;
    }
    
    
    public func updateBuffer(device: MTLDevice) {
        if (!isDirty) {return}
        
        let newChunkNum = (vertices.count + BFFR_CHNK_SIZE - 1) / BFFR_CHNK_SIZE
        let newCapacity = newChunkNum * BFFR_CHNK_SIZE
        
        // expand buffer if necesarry
        if currChunkNum < newChunkNum {
            let oldBuffer = vertexBuffer
            vertexBuffer = device.makeBuffer(length: newCapacity * StrokeBufferManager.VTX_STRIDE)
            
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
    
    
    func setStrokeWidth (_ value:Float){
        if (self.strokeWidth != value) {
            self.strokeWidth = value
            self.isDirty = true
        }
    }
    
    
    func getVertexBuffer() -> MTLBuffer? {
        return vertexCount > 1 ? vertexBuffer : nil
    }
}
