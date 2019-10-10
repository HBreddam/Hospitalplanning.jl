
function MasterCalendar(startdate::Date,enddate::Date)
    Dict((date-startdate).value+1 => date for date = filter(td -> dayofweek(td) <= 5, startdate:Day(1):enddate))
end

function MasterCalendar(mastercalendar::Dict{Int64,Date},startdate::Date,enddate::Date)
    filter(date -> startdate <date[2] < enddate,mastercalendar)
 end

@enum STATUS free = 1 booked = 2
mutable struct Timeslot
    date::Pair{Int64,Date}
    intID::Int
    startTime::Time
    endTime::Time

    status::STATUS

    Timeslot(date::Pair{Int64,Date},intID::Int,startTime::DateTime,endTime::DateTime)= new(date,intID,Time(startTime),Time(startTime),free)
    Timeslot(date::Pair{Int64,Date},intID::Int,startTime::Time,endTime::Time)= new(date,intID,startTime,endTime,free)

end

@enum WEEK Odd = 1 Even = 2
mutable struct Workday
    date::Pair{Int64,Date}
    timeslots::Array{Timeslot}

    weekday::Int
    weektype::WEEK

    Workday() = new((0 =>Date(0)),[])
    Workday(weekday::Int,weektype::WEEK) = new((0 =>Date(0)),[],weekday,weektype)
    Workday(date::Pair{Int64,Date},timeslots::Array{Timeslot},weekday::WEEK,weektype::Int) = new(date,timeslots,weekday,weektype)
end
function addTimeslot!(workday::Workday,startTime::Time,endTime::Time)
    push!(workday.timeslots,Timeslot(workday.date,length(workday.timeslots)+1,startTime,endTime))
end

function addTimeslot!(workday::Workday,startTime::String,endTime::String)
    push!(workday.timeslots,Timeslot(workday.date,length(workday.timeslots)+1,Dates.Time(startTime),Dates.Time(endTime)))
end


abstract type AbstractCalendar end


struct Calendar <: AbstractCalendar
    workdays::Array{Workday}

    Calendar() = new([])
    Calendar(workdays::Array{Workday}) = new(workdays)
end

function Base.:(+)(cal1::AbstractCalendar, cal2::AbstractCalendar)
    newcal = vcat(cal1.workdays,cal2.workdays)
    sort!(newcal, by= x ->(x.date,x.weekday) )
    return Calendar(newcal)
end


function addWorkday!(calendar::Calendar,workday::Workday)
    push!(calendar.workdays,workday)
    sort!(calendar.workdays,by = x ->(x.date,x.weekday))
end
