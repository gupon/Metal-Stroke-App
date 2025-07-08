# MetalStrokeApp

![Preview](Images/app_preview01.png)
![Preview](Images/app_preview02.png)

A stroke-drawing app built with Metal + SwiftUI.  
Aimed for a small exercise in learning Metal, achieving the most basic features for stroke.

## Features 

### Per-vertex control over:
  - Color
  - Radius (stroke width)
  - Join type (`miter`, `bevel`, `round`)
  - Cap type (`butt`, `square`, `round`)
  - Z-position

So you can
- make gradient along stroke
- make tapered line
- cross its own stroke (under or over)

### Make full use of instanced drawing
- No mesh construction per-frame inside CPU 
  - only list of vertex & attributes are passed to shaders
- Entire stroke is formed from basic 3 shapes (quad, triangle, pie)
  - each deformed by vertex shader
  - no polygon overwrapping in caps/joins
    - works well with gradients, alpha blending
- Maximum 3 draw calls for infinite number & types of strokes
  - draws separated only by base shapes, not by strokes
  - each result combined with depth properly

## Limitation
- Miter Limit
- No way to set width/color/cap/join types in drawing mode 😉
  - selected from all types by order


## Try Drawing
You can draw strokes manually by:

- **Left click** to add a point with randomized color
- **Right click** to clear the canvas
- **Return key (⏎)** to finalize a stroke

## Try Drawing (by code)
Replace codes inside
- `InteractiveMTKView(...)` : Handling mouse event
- `FrameUpdater.update(...)` : Generating wave motion

