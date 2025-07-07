import SwiftUI
import MetalKit

struct ContentView: View {
    @StateObject private var strokeModel: StrokeModel
    @StateObject private var renderOptions :RenderOptions
    @StateObject private var renderer :Renderer
    @StateObject private var frameUpdater: FrameUpdater
    
    @State private var strokeWidth:Float = 15.0
    @State private var numPoint: Float = 5
    
    init () {
        let model = StrokeModel()
        let options = RenderOptions()
        
        _strokeModel = StateObject(wrappedValue: model)
        _renderOptions = StateObject(wrappedValue: options)
        _renderer = StateObject(wrappedValue: Renderer(model, options: options))
        
        _frameUpdater = StateObject(wrappedValue: FrameUpdater(model: model))
    }

    var body: some View {
        VStack {
            ZStack(alignment: .topLeading) {
                TimelineView(.animation) { context in
                    MetalView(strokeWidth: $strokeWidth)
                        .environmentObject(strokeModel)
                        .environmentObject(renderOptions)
                        .environmentObject(renderer)
                        .onChange(of: context.date) {
                            frameUpdater.update(context.date)
                        }
                }
                Text("FPS \(renderer.fps, specifier: "%.2f")")
                    .foregroundColor(.white)
                    .padding()
            }
            .padding(.bottom, 16)


            
            /*
            Slider( value: $numPoint,in: 3 ... 20, step: 1)
                .frame(width: 180)
                .padding()
                .onChange(of: numPoint) { frameUpdater.numpt = Int(numPoint) }
             */
            HStack {
                VStack (alignment: .leading, spacing: 12) {
                    HStack {
                        Slider( value: $strokeWidth, in: 0 ... 20)
                            .frame(width: 180)
                            .padding(.trailing, 8)
                        
                        Text("Width Scale: \(strokeWidth, specifier: "%.1f")")
                            .font(.custom("Monaco", size: 14))
                    }
                    HStack {
                        Slider( value: $numPoint,in: 5 ... 30, step: 1)
                            .frame(width: 180)
                            .padding(.trailing, 8)
                            .onChange(of: numPoint) { frameUpdater.numpt = Int(numPoint) }
                        
                        Text("Num Points: \(numPoint, specifier: "%.f")")
                            .font(.custom("Monaco", size: 14))
                    }
                }
                
                Spacer()
                
                VStack (alignment: .leading, spacing: 12) {
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
