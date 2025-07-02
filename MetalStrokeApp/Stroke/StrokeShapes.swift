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
        0, 2
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
