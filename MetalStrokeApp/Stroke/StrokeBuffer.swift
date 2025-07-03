import MetalKit

class StrokeBuffer {
    static let VTX_STRIDE = MemoryLayout<StrokeModel.Vertex>.stride
    static let VTX_EMPTY = StrokeModel.Vertex()
    
    // current buffer state
    private let BFFR_CHNK_SIZE: Int = 300
    private var currChunkNum: Int = 0
    
    private(set) var vertexBuffer: MTLBuffer?
    private(set) var vertexCount:Int = 0
    
    private(set) var centerLineIndexCount = 0
    private(set) var centerLineIndexBuffer:MTLBuffer?
    
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
        
        desc.layouts[0].stride = StrokeBuffer.VTX_STRIDE
        
        return desc;
    }
    
    
    // update buffer by current state of Strokes
    public func updateBuffer(from model:StrokeModel, device: MTLDevice) {
        guard model.isDirty else { return }
        
        let allVertices = model.getFlatVertexList()
        let newVertexNum = allVertices.count
        
        guard newVertexNum > 1 else {
            self.vertexCount = 0
            return
        }
        
        let newChunkNum = (newVertexNum + BFFR_CHNK_SIZE - 1) / BFFR_CHNK_SIZE
        let newCapacity = newChunkNum * BFFR_CHNK_SIZE
        
        // expand buffer if necesarry
        if currChunkNum < newChunkNum {
            vertexBuffer = device.makeBuffer(length: newCapacity * StrokeBuffer.VTX_STRIDE)
            currChunkNum = newChunkNum
            print("____BUMP UP CHUNK: \(newCapacity)")
        }
        
        if let ptr = vertexBuffer?.contents().bindMemory(to: StrokeModel.Vertex.self, capacity: newCapacity)
        {
            for (i, vertex) in allVertices.enumerated() {
                ptr[i] = vertex
                ptr[i].radius *= model.strokeWidthScale
            }
            
            (ptr + newVertexNum).initialize(
                repeating: StrokeBuffer.VTX_EMPTY,
                count: newCapacity - newVertexNum
            )
        }
        
        updateCenterIndexBuffer(from:model.strokes, device: device)
        
        self.vertexCount = newVertexNum
        model.isDirty = false
    }
    
    func updateCenterIndexBuffer(from strokes:[StrokeModel.Stroke], device: MTLDevice) {
        guard strokes.count > 0 else { return }
        
        var idx_off: Int = 0
        var indices: [UInt16] = []
        
        for stroke in strokes {
            guard stroke.vertices.count > 1 else {continue}
            
            for i in 1 ..< stroke.vertices.count {
                indices.append(UInt16(idx_off + i - 1))
                indices.append(UInt16(idx_off + i))
            }
            idx_off += stroke.vertices.count
        }
        
        guard indices.count > 1 else { return }
        
        self.centerLineIndexCount = indices.count
        self.centerLineIndexBuffer =  device
            .makeBuffer( bytes: indices, length: indices.count * MemoryLayout<UInt16>.size )
    }
    
    func getLatest() -> MTLBuffer? {
        vertexCount > 1 ? vertexBuffer : nil
    }
}
