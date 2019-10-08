using Dates

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

struct Offperiod
    id::String
    starttime::DateTime
    endtime::DateTime

    Offperiod(id,starttime,endtime) = new(id,starttime,endtime)
end

mutable struct Resource <: AbstractResource
    id::String
    type::String
    name::String

    workpattern::Calendar

    calendar::Calendar
    offperiods::Array{Offperiod}

    Resource(type::String,name::String) = new(string(type, "_" , name),type,name)
end

function addWorkPattern(resource::Resource,oddcalendar::Calendar,evencalendar::Calendar)
    resource.workpattern = WorkPattern(oddcalendar,evencalendar)

end