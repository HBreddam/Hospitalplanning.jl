abstract type AbstractVisit end

mutable struct UnplannedVisit <: AbstractVisit
    intID::Int64
    id::String
    bestord::Pair{Int64,Date}
    required_qualifications::Dict{String,String}
    patient::String

    UnplannedVisit(intID::Int64,id::String,bestord::Pair{Int64,Date},requiredresources::String) = new(intID,id,bestord,Dict("type" => requiredresources))
end
function resourceVisitMatch(resource::Resource,visit::UnplannedVisit)
    return !any(req -> !any(qual-> qual == req ,resource.qualifications),visit.required_qualifications)
end

function resourceVisitMatch(resource::Resource,visits::Array{UnplannedVisit})
    return any(visit -> resourceVisitMatch(resource,visit),visits)
end

function findqualifiedResources(resources::Array{Resource},visit::AbstractVisit)
    res = filter(res -> resourceVisitMatch(res,visit),resources)
    if length(res) == 0
        @warn "No qualified resources found for resource with qualifications $(visit.required_qualifications) subproblem will be infeasible"
    end
    return res
end

function findqualifiedResources(resources::Array{Resource},visits::Array{UnplannedVisit})
    return filter(res -> resourceVisitMatch(res,visits),resources)
end


function findqualifiedResourceIDs(resources::Array{Resource},visits::Array{UnplannedVisit})
        dict = Dict(v.intID => (x->x.intID).(findqualifiedResources(resources,v)) for v in visits)#TODO id not unique
        output = (x->x.intID).(findqualifiedResources(resources,visits))
    return output, dict
end
