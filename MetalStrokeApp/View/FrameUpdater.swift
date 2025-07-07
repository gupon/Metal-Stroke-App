import SwiftUI

class FrameUpdater: ObservableObject {
    private var model: StrokeModel
    private var startDate: Date
    
    private var capTypes: [StrokeModel.CapType]
    private var joinTypes: [StrokeModel.JoinType]
    
    public var numpt: Int = 5

    init(model: StrokeModel) {
        self.model = model
        startDate = Date()
        
        capTypes = StrokeModel.CapType.allCases
        joinTypes = StrokeModel.JoinType.allCases
    }
    
    func update (_ date: Date) {
        let t = Float(date.timeIntervalSince(startDate))
        
        let stroke = StrokeModel.Stroke()
        
        let typeOffset = Int(floor(t / 1.0))
        
        for i in 0 ..< numpt {
            let u = Float(i) / Float(numpt - 1)
            let amp = 0.25 + (cos(u * .pi - t * 4) + 1) * 0.25
            let x = (u - 0.5) * 1.5
            let y = sin(u * .pi * 2.5 + t * 3) * amp
            
            let v = StrokeModel.Vertex(
                position: SIMD2<Float>(x, y),
                color: SIMD4<Float>(0.0, 0.2, 0.75, 1),
                radius: 0.01,
                capType: capTypes[(i + typeOffset) % 3],
                joinType: joinTypes[(i + typeOffset) % 3]
            )
            stroke.vertices.append(v)
        }
        
        model.strokes = [stroke]
        model.isDirty = true
//        print(t)
    }
}
