import Foundation
import MetalKit

class Rectangle {
    public var vertexBuffer:MTLBuffer?
    public var indexBufferTriangle:MTLBuffer?
    public var indexBufferWireframe:MTLBuffer?
    
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
//        0, 2
    ]
    
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

class RoundShape {
    public var vertexBuffer:MTLBuffer?
    public var indexBufferTriangle:MTLBuffer?
    public var indexBufferWireframe:MTLBuffer?
    
    public var roundRes: Int;
    
    public let vertices: [SIMD2<Float>]
    public let indicesTriangle: [UInt16]
    public let indicesWireframe: [UInt16]
    
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
        
        self.vertices = vertices
        self.indicesTriangle = indicesFill.map(UInt16.init)
        self.indicesWireframe = indicesWire.map(UInt16.init)
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
