using Dates

struct MasterCalendar
    workdays::Array{Date}

    MasterCalendar(startDate::Date,enddate::Date) = filter(date -> dayofweek(date)<=5, startDate:Day(1):enddate)
end


struct Timeslot
    startTime::Time
    endTime::Time

    Timeslot(startTime::DateTime,endTime::DateTime)= new(Time(startTime),Time(startTime))
    Timeslot(startTime::Time,endTime::Time)= new(startTime,endTime)

end
@enum WEEK Odd = 1 Even = 2
struct Workday
    date::DateTime
    timeslots::Array{Timeslot}

    weekday::Int
    weektype::WEEK

    Workday() = new(Date(0),[])
    Workday(weekday::Int,weektype::WEEK) = new(Date(0),[],weekday,weektype)
    Workday(date::DateTime,timeslots::Array{Timeslot},weekday::WEEK,weektype::Int) = new(date,timeslots,weekday,weektype)
end
function addTimeslot(workday::Workday,startTime::Time,endTime::Time)
    push!(workday.timeslots,Timeslot(startTime,endTime))
end


function addTimeslot(workday::Workday,startTime::String,endTime::String)
    push!(workday.timeslots,Timeslot(Dates.Time(startTime),Dates.Time(endTime)))
end


abstract type AbstractCalendar end


struct Calendar <: AbstractCalendar
    workdays::Array{Workday}

    Calendar() = new([])
end
function Base.:(+)(cal1::AbstractCalendar, cal2::AbstractCalendar)
    newcal = vcat(cal1.workdays,cal2,workdays)
    sort!(newcal, by )
    return
end


function addWorkday(calendar::Calendar,workday::Workday)
    push!(calendar.workdays,workday)
    sort!(calendar.workdays,by = x ->(x.date,x.weekday))
end

struct WorkPattern
    oddcalendar::Calendar
    evencalendar::Calendar

    WorkPattern() = new([],[])
    WorkPattern(oddcalendar::Calendar,evencalendar::Calendar) = new(oddcalendar,evencalendar)
end
