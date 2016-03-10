#__precompile__()
module GraphVisualize
# Credits for original code: Simon Danisch
# Contributors: Carlo Lucibello

export plot

using GLVisualize
using LightGraphs
using GraphLayout
using GeometryTypes, GLAbstraction, Reactive, GLWindow, GLFW
import Base: push!

type GraphObserver
    glast::Graph
    g::Graph
    sg::Signal{Graph}
    sw::Signal{Bool}
end
GraphObserver(g::Graph) = GraphObserver(Graph(), g, Signal(g), Signal(false))

function set_observation_fps!(obs::GraphObserver, f)
    obs.sw = map(delta -> begin
            if has_changed(obs)
                observe!(obs)
                return true
            else
                return false
            end
        end, f)
end

function observe!(obs::GraphObserver, g::Graph)
    obs.glast = deepcopy(g)
    obs.g = g
    push!(obs.sg, g)
end
observe!(obs::GraphObserver) = observe!(obs, obs.g)

push!(obs::GraphObserver, g::Graph) = push!(obs.sg, g)

has_changed(obs::GraphObserver) = !(nv(obs.glast) == nv(obs.g) &&  ne(obs.glast) == ne(obs.g))
has_really_changed(obs::GraphObserver) = !(obs.glast == obs.g)

function edgelist(g::Graph)
    indices = Vector{Int32}(2ne(g))
    i = 0
    for (u,v) in edges(g)
        indices[i+=1] = u
        indices[i+=1] = v
    end
    indices
end

function layout(g::Graph, wsize, psize)
    x, y = layout_spring_adj(full(adjacency_matrix(g)))
    return [Point2f0(2psize,2psize) + (Point2f0(x[i], y[i]) + Point2f0(1.,1.))* (wsize-4psize)/2 for i=1:nv(g)]
end

"""
    plot(g::Graph; observe=false)

Creates an OpenGL window and draws `g` in it. If `observe==true` future modifications of
`g` will be reflected in the plot. Returns a `GraphObserver` of `g`.
"""
function plot(g::Graph; observe=false)
    obs = GraphObserver(g)
    observe && set_observation_fps!(obs, fps(10.0))
    plot(obs)
    return obs
end

function plot(obs::GraphObserver)
    g = obs.sg
    wsize = 900
    psize = 15f0

    window = glscreen(resolution=(wsize, wsize))

    const record_interactive = true
    vpos = const_lift(layout, g, wsize, psize)
    points = visualize((Circle(Point2f0(0), psize), vpos))

    const point_robj = points.children[] # temporary way of getting the render object. Shouldn't stay like this
     # best way to get the gpu object. One could also start by creating a gpu array oneself.
     # this is a bit tricky, since not there are three different types.
     # for points and lines you need a GLBuffer. e.g gpu_position = GLBuffer(rand(Point2f0, 50)*1000f0)
    const gpu_position = point_robj[:position]
    # now the lines and points share the same gpu object
    # for linesegments, you can pass indices, which needs to be of some 32bit int type
    elist = map(edgelist, g)
    lines  = visualize(gpu_position, :linesegment, indices=elist)

    # current tuple of renderobject id and index into the gpu array
    const m2id = GLWindow.mouse2id(window)
    isoverpoint = const_lift(is_same_id, m2id, point_robj)

    # inputs are a dict, materialize gets the keys out of it (equivalent to mouseposition = window.inputs[:mouseposition])
    @materialize mouse_buttons_pressed, mouseposition = window.inputs

    # single left mousekey pressed (while no other mouse key is pressed)
    key_pressed = const_lift(GLAbstraction.singlepressed, mouse_buttons_pressed, GLFW.MOUSE_BUTTON_LEFT)
    # dragg while key_pressed. Drag only starts if isoverpoint is true
    mousedragg  = GLAbstraction.dragged(mouseposition, key_pressed, isoverpoint)

    # use mousedrag and mouseid + index to actually change the gpu array with the positions
    preserve(foldp((value(m2id)..., Point2f0(0)), mousedragg) do v0, dragg
        if dragg == Vec2f0(0) # if drag just started. Not the best way, maybe dragged should return a tuple of (draggvalue, started)
            id, index = value(m2id)
            if id==point_robj.id && length(gpu_position) >= index
                p0 = gpu_position[index]
            else
                p0 = v0[3]
            end
        else
            id, index, p0 = v0
            if id==point_robj.id && length(gpu_position) >= index
                gpu_position[index] = Point2f0(p0) + Point2f0(dragg)
            end

        end
        return id, index, p0
    end)

    view(lines, window, camera=:fixed_pixel)
    view(points, window, camera=:fixed_pixel)
    @spawn renderloop(window)
end

end # module
