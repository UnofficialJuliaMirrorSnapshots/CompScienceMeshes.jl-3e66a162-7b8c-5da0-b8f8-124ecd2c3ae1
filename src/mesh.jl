export Mesh

using Combinatorics
using Compat.Iterators

export vertexarray, cellarray

"""
    `U::Int`: indicating dimension of the embedding space
    `D1::Int`: one plus the manifold dimension
    `T<:AbstractFloat`: the type of a vertex coordinate
"""
abstract type AbstractMesh{U,D1,T} end

mutable struct Mesh{U,D1,T} <: AbstractMesh{U,D1,T}
    vertices::Vector{SVector{U,T}}
    faces::Vector{SVector{D1,Int}}
    """
    maps a face on its index in enumeration
    """
    dict::Dict{SVector{D1,Int},Int}
end

function Mesh(vertices, faces)
    dict = Dict((f,i) for (i,f) in enumerate(faces))
    T = eltype(eltype(vertices))
    U = length(eltype(vertices))
    D1 = length(eltype(faces))
    Mesh{U,D1,T}(vertices, faces, dict)
end

vertexarray(m::Mesh) = [ v[i] for v in m.vertices, i in 1:universedimension(m) ]
cellarray(m::Mesh) = [ k[i] for k in m.faces, i in 1:dimension(m)+1 ]


"""
    mesh(type, mdim, udim=mdim+1)

Returns an empty mesh with `coordtype` equal to `type`, of dimension `mdim`
and embedded in a universe of dimension `udim`
"""
mesh(T, mdim, udim=mdim+1) = Mesh(Pt{udim,T}[], SVector{mdim+1,Int}[])



"""
    vt = vertextype(mesh)

Returns type of the vertices used to define the cells of the mesh.
"""
vertextype(m::Mesh) = eltype(m.vertices)



"""
    celltype(mesh)

Returns the type of the index tuples stored in the mesh.
"""
celltype(m::Mesh) = eltype(m.faces)



"""
    coordtype(mesh)

Returns `eltype(vertextype(mesh))`
"""
coordtype(m::AbstractMesh{U,D1,T}) where {U,D1,T} = T
# coordtype(m::Mesh) = eltype(vertextype(m))



"""
    dim = dimension(mesh)

Returns the dimension of the mesh. Note that this is
the dimension of the cells, not of the surrounding space.
"""
dimension(m::AbstractMesh{U,D1}) where {U,D1} = D1-1
# dimension(m::Mesh) = length(celltype(m)) - 1



"""
    universedimension(mesh)

Returns the dimension of the surrounding space. Equals
the number of coordinates required to describe a vertex.
"""
universedimension(m::Mesh) = length(vertextype(m))



"""
    vertices(mesh)

Returns an indexable iterable to the vertices of the mesh
"""
vertices(m::Mesh) = m.vertices



#     vertices(mesh, i)
#     vertices(mesh, I)
#
# Select one or multiple vertices from the mesh. In the second
# form, only statically sized arrays are allowed to discourage
# memory allocation. The returned vector in that case will also
# be statically typed and of the same size as `I`.
vertices(m::Mesh, i::Number) = m.vertices[i]
@generated function vertices(m::Mesh, I::SVector)
    N = length(I)
    xp = :(())
    for i in 1:N
        push!(xp.args, :(m.vertices[I[$i]]))
    end
    :(SVector($xp))
end



"""
    numvertices(mesh)

Returns the number of vertices in the mesh.

*Note*: this is the number of vertices in the vertex buffer and might include floatin vertices
or vertices not appearing in any cell. In other words the following is not necessarily true:

```julia
    numvertices(mesh) == numcells(skeleton(mesh,0))
```
"""
numvertices(m::Mesh) = length(m.vertices)



"""
    numcells(mesh)

Returns the number of cells in the mesh.
"""
numcells(m::Mesh) = length(m.faces)



"""
    cells(mesh)

Return an iterable collection containing the cells making up the mesh.
"""
cells(mesh) = mesh.faces


# """
#     cellvertices(mesh, i)
#
# Return an indexable collection containing the vertices of cell `i`.
# Shorthand for `vertices(mesh, cells(mesh, i))`.
# """
# cellvertices(mesh,i) = vertices(mesh, cells(mesh, i))



"""
    translate(mesh, v)

Creates a new mesh by translating `mesh` over vector `v`
"""
translate(Γ::Mesh, v) = Mesh([w + v for w in Γ.vertices], deepcopy(Γ.faces))



