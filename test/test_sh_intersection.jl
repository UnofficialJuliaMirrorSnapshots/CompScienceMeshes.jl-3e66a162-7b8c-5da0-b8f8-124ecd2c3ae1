#using FixedSizeArrays
using CompScienceMeshes
using Test

p = point(0.0, 1.0)
q = point(2.0, 1.0)
r = point(2.0, 2.0)
a = point(1.0, 0.0)
b = point(2.0, 0.0)
c = point(1.0, 2.0)

@test CompScienceMeshes.leftof(p, a,b) == true
@test CompScienceMeshes.intersectlines(p,r, a,c) == [1.0, 1.5]

α = CompScienceMeshes.sutherlandhodgman2d([p,q,r], [a,b,c])
@test length(α) == 4
@test α[1] == [1.2, 1.6]
@test α[2] == [1.0, 1.5]
@test α[3] == [1.0, 1.0]
@test α[4] == [1.5, 1.0]

β = CompScienceMeshes.sutherlandhodgman([p,q,r], [a,b,c])
@test length(β) == length(α)
for i in eachindex(β) @test β[i] == α[i] end

P = simplex(p, q, r)
Q = simplex(a, b, c)
R = intersection(P,Q)

@test length(R) == 2
@test R[1].vertices == [α[1], α[2], α[3]]
@test R[2].vertices == [α[1], α[3], α[4]]

t = point(1.0, 2.0, 3.0)
p = point(0.0, 1.0, 0.0) + t
q = point(2.0, 1.0, 0.0) + t
r = point(2.0, 2.0, 0.0) + t
a = point(1.0, 0.0, 0.0) + t
b = point(2.0, 0.0, 0.0) + t
c = point(1.0, 2.0, 0.0) + t

P = simplex(p,q,r)
Q = simplex(a,b,c)
S = intersection(P,Q)

# Test whether translation and intersection commute
@test length(S) == 2
for i in 1:2
    for j in 1:3
        for k in 1:2
            @test S[i].vertices[j][k] ≈ R[i].vertices[j][k]+t[k]
        end
        @test S[i].vertices[j][3] ≈ t[3]
    end
end
