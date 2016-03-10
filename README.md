# GraphVisualize
Graph visualization using `GLVisualize.jl` by Simon Danisch. Tightly integrated
with `LightGraphs.jl`.

This is a pre-alpha version.

## Install
```julia
Pkg.clone("https://github.com/JuliaGraphs/GraphVisualize.jl")
Pkg.checkout("GLVisualize")
Pkg.checkout("GLAbstraction")
```

## Usage
For the time being only the function
```julia
    plot(g::Graph; observe=false)
```
returning an observer of graph `g`, is exported.

You can left-click and drag a vertex to move it around.

```julia
using LightGraphs
using GraphVisualize

g = WheelGraph(10)
obs = plot(g, observe=true)   # a windows pops up displaying g

add_edge!(g, 3, 7)      # the plot is updated
rem_edge!(g, 3, 7)      # the plot is updated
rem_vertex!(g, 3)       # the plot is updated
add_vertex!(g)          # the plot is updated

# manually close the window before next commands

obs = plot(g, observe=false)   # a windows pops up displaying g
add_edge!(g, 3, 7)      # the plot is NOT updated
push!(obs, g)          # the plot is updated
...

```
