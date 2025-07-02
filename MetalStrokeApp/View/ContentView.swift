import SwiftUI
import MetalKit

struct ContentView: View {
    @StateObject var strokeModel = StrokeModel()
    
    @State private var strokeWidth:Float = 2.0
    @State private var showWireFrame:Bool = true

    var body: some View {
        VStack {
            ZStack(alignment: .topLeading) {
                MetalView(
                    strokeWidth: $strokeWidth,
                    showWireFrame: $showWireFrame
                )
                    .environmentObject(strokeModel)
//                  .frame(minWidth: 640, minHeight: 640)

                /*
                Text("FPS \(renderer.fps, specifier: "%.2f")")
                    .foregroundColor(.white)
                    .padding()
                 */
            }
            
            HStack {
                Slider(
                    value: $strokeWidth,
                    in: 0...5
                )
                .frame(width: 240)
                .padding()
                
                Text("Width Scale: \(strokeWidth, specifier: "%.1f")")
                    .font(.custom("Monaco", size: 14))
                
                Spacer()
                
                Toggle("Wireframe", isOn: $showWireFrame)
                    .padding()
            }
        }
    }
}

#Preview {
    ContentView()
}