"""
    translate!(mesh, v)

Translates `mesh` over vector `v` inplace.
"""
function translate!(Γ::Mesh, v)
    for i in 1:length(Γ.vertices)
        Γ.vertices[i] += v
    end
    Γ
end


"""
    flip(cell)

Change the orientation of a cell by interchanging the first to indices.
"""
@generated function flip(cell)
    # generate `T(cell[2],cell[1],cell[3],...)`, with `T = typeof(cell)`
    N = length(cell)
    xp = :($cell(cell[2], cell[1]))
    for i in 3:N
        push!(xp.args, :(cell[$i]))
    end
    xp
end

"""
    flipmesh!(mesh)

Change the orientation of a mesh
"""
function flipmesh!(mesh)
    mesh.faces .= flip.(mesh.faces)
    mesh
end


flipmesh(mesh) = flipmesh!(deepcopy(mesh))


export mirrormesh, mirrormesh!

"""
    mirror(vertex, normal, anchor)

Mirror vertex across a plane defined by its normal and a containing point.
"""
function mirror(vertex, normal, anchor)
    h = dot(vertex - anchor, normal)
    vertex - 2*h * normal
end

function mirrormesh!(mesh, normal, anchor)
    #mesh.vertices .= mirror.(mesh.vertices, normal, anchor)
    for i in eachindex(mesh.vertices)
        mesh.vertices[i] = mirror(mesh.vertices[i], normal, anchor)
    end
    mesh
end

mirrormesh(mesh, args...) = mirrormesh!(deepcopy(mesh), args...)

function rotate!(Γ::Mesh{3}, v)
    α = norm(v)
    u = v/α

    cα = cos(α/2)
    sα = sin(α/2)

    p = point(cα, sα*u[1], sα*u[2], sα*u[3])
    q = point(cα, -sα*u[1], -sα*u[2], -sα*u[3])

    P = @SMatrix [
        +p[1] -p[2] -p[3] -p[4];
        +p[2] +p[1] -p[4] +p[3];
        +p[3] +p[4] +p[1] -p[2];
        +p[4] -p[3] +p[2] +p[1]]

    Q = @SMatrix [
        +q[1] -q[2] -q[3] -q[4];
        +q[2] +q[1] +q[4] -q[3];
        +q[3] -q[4] +q[1] +q[2];
        +q[4] +q[3] -q[2] +q[1]]

    for i in 1:numvertices(Γ)
        r = vertices(Γ,i)
        t = point(0, r[1], r[2], r[3])
        s = P * Q * t
        Γ.vertices[i] = point(s[2], s[3], s[4])
    end
    Γ
end

function rotate(Γ::Mesh{3}, v)
    R = deepcopy(Γ)
    rotate!(R,v)
    R
end


"""
    fliporientation(mesh)

Changes the mesh orientation inplace. If non-orientatble, undefined.
"""
function fliporientation!(m::Mesh)
    for i in 1:numcells(m)
        m.faces[i] = fliporientation(m.faces[i])
    end
    return m
end


"""
    fliporientation(mesh)

Returns a mesh of opposite orientation.
"""
function fliporientation(m::Mesh)
    n = deepcopy(m)
    fliporientation!(n)
end

@generated function fliporientation(I::SVector{N,T}) where {N,T}
    @assert N >= 2
    xp = :(SVector{N,T}(I[2],I[1]))
    for i in 3:N
        push!(xp.args, :(I[$i]))
    end
    return xp
end

"""
    -mesh -> flipped_mesh

Create a mesh with opposite orientation.
"""
Base.:-(m::Mesh) = fliporientation(m)





"""
    boundary(mesh)

Returns the boundary of `mesh` as a mesh of lower dimension.
"""
function boundary(mesh)

    D = dimension(mesh)

    # vertices have no boundary
    @assert 0 < D

    # build a list of D-1 cells
    edges = skeleton(mesh, D-1)
    faces = skeleton(mesh, D)

    # get the edge-face connection matrix
    conn = connectivity(edges, faces)

    # find the edges that only have one adjacent face
    #i = find(x -> x < 2, sum(abs.(conn), dims=1))
    sums = sum(abs.(conn), dims=1)
    i = (LinearIndices(sums))[findall(x->x<2, sums)]

    # create a mesh out of these
    bnd = Mesh(mesh.vertices, edges.faces[i])
end


