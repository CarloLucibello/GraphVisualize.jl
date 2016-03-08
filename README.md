# GraphVisualize
Graph visualization using `GLVisualize.jl` by Simon Danisch. Tightly integrated
with `LightGraphs.jl`.

This is a pre-alpha version.

## Usage
```julia
using LightGraphs
using GraphVisualize

g = WheelGraph(10)
plot(g)
```
