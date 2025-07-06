import SwiftUI
import MetalKit

struct ContentView: View {
    @StateObject private var strokeModel: StrokeModel
    @StateObject private var renderOptions :RenderOptions
    
    @State private var strokeWidth:Float = 4.0
    
    init () {
        let model = StrokeModel()
        let options = RenderOptions()
        
        _strokeModel = StateObject(wrappedValue: model)
        _renderOptions = StateObject(wrappedValue: options)
//        _renderer = StateObject(wrappedValue: Renderer(model, options: options))
    }

    var body: some View {
        VStack {
            ZStack(alignment: .topLeading) {
                MetalView(strokeWidth: $strokeWidth)
                    .environmentObject(strokeModel)
                    .environmentObject(renderOptions)
//                  .frame(minWidth: 640, minHeight: 640)

                /*
                Text("FPS \(renderer.fps, specifier: "%.2f")")
                    .foregroundColor(.white)
                    .padding()
                */
            }
            .padding(.bottom, 16)
            
            HStack {
                Slider(
                    value: $strokeWidth,
                    in: 0 ... 20
                )
                .frame(width: 180)
                .padding()
                
                Text("Width Scale: \(strokeWidth, specifier: "%.1f")")
                    .font(.custom("Monaco", size: 14))
                
                Spacer()
                
                VStack (alignment: .leading) {
                    Toggle("Wireframe", isOn: $renderOptions.wireFrame)
                    Toggle("Debug", isOn: $renderOptions.debug)
                }
                .padding(.trailing, 16)
            }
        }
    }
}

#Preview {
    ContentView()
}
