import SwiftUI
import MetalKit

struct ContentView: View {
    @StateObject private var strokeModel: StrokeModel
    @StateObject private var renderOptions :RenderOptions
    @StateObject private var renderer :Renderer
    @StateObject private var frameUpdater: FrameUpdater
    
    @State private var strokeWidth: Float = 5.0
    @State private var numPoint: Float = 5
    @State private var isMotionEnabled: Bool = false

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
                            if (isMotionEnabled) {
                                frameUpdater.update(context.date)
                            }
                        }
                }
                Text("FPS \(renderer.fps, specifier: "%.2f")")
                    .foregroundColor(.white)
                    .padding()
            }
            .padding(.bottom, 8)

            HStack (alignment: .center) {
                VStack (alignment: .leading, spacing: 12) {
                    HStack {
                        Slider( value: $strokeWidth, in: 0 ... 20)
                            .frame(width: 180)
                            .padding(.trailing, 8)
                        
                        Text("Width Scale: \(strokeWidth, specifier: "%.1f")")
                    }
                    HStack {
                        Slider( value: $numPoint,in: 5 ... 30, step: 1)
                            .frame(width: 180)
                            .padding(.trailing, 8)
                            .disabled(!isMotionEnabled)
                            .onChange(of: numPoint) { frameUpdater.numpt = Int(numPoint) }
                        
                        Text("Num Points: \(numPoint, specifier: "%.f")")
                    }
                }
                
                Spacer()
                
                VStack (alignment: .leading, spacing: 8) {
                    Toggle("Wireframe", isOn: $renderOptions.wireFrame)
                    Toggle("Debug Color", isOn: $renderOptions.debug)
                    Toggle("Wave Motion", isOn: $isMotionEnabled)
                        .onChange(of: isMotionEnabled) {
                            if !isMotionEnabled {
                                strokeModel.clearAll()
                            }
                        }
                }
                .padding(.trailing, 18)
            }
        }
    }
}

#Preview {
    ContentView()
}
