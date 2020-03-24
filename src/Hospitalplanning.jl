__precompile__()

module Hospitalplanning
using JuMP
using Gurobi
using MathOptInterface
using Random
using Dates
using Query
using XLSX
using Random
using JuliaDB
using CSV
using DataFrames
using CSVFiles



include("Misc.jl")

include("GenerateSampleData.jl")
include("readwritedata.jl")
include("MIP/datastructures.jl")
include("MIP/SupportFunctions.jl")
include("MIP/masterproblem.jl")
include("MIP/subproblem.jl")
include("MIP/model_column.jl")



end # module
