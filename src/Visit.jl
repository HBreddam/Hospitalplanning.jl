abstract type AbstractVisit end

mutable struct UnplannedVisit <: AbstractVisit
    id::String
    bestord::Pair{Int64,Date}
    requiredresources::String
    patient::String

    UnplannedVisit(id::String,bestord::Pair{Int64,Date},requiredresources::String) = new(id,bestord,requiredresources)
end
