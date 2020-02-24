abstract type AbstractResource end


function Base.:(==)(r1::AbstractResource, r2::AbstractResource)
    return  r1.id == r2.id
end

function Base.:(==)(r1::AbstractResource, r2::String)
    return  r1.id == r2
end

function Base.:(==)(r1::String, r2::AbstractResource)
    return  r1 == r2.id
end

# struct Offperiod DELETE ME
#     id::String
#     starttime::DateTime
#     endtime::DateTime
#
#     Offperiod(id,starttime,endtime) = new(id,starttime,endtime)
# end

mutable struct Resource <: AbstractResource
    intID::Int
    id::String
    type::String
    name::String
    qualifications::Dict{String,String}
    workpattern::Calendar

    calendar::Calendar
    #offperiods::Array{Offperiod} DELETE ME

    Resource(intID::Int,type::String,name::String) = new(intID,string(type, "_" , name),type,name,Dict("name" => name,"type"=>type),Calendar(),Calendar(),Offperiod[])
    Resource(type::String,name::String) = new(0,string(type, "_" , name),type,name,Dict("name" => name,"type"=>type)Calendar(),Calendar(),Offperiod[])
end

function addNewResource!(resources::Array{Resource},type::String,name::String)
    any(r-> r.id == string(type, "_" , name),resources) ? error("Not Unique resource id") : push!(resources,Resource(length(resources)+1,type,name))
end

function addWorkPattern(resource::Resource,oddcalendar::Calendar,evencalendar::Calendar)
    resource.workpattern = oddcalendar + evencalendar
end
