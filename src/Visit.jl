abstract type AbstractVisit end

mutable struct UnplannedVisit <: AbstractVisit
    id::String
    bestord::Pair{Int64,Date}
    required_qualifications::Dict{String,String}
    patient::String

    UnplannedVisit(id::String,bestord::Pair{Int64,Date},requiredresources::String) = new(id,bestord,Dict("Type" => requiredresources))
end
function resourceVisitMatch(resource::Resource,visit::AbstractVisit)
    return !any(req -> !any(qual-> qual == req ,resource.qualifications),visit.required_qualifications)
end

function resourceVisitMatch(resource::Resource,visits::Array{AbstractVisit})
    return any(visit -> resourceVisitMatch(resource,visit),visits)
end

function findqualifiedResources(resources::Array{Resource},visit::AbstractVisit)
    return filter(res = resourceVisitMatch(res,visit),res)
end

function findqualifiedResources(resources::Array{Resource},visits::Array{AbstractVisit})
    return filter(res = resourceVisitMatch(res,visits),res)
end


function findqualifiedResourceIDs(resources::Array{Resource},visits::AbstractVisit)
    return (res -> res.intID).(findqualifiedResource(resources,visits))
end
