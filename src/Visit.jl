abstract type AbstractVisit end

mutable struct UnplannedVisit <: AbstractVisit
    id::String
    bestord::Date
    requiredresources::String
    patient::String

    UnplannedVisit(id::String,bestord::Date,requiredresources::String) = new(id,bestord,requiredresources)
end
