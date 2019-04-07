"""
    load_gid_mesh(filename) -> mesh
"""
function load_gid_mesh(fn::AbstractString)
    open(fn, "r") do io
        load_gid_mesh(io)
    end
end

"""
    load_gid_mesh(stream) ->mesh
"""
function load_gid_mesh(file)

    lineCount = countlines(file);
    seekstart(file);
    readline(file); # MESH dimension 3 ElemType Triangle Nnode 3
    readline(file); # Coordinates

    # Read the vertices
    vertices = Vector{Pt{3,Float64}}(undef,lineCount)
    vertexCount = 0;
    while !eof(file)
            line = split(readline(file));
            size(line, 1) == 4 || break; # End Coordinates
            vertexCount += 1;
            #vertices[vertexCount] = Pt{3,Float64}(map(Meta.parse, line[2:4]));
            vertices[vertexCount] = Pt{3,Float64}(parse.(Float64,line[2:4]))
    end

    readline(file); # "\n"
    readline(file); # Elements

    # Read the triangles
    triangles = Vector{Pt{3,Int}}(undef,lineCount-vertexCount);
    triangleCount = 0;
    while !eof(file)
            line = split(readline(file));
            size(line, 1) == 4 || break; # End Elements
            triangleCount += 1;
            triangles[triangleCount] = Pt{3,Int}(map(Meta.parse, line[2:4]));
    end

    Mesh(vertices[1:vertexCount], triangles[1:triangleCount])
end
