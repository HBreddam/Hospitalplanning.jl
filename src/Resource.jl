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
