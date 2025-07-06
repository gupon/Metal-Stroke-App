import Foundation
import MetalKit

class StrokeModel: ObservableObject {
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
        var capType: CapType = .round
        var joinType: JoinType = .round
        var reserved0: UInt8 = 0
        var reserved1: UInt8 = 0
    }
    
    
    @Published var strokes:[Stroke] = []
    private var currentStroke: Stroke?
    
    public var isDirty: Bool = false
    public var strokeWidthScale: Float = 1
    
    
    enum CapType: UInt8, CaseIterable {
        case butt = 0, square = 1, round = 2
    }
    
    enum JoinType: UInt8, CaseIterable {
        case miter = 0, bevel = 1, round = 2
    }
    
    /*
     mark stroke first/end point as ends
     */
    public func markEndVertices() {
        var end: Float = 0
        var cap: CapType = .square
        
        strokes.forEach() { stroke in
            if stroke.vertices.count > 1 {
                for i in 0 ..< stroke.vertices.count {
                    switch i {
                        case 0:
                            end = -1
//                        cap = .square
                        case stroke.vertices.count - 1:
                            end = 1
//                        cap = .square
                        default: end = 0
                    }
                    stroke.vertices[i].end = end
                    stroke.vertices[i].capType = cap
                }
            }
        }
    }
    
    public func getFlatVertexList(keepSinglePointStroke: Bool = false) -> [Vertex] {
        let targetStrokes = keepSinglePointStroke ? strokes : strokes.filter{ $0.vertices.count > 1 }
        return targetStrokes.flatMap{ $0.vertices }
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
                radius: radius,
                capType: .round,
                joinType: JoinType.allCases.randomElement()!
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
        currentStroke = nil
        self.isDirty = true
    }
}
