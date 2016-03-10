# GraphVisualize
Graph visualization using `GLVisualize.jl` by Simon Danisch. Tightly integrated
with `LightGraphs.jl`.

This is a pre-alpha version.

## Usage
```julia
using LightGraphs
using GraphVisualize

g = WheelGraph(10)
sg, sw = plot(g, observe=true)   # a windows pops up displaying g

add_edge!(g, 3, 7)   # the plot is updated
rem_edge!(g, 3, 7)   # the plot is updated
rem_vertex!(g, 3)    # the plot is updated
add_vertex!(g)    # BUG: the plot is NOT updated, need to close the window and replot

# close the window
sg, sw = plot(g, observe=false)   # a windows pops up displaying g
add_edge!(g, 3, 7)   # the plot is NOT updated
push!(sg, g)         # the plot is updated
...

```
