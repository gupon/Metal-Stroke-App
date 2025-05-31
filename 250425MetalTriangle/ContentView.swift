import SwiftUI
import MetalKit

struct ContentView: View {
    @StateObject var renderer = Renderer()
    
    @State private var strokeWidth:Float = 1.0
    @State private var showWireFrame:Bool = true
    
    
    var body: some View {
        VStack {
            ZStack(alignment: .topLeading) {
                MetalView()
                //                .frame(minWidth: 640, minHeight: 640)
                    .environmentObject(renderer)
                
                Text("FPS \(renderer.fps, specifier: "%.2f")")
                    .foregroundColor(.white)
                    .padding()
            }
            
            HStack {
                Slider(
                    value: $strokeWidth,
                    in: 0...5
                )
                .frame(width: 240)
                .padding()
                .onChange(of: strokeWidth) {
                    renderer.setStrokeWidth(strokeWidth)
                }
                
                Text("Width: \(strokeWidth, specifier: "%.1f")")
                    .font(.custom("Monaco", size: 14))
                
                Spacer()
                
                Toggle("Wireframe", isOn: $showWireFrame)
                    .padding()
                    .onChange(of: showWireFrame) {
                        renderer.setWireframe(showWireFrame)
                    }
            }
        }
    }
}

#Preview {
    ContentView()
}
