import Foundation
import MetalKit

protocol BufferedStrokeShape {
    var vertexBuffer: MTLBuffer? { get }
    var indexBufferTriangle: MTLBuffer? { get }
    var indexBufferWireframe: MTLBuffer? { get }
    
    var vertices: [SIMD2<Float>] { get }
    var indicesTriangle: [UInt16] { get }
    var indicesWireframe: [UInt16] { get }
}


class BaseShape: BufferedStrokeShape {
    var vertexBuffer: (any MTLBuffer)?
    var indexBufferTriangle: (any MTLBuffer)?
    var indexBufferWireframe: (any MTLBuffer)?
    
    private let _vertices: [SIMD2<Float>];
    private let _indicesTriangle: [UInt16];
    private let _indicesWireframe: [UInt16];
    
    var vertices: [SIMD2<Float>] { return _vertices }
    var indicesTriangle: [UInt16] { return _indicesTriangle }
    var indicesWireframe: [UInt16] {return _indicesWireframe }
    
    init (
        vertices: [SIMD2<Float>],
        indicesTriangle:[UInt16],
        indicesWireframe: [UInt16]
    ) {
        self._vertices = vertices
        self._indicesTriangle = indicesTriangle
        self._indicesWireframe = indicesWireframe
    }
    
    public func createBuffers(_ device:MTLDevice) {
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: vertices.count * MemoryLayout<SIMD2<Float>>.stride,
            options: []
        )
        
        indexBufferTriangle = device.makeBuffer(
            bytes: indicesTriangle,
            length: indicesTriangle.count * MemoryLayout<UInt16>.size,
            options: []
        )
        
        indexBufferWireframe = device.makeBuffer(
            bytes: indicesWireframe,
            length: indicesWireframe.count * MemoryLayout<UInt16>.size,
            options: []
        )
    }
}


class Rectangle: BaseShape {
    init() {
        let vertices: [SIMD2<Float>] = [
            [-0.5, 0.0], [0.5, 0.0],
            [0.5, 1.0], [-0.5, 1.0]
        ]
        
        let indicesTriangle: [UInt16] = [
            0, 1, 2,
            0, 2, 3
        ]
        
        let indicesWireframe: [UInt16] = [
            0, 1,
            1, 2,
            2, 3,
            3, 0,
//          0, 2
        ]

        super.init(
            vertices: vertices,
            indicesTriangle: indicesTriangle,
            indicesWireframe: indicesWireframe
        )
    }
}


class RoundShape: BaseShape {
    public var roundRes: Int;
    
    init(roundRes:Int = 1) {
        self.roundRes = roundRes
        
        // init vertices
        var indicesFill: [Int] = []
        var indicesWire: [Int] = [0, 1]

        let angleStep = Float.pi * 0.5 / Float(roundRes)
        var vertices: [SIMD2<Float>] = [[0.0, 0.0]]     // add origin
        
        for i in 0...roundRes {
            let angle = angleStep * Float(i)
            vertices.append([cos(angle), sin(angle)])
            
            if i > 0 {
                indicesFill.append(contentsOf: [0, i, i+1])
                indicesWire.append(contentsOf: [i, i+1, i+1, 0])
            }
        }
        
        super.init(
            vertices: vertices,
            indicesTriangle: indicesFill.map(UInt16.init),
            indicesWireframe: indicesWire.map(UInt16.init)
        )
    }
    
}
