using GraphVisualize
using LightGraphs
using Base.Test

g = WheelGraph(10)
plot(g, observe=true)
