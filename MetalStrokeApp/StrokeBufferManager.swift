import MetalKit

class StrokeBufferManager: ObservableObject {
    
    class Stroke {
        var vertices: [Vertex]
        var width: Float
        var color: NSColor
        
        init(vertices: [Vertex]=[], width: Float, color: NSColor) {
            self.vertices = vertices
            self.width = width
            self.color = color
        }
    }
    
    struct Vertex {
        // align in 16B
        var position: SIMD2<Float> = .zero  // 8B
        var color: SIMD4<Float> = .zero     // 16B
        var radius: Float = 0               // 4B
        var end: Float = 0                  // 4B (-1:start, 0:mid, 1:end)
    }
    
    private var currentStroke: Stroke?
    private var strokes:[Stroke] = []
    
    public var vertices: [SIMD2<Float>] = []
    private(set) var vertexCount: Int = 0
    
    public var isDirty: Bool = false
    
    private var strokeWidth: Float = 1
    private var strokeWidthScale: Float = 1
    
    // buffer chunks
    private let BFFR_CHNK_SIZE: Int = 300
    private var currChunkNum: Int = 0
    private var vertexBuffer: MTLBuffer?
    

    static let VTX_STRIDE = MemoryLayout<Vertex>.stride
    static let VTX_EMPTY = Vertex()
    
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
    
    
    /*
     Vertex Buffer APIs
     */
    public func markEndVertices() {
        var end: Float = 0
        strokes.forEach() { stroke in
            if stroke.vertices.count > 1 {
                for i in 0 ..< stroke.vertices.count {
                    switch i {
                        case 0: end = -1
                        case stroke.vertices.count - 1: end = 1
                        default: end = 0
                    }
                    stroke.vertices[i].end = end
                }
            }
        }
    }
    
    // update buffer by current state of Strokes
    public func updateBuffer(device: MTLDevice) {
        guard isDirty else { return }
        
        markEndVertices()
        let allVertices = strokes.flatMap{ $0.vertices }
        let newVertexNum = strokes.reduce(0){ $0 + $1.vertices.count }
        
        let newChunkNum = (newVertexNum + BFFR_CHNK_SIZE - 1) / BFFR_CHNK_SIZE
        let newCapacity = newChunkNum * BFFR_CHNK_SIZE
        
        // expand buffer if necesarry
        if currChunkNum < newChunkNum {
            vertexBuffer = device.makeBuffer(length: newCapacity * StrokeBufferManager.VTX_STRIDE)
            currChunkNum = newChunkNum
            print("____BUMP UP CHUNK: \(newCapacity)")
        }
        
        if let ptr = vertexBuffer?.contents().bindMemory(to: Vertex.self, capacity: newCapacity)
        {
            for (i, vertex) in allVertices.enumerated() {
                ptr[i] = vertex
                ptr[i].radius *= strokeWidthScale
            }
            
            (ptr + newVertexNum).initialize(
                repeating: StrokeBufferManager.VTX_EMPTY,
                count: newCapacity - newVertexNum
            )
        }
        
        vertexCount = newVertexNum
        isDirty = false
    }
    
    func getVertexBuffer() -> MTLBuffer? {
        return vertexCount > 1 ? vertexBuffer : nil
    }

    
    
    /*
     Drawing APIs
     */
    
    func startStroke(color: NSColor = .blue, width:Float = 0.1) {
        let stroke = Stroke(width: width, color: color)
        currentStroke = stroke
        strokes.append(stroke)
        
//        isDirty = true
        print("start stroke: \(strokes.count)")
    }
    
    func addPoint(pos: SIMD2<Float>, color: SIMD4<Float>, radius: Float=0.05) {
        let firstPoint = currentStroke == nil
        if firstPoint {
            startStroke()
        }
        
        if let stroke = currentStroke {
            let vert = Vertex(
                position: pos,
                color: color,
                radius: radius
            )
            stroke.vertices.append(vert)
            isDirty = true
        }
        
        print("stroke: \(strokes.count), vert: \(currentStroke!.vertices.count)")
//        strokes.forEach { str in print(str.vertices) }
    }
    
    func endStroke() {
        currentStroke = nil
        isDirty = true
        print("end stroke: \(strokes.count)")
    }
    
    
    func setStrokeWidthScale (_ value: Float){
        if (self.strokeWidthScale != value) {
            self.strokeWidthScale = value
            self.isDirty = true
        }
    }
    
    func setFinalRadius (_ value: Float) {
        if let stroke = currentStroke {
            stroke.vertices[stroke.vertices.count - 1].radius = value
            self.isDirty = true
        }
    }
    
    func clearAll() {
        strokes.removeAll()
        vertices.removeAll()
        currentStroke = nil
        vertexCount = 0
        self.isDirty = true
    }
    
}
