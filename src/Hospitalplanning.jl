module Hospitalplanning
include("Misc.jl")

include("Patient.jl")
include("Visit.jl")
include("Resource.jl")
include("GenerateSampleData.jl")

greet() = print("Hello World!")


end # module
