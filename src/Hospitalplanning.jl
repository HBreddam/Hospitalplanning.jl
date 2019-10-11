module Hospitalplanning
using JuMP
using Gurobi
using MathOptInterface
using Random
using Dates


include("Misc.jl")

include("Patient.jl")
include("Resource.jl")
include("Visit.jl")
include("GenerateSampleData.jl")

greet() = print("Hello World!")


end # module
