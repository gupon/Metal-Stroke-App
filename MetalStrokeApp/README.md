# MetalStrokeApp

A simple stroke-drawing engine built with Metal and SwiftUI.  
Built for personal learning to get familiar with Metal fundamentals.  

## Features

- Per-vertex control over:
  - **Color**
  - **Radius (stroke width)**
  - **Join type** (`miter`, `bevel`, `round`)
  - **Cap type** (`butt`, `square`, `round`)
- Efficient rendering using **instanced drawing** and **custom vertex shaders**

## Usage

Responds to mouse input as follows:

- **Left click** to add a point with randomized color
- **Right click** to clear the canvas
- **Return key (⏎)** to finalize a stroke

Under the hood, calling `addPoint(pos:color:radius:)` adds a point to the stroke.  
The position is mapped from window coordinates to Metal’s coordinate system inside `toMetalPos(...)`.


You can find the core interaction logic in:
- `InteractiveMTKView.mouseDown(...)`
- `StrokeModel.addPoint(...)`

##  Tech Stack

- SwiftUI + AppKit bridging (`NSViewRepresentable`)
- Metal for custom GPU rendering
- Shader logic written in `.metal` files

##  Notes

This is a learning-focused personal project, not production-ready.  
Feel free to explore, learn, or fork as needed!

