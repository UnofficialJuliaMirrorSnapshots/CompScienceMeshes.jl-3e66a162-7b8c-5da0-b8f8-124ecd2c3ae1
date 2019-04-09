"""
    read_gmsh_mesh(filename) -> mesh::Mesh
"""
function read_gmsh_mesh(fn::AbstractString; kwargs...)
    open(fn, "r") do io
        read_gmsh_mesh(io; kwargs...)
    end
end

"""
    read_gmsh_mesh(iostream) -> mesh::Mesh

Reads the mesh nodes and elements stored in the input .msh file (`io`, output by GMSH)
    into arrays of node vectors and vertex vectors respectively.

Returns an object `mesh` of type `Mesh`, comprising both vector arrays.
"""
function read_gmsh_mesh(io; physical=nothing)

    entity_tag = 0
    if physical != nothing
        @assert physical isa String
        while true
            thisLine = io |> readline |> strip
            thisLine == "\$PhysicalNames" && break
            thisLine == "\$Nodes" && error("Mesh file does not define physical entities")
        end
        thisLine = io |> readline |> strip
        s = split(thisLine)
        NP = parse(Int,s[1])
        println("Mesh file defined $(NP) physical entities:")
        for i in 1:NP
            thisLine = io |> readline |> strip
            s = split(thisLine)
            entity_name = s[3]
            @show entity_name
            if entity_name == "\"$(physical)\""
                entity_tag = parse(Int, s[2])
                println("Target entity \"$(physical)\" is $i out of $(NP).")
                break
            end
        end
        entity_tag == 0 && error("Specified physical entitiy not found")
    end

    thisLine = io |> readline |> strip
    while thisLine != "\$Nodes"
        thisLine = io |> readline |> strip
    end

    thisLine = io |> readline |> strip
    s = split(thisLine)
    NV = parse(Int, s[1])

    P = SVector{3,Float64}
    v = Vector{P}(undef,NV)
    for i in 1:NV
        thisLine = io |> readline |>  strip
        d = readdlm(IOBuffer(thisLine), Float64)
        v[i] = P(d[2], d[3], d[4])
    end

    while thisLine != "\$Elements"
        thisLine = io |> readline |> strip
    end

    thisLine = io |> readline |> strip
    s = split(thisLine)
    NF = parse(Int, s[1])

    thisLine = io |> readline |> strip
    f = Vector{SVector{3,Int}}(undef,NF); i = 0
    while thisLine != "\$EndElements"
        d = readdlm(IOBuffer(thisLine), Int)
        thisLine = io |> readline |> strip
        d[2] == 2 || continue
        tag = d[4]
        if entity_tag == 0 || entity_tag == tag
            f[i +=1] = SVector(d[end-2], d[end-1], d[end-0])
        end
    end
    resize!(f,i)

    return Mesh(v, f)

end
