module Hospitalplanning
using JuMP
using Gurobi
using MathOptInterface
using Random
using Dates


include("Misc.jl")

include("Resource.jl")
include("Visit.jl")
include("Patient.jl")
include("GenerateSampleData.jl")

include("MIP/datastructures.jl")
include("MIP/SupportFunctions.jl")
include("MIP/masterproblem.jl")
include("MIP/subproblem.jl")



end # module