"""
Complement to boundary. This function selects those edges that have at
least two faces adjacent. The case with more than two neighboring faces
occurs on non-manifold structures (e.g. containing junctions)
"""
function interior(mesh::Mesh, edges=skeleton(mesh,1))
    @assert dimension(mesh) == 2
    @assert vertices(mesh) === vertices(edges)

    C = connectivity(edges, mesh)
    @assert size(C) == (numcells(mesh), numcells(edges))

    nn = vec(sum(abs.(C), dims=1))
    T = CompScienceMeshes.celltype(edges)
    interior_edges = Vector{T}()
    for (i,edge) in pairs(cells(edges))
        nn[i] > 1 && push!(interior_edges, edge)
    end
    Mesh(vertices(mesh), interior_edges)
end



"""
    vertextocellmap(mesh) -> vertextocells, numneighbors

Computed an V×M array `vertextocells` where V is the number of vertices
and M is the maximum number of cells adjacent to any given vertex such
that `vertextocells[v,i]` is the index in the cells of `mesh` of the `i`th
cell adjacent to teh `v`-th vertex. `numneighbors[v]` contains the number
of cells adjacent to the `v`-th vertex.

This method allows e.g. for the efficient computation of the connectivity
matrix of the mesh.
"""
function vertextocellmap(mesh)

    # cells = mesh.faces
    C = cells(mesh)

    numverts = length(vertices(mesh)) #numvertices(mesh)
    numcells = length(C)
    numneighbors = zeros(Int, numverts)
    for i = 1 : numcells
        for m in C[i]
            numneighbors[m] += 1
        end
        #numneighbors[ cells[i] ] += 1
    end

    npos = -1
    vertstocells = fill(npos, numverts, maximum(numneighbors))
    numneighbors = zeros(Int, numverts)
    for i = 1 : numcells
        cell = C[i]
        for j = 1 : length(cell)
            v = cell[j]
            k = (numneighbors[v] += 1)
            vertstocells[v,k] = i
        end
    end

    vertstocells, numneighbors
end



"""
    skeleton(mesh, dim)

Returns a mesh comprising the `dim`-dimensional sub cells of `mesh`. For example to retrieve
the edges of a given surface `mesh`,

```julia
edges = skelton(mesh, 1)
```
"""
function skeleton(mesh, dim::Int)

    meshdim = dimension(mesh)
    @assert 0 <= dim <= meshdim

    if dim == meshdim
        return mesh
    end

    nc = numcells(mesh)
    C = SVector{dim+1,Int}
    simplices = zeros(C, nc*binomial(meshdim+1,dim+1))

    n = 1
    for c = 1 : nc

        cell = mesh.faces[c]
        for simplex in combinations(cell,dim+1)
            simplices[n] = sort(simplex)
            n += 1
        end
    end

    simplices = unique(simplices)
    Mesh(mesh.vertices, simplices)
end



"""
    skeleton(pred, mesh, dim)

Like `skeleton(mesh, dim)`, but only cells for which `pred(cell)`
returns true are withheld.
"""
function skeleton(pred, mesh, dim)

    meshdim = dimension(mesh)
    @assert 0 <= dim <= meshdim

    nc = numcells(mesh)
    C = SVector{dim+1,Int}
    simplices = zeros(C, nc*binomial(meshdim+1,dim+1))

    n = 1
    for c = 1 : nc

        cell = mesh.faces[c]
        for simplex in combinations(cell,dim+1)
            if pred(SVector{dim+1,Int}(simplex))
                simplices[n] = sort(simplex)
                n += 1
            end
        end
    end

    simplices = simplices[1:n-1]
    simplices = unique(simplices)

    Mesh(mesh.vertices, simplices)
end







"""
    connectivity(faces, cells, op=sign)

Create a sparse matrix `D` of size `numcells(cells)` by `numcells(faces)` that
contiains the connectivity info of the mesh. In particular `D[m,k]` is `op(r)`
where `r` is the local index of face `k` in cell `m`. The sign of `r` is
positive or negative depending on the relative orientation of face `k` in cell
`m`.

For `op=sign`, the matrix returned is the classic connectivity matrix, i.e.
the graph version of the exterior derivative.
"""
function connectivity(kcells::AbstractMesh, mcells::AbstractMesh, op = sign)

    vtok, _ = vertextocellmap(kcells)
    vtom, _ = vertextocellmap(mcells)

    npos = -1

    dimk = numcells(kcells)
    dimm = numcells(mcells)

    D = spzeros(Int, dimm, dimk)

    for v in 1:numvertices(kcells)
        for i in vtok[v,:]
            i == npos && break
            #kcell = cells(kcells, i)
            kcell = kcells.faces[i]
            for j in vtom[v,:]
                j == npos && break
                #mcell = cells(mcells, j)
                mcell = cells(mcells)[j]
                D[j,i] = op(relorientation(kcell, mcell))
            end
        end
    end

    return D
