"""
MasterCalendar(startdate::Date,enddate::Date)

Produces a mastercalendar (Dict{Int64,Date}) of weekdays where clinic is open between the start and enddate
# Examples
```julia-repl
julia> MasterCalendar(Date("2019-01-01"),Date("2019-02-01"))
Dict{Int64,Date} with 24 entries:
  18 => 2019-01-18
  24 => 2019-01-24
  ⋮  => ⋮
```
"""
function MasterCalendar(startdate::Date,enddate::Date)
    Dict((date-startdate).value+1 => date for date = filter(td -> dayofweek(td) <= 5, startdate:Day(1):enddate))
end
"""
MasterCalendar(mastercalendar::Dict{Int64,Date},startdate,enddate)

Produces a mastercalendar (Dict{Int64,Date}) of weekdays where clinic is open.

# Examples
```julia-repl
julia> mc = MasterCalendar(Date("2019-01-01"),Date("2019-02-01"))
Dict{Int64,Date} with 24 entries:
  18 => 2019-01-18
  24 => 2019-01-24
  ⋮  => ⋮
  julia> MasterCalendar(mc,Date("2019-01-01"),Date("2019-01-10"))
  Dict{Int64,Date} with 6 entries:
    7 => 2019-01-07
    9 => 2019-01-09
    4 => 2019-01-04
    2 => 2019-01-02
    3 => 2019-01-03
    8 => 2019-01-08
```
"""
function MasterCalendar(mastercalendar::Dict{Int64,Date},startdate::Date,enddate::Date)
    filter(date -> startdate <date[2] < enddate,mastercalendar)
 end

@enum STATUS free = 1 booked = 2

@enum WEEK Odd = 1 Even = 2
