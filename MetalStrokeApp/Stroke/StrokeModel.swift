import Foundation
import MetalKit

class StrokeModel: ObservableObject {
    class Stroke {
        // add width/color/joinType... for common setting
        var vertices: [Vertex] = []
    }
    
    struct Vertex {
        // align in 16B
        var position: SIMD2<Float> = .zero  // 8B
        var color: SIMD4<Float> = .zero     // 16B
        var radius: Float = 0               // 4B
        var end: Float = 0                  // 4B (-1:start, 0:mid, 1:end)
        var capType: CapType = .square
        var joinType: JoinType = .miter
        var reserved0: UInt8 = 0
        var reserved1: UInt8 = 0
    }
    
    
    public var strokes:[Stroke] = []
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
    
    public func getFlatVertexList(keepSinglePointStroke: Bool = false) -> [Vertex] {
        let targetStrokes = keepSinglePointStroke ? strokes : strokes.filter{ $0.vertices.count > 1 }
        return targetStrokes.flatMap{ $0.vertices }
    }
    
    
    /*
     Drawing APIs
     */
    
    func startStroke() {
        let stroke = Stroke();
        currentStroke = stroke
        strokes.append(stroke)
        
//        print("start stroke: \(strokes.count)")
    }
    
    func addPoint(
        pos: SIMD2<Float>,
        color: SIMD4<Float>,
        radius: Float=0.05,
        capType: StrokeModel.CapType = .round,
        joinType: StrokeModel.JoinType = .round
    ) {
        let firstPoint = currentStroke == nil
        if firstPoint {
            startStroke()
        }
        
        if let stroke = currentStroke {
            let vert = Vertex(
                position: pos,
                color: color,
                radius: radius,
                capType: capType,
                joinType: joinType
            )
            stroke.vertices.append(vert)
            isDirty = true
        }
        
//        print("stroke: \(strokes.count), vert: \(currentStroke!.vertices.count)")
//        strokes.forEach { str in print(str.vertices) }
    }
    
    func setStrokes(_ strokes: [Stroke]) {
        self.strokes = strokes
        self.isDirty = true
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
    
    // use for drag-to-scale
    func updateLatestPosition (_ value: SIMD2<Float>) {
        if let stroke = currentStroke {
            stroke.vertices[stroke.vertices.count - 1].position = value
            self.isDirty = true
        }
    }
    
    func clearAll() {
        strokes.removeAll()
        currentStroke = nil
        self.isDirty = true
    }
}
