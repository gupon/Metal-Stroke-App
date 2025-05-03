import SwiftUI
import MetalKit

struct ContentView: View {
    @StateObject var renderer = Renderer()
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            MetalView()
                .frame(minWidth: 640, minHeight: 640)
                .environmentObject(renderer)
            Text("FPS \(renderer.fps, specifier: "%.2f")")
                .foregroundColor(.white)
                .padding()
        }
        .padding(60)
    }
}

#Preview {
    ContentView()
}