end



"""
    pairs = cellpairs(mesh, edges, dropjunctionpair=false)

Given a mesh and set of oriented edges from that mesh (as generated by `skeleton`),
    `cellpairs` will generate a 2 x K matrix, where K is the number of pairs
    and each column contains a pair of indices in the cell array of `mesh` that have
    one of the supplied edges in common.

Returns an array of pairs of indices, each pair corresponding to a pair of adjacent faces.

(If the mesh is oriented, the first row of `facepairs` will contain indices to the cell
    for which the corresponding edge has a positive relative orientation.

If a edge lies on the boundary of the mesh, and only has one neighboring cell, the
    second row of `facepairs` will contain `-k` with `k` the local index of the corresponding
    edge in its neighboring triangle.

If an edge has more than two neighboring cells (i.e. the edge is on a junction),
    all possible pairs of cells that have the junction edge in common are supplied. if
    `dropjunctionpair == false` then one of the possible pairs of cells is not recorded.
    This is done to avoid the creation of linearly dependent basis functions in the
    construction of boundary element methods for Maxwell's equations.)
"""
function cellpairs(mesh, edges; dropjunctionpair=false)

    ndrops = dropjunctionpair ? 1 : 0
    @assert dimension(edges)+1 == dimension(mesh)

    numedges = numcells(edges)

    # perform a dry run to determine the number of cellpairs
    v2e, nn = vertextocellmap(mesh)
    k = 0
    for edge = edges.faces

        v = edge[1]; n = nn[v]; nbd1 = v2e[v,1:n]
        v = edge[2]; n = nn[v]; nbd2 = v2e[v,1:n]

        nbd = intersect(nbd1, nbd2)
        n = length(nbd)
        if n < 3
            k += 1
        else
            k += (n-ndrops)
        end

    end
    facepairs = zeros(Int, 2, k)

    k = 1
    for edge in edges.faces

        # neighborhood of startvertex
        v = edge[1]
        n = nn[v]
        nbd1 = v2e[v,1:n]

        # neighborhood of endvertex
        v = edge[2]
        n = nn[v]
        nbd2 = v2e[v,1:n]

        # get the intersection
        nbd = intersect(nbd1, nbd2)
        n = length(nbd)
        @assert 0 < n

        if n == 1 # boundary edge

            c = nbd[1]
            cell = mesh.faces[c]
            s = relorientation(edge, cell)
            facepairs[1,k] = c
            facepairs[2,k] = -abs(s)

            k += 1
        elseif n == 2

            c = nbd

            cell1 = mesh.faces[c[1]]
            cell2 = mesh.faces[c[2]]

            r1 = relorientation(edge, cell1)
            r2 = relorientation(edge, cell2)

            if r1 > 0 && r2 < 0
                c1 = c[2]
                c2 = c[1]
            else
                c1 = c[1]
                c2 = c[2]
            end

            facepairs[1,k] = c1
            facepairs[2,k] = c2

            k += 1
        else

            for c in drop(combinations(nbd,2), ndrops)

                cell1 = mesh.faces[c[1]]
                cell2 = mesh.faces[c[2]]

                r1 = relorientation(edge, cell1)
                r2 = relorientation(edge, cell2)

                if r1 > 0 && r2 < 0
                    c1 = c[2]
                    c2 = c[1]
                else
                    c1 = c[1]
                    c2 = c[2]
                end

                facepairs[1,k] = c1
                facepairs[2,k] = c2

                k += 1
            end
        end
    end

    facepairs
end


"""
    chart(mesh, cell) -> cell_chart

Return a chart describing the supplied cell of `mesh`.
"""
chart(mesh::Mesh, cell) = simplex(vertices(mesh,cell))

parent(mesh::Mesh) = nothing

"""
    isoriented(mesh) -> Bool

Returns true is all cells are consistently oriented, false otherwise.
"""
function isoriented(m::AbstractMesh)

    @assert dimension(m) >= 0
    edges = skeleton(m, dimension(m)-1)

    D = connectivity(edges, m)
    S = (abs.(sum(D,dims=1)) .<= 1)
    return all(S)
end

"""
True if m1 is a direct refinement of m2.
"""
function refines(m1::AbstractMesh, m2::AbstractMesh)
    parent(m1) == nothing && return false
    return parent(m1) == m2
end
