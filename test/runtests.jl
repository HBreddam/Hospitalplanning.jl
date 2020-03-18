using Hospitalplanning
using Test
using BenchmarkTools
HP = Hospitalplanning

@testset "Hospitalplanning.jl" begin
    include("readwritedata_tests.jl")
    include("solution_tests.jl")
end
