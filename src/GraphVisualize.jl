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

type GraphPlot
    glast::Graph
    g::Graph
    resolution::Tuple{Int,Int}
    point_size::Float32

    #SIGNALS
    s_g::Signal{Graph}
    s_vertex_pos::Signal
end

function GraphPlot(g::Graph; resolution = (900, 900), point_size = 15f0)
    s_g = Signal(g)
    s_vertex_pos = Signal(layout(g, resolution, point_size))
    plt = GraphPlot(Graph(), g, resolution, point_size, s_g, s_vertex_pos)
    return plt
end

function set_observation_fps!(plt::GraphPlot, f)
    preserve(map(delta -> begin
            if has_changed(plt.g, plt.glast)
                update!(plt)
            end
        end, f))
end

function update!(plt)
    g = plt.g; glast = plt.glast
    res = plt.resolution; psize = plt.point_size

    @assert has_changed(g, glast)
    push!(plt.s_g, g)

    if vertex_added(g, glast)
        push!(plt.s_vertex_pos, push!(value(plt.s_vertex_pos), new_pos(res, psize)))
    elseif vertex_removed(g, glast)
        # Assume that the removed vertex was exchanged with last vertex
        # This is an hack, and it is slow and buggy.
        # In order to have a graphically consistent vertex removal,
        # we need either unique vertex identifiers or some external signaling.

        lastneigs = neighbors(glast, nv(glast))
        ilast = 0
        i = 1
        for neigs in fadj(g)
            if neigs == filter(x->x!=i,lastneigs)
                neigs != neighbors(glast,i) && break
                ilast = i
            end
            i += 1
        end
        i > nv(g) && (i = ilast)
        pos = value(plt.s_vertex_pos)
        pos[i] = pos[end]
        resize!(pos, length(pos)-1)
        push!(plt.s_vertex_pos, pos)
    elseif nv(g) == nv(glast)
        # nothing
    else #nv(g) != nv(glast)
        push!(plt.s_vertex_pos, layout(g, res, psize))
    end

    plt.glast = deepcopy(g)
    sleep(1e-3) # BUG: removing this results in error messages
end

push!(plt::GraphPlot, g::Graph) = push!(plt.s_g, g)

edge_removed(g::Graph, glast::Graph) = ne(glast) == ne(g) + 1
edge_added(g::Graph, glast::Graph) = ne(glast) == ne(g) - 1
vertex_removed(g::Graph, glast::Graph) = nv(glast) == nv(g) + 1
vertex_added(g::Graph, glast::Graph) = nv(glast) == nv(g) - 1

has_changed(g::Graph, glast::Graph) = !(nv(glast) == nv(g) &&  ne(glast) == ne(g))
has_really_changed(g::Graph, glast::Graph) = !(glast == g)

function edgelist(g::Graph)
    indices = Vector{Int32}(2ne(g))
    i = 0
    for (u,v) in edges(g)
        indices[i+=1] = u
        indices[i+=1] = v
    end
    indices
end

function new_pos(resolution, psize)
    wsize = minimum(resolution)
    x, y = (2rand()-1, 2rand()-1)
    return Point2f0(2psize,2psize) + (Point2f0(x, y) + Point2f0(1.,1.))* (wsize-4psize)/2
end


function layout(g::Graph, resolution, psize)
    wsize = minimum(resolution)
    x, y = layout_spring_adj(full(adjacency_matrix(g)))
    return [Point2f0(2psize,2psize) + (Point2f0(x[i], y[i]) + Point2f0(1.,1.))* (wsize-4psize)/2 for i=1:nv(g)]
end

"""
    plot(g::Graph; observe=true, resolution = (900, 900), point_size = 15f0)

Creates an OpenGL window and draws `g` in it. If `observe==true` future modifications of
`g` will be reflected in the plot. Returns a `GraphPlot` object.
"""
function plot(g::Graph; observe= true, kw...)
    plt = GraphPlot(g, kw...)
    observe && set_observation_fps!(plt, fps(10.))  # WEIRDNESS: if I inserte this line in the GraphPlot constructor
                                                    #           it doesn't update
    plot(plt)
    return plt
end

function plot(plt::GraphPlot)

    window = glscreen(resolution=plt.resolution)

    const record_interactive = true
    points = visualize((Circle(Point2f0(0), plt.point_size), plt.s_vertex_pos))

    const point_robj = points.children[]
    const gpu_position = point_robj[:position]
    elist = map(edgelist, plt.s_g)
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
