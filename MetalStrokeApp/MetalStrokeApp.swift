import SwiftUI

@main
struct MetalStrokeApp: App {
    var body: some Scene {
        let W: CGFloat = 640
        WindowGroup {
            ContentView()
                .frame(width: W, height: W)
                .padding(30)
        }
    }
}
