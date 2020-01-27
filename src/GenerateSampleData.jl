using XLSX
using DataFrames
using Random
using UUIDs
using JuliaDB
using Lazy

#TODO sort treatmentplan by default
function generateTreatmentplan(row::DataFrameRow,bestord::Pair{Int64,Date},columns::Dict{Symbol,String},visits::IndexedTable,patientID)
    treatmentplan = []
        for col in columns
            if !ismissing(row[col[1]])
                if row[col[1]] == 1 || rand() < row[col[1]]
                    push!(rows(visits),(intID=length(visits)+1,patientID=patientID,bestord=bestord,req_type=col[2]))
                end
            end
        end
    treatmentplan
end

function readPatientTable(path,sheet,columns,mastercalendar)
    patientOverview = DataFrame(XLSX.readtable(path,sheet)...)
    patients = JuliaDB.table((intID=Int64[],diagnosis=String[],bestord=Pair{Int64,Date}[],);pkey=[:intID])
    visits =  JuliaDB.table((intID=Int64[],patientID=Int64[],bestord=Pair{Int64,Date}[],req_type=String[]);pkey=[:intID])
    for row in eachrow(patientOverview)
        if row.Kategori === missing
            continue
        end
        for i = 1:Int(row.Antal)
            bestord = rand(mastercalendar)
            intID=length(patients)+1
            treatmentplan = generateTreatmentplan(row,bestord,columns,visits,intID)
            push!(rows(patients),(intID=intID,diagnosis="test",bestord=bestord,))
        end
    end
    patients, visits
end

function readWorkPattern(path::String,sheet::String)
    resources = JuliaDB.table((intID=Int64[],id=String[],type=String[],name=String[],qualifications=Dict{String,String}[],workpattern=Calendar[],calendar=Calendar[]);pkey=[:intID])
    workpattern = JuliaDB.table((resourceID=Int64[],weekdayID=Int64[],oddWeek=Bool[],timeslotID=Int64[],startTime=Time[],endTime=Time[]);pkey=[:resourceID,:weekdayID,:timeslotID])
    timeslots = JuliaDB.table((resourceID=Int64[],dayID=Int64[],timeslotID=Int64[],startTime=Time[],endTime=Time[],booked=Bool[]);pkey=[:resourceID,:dayID,:timeslotID]) #TODO Make NDSparse
    readWorkPattern!(resources,timeslots,workpattern,path::String,sheet::String,)
end

function readWorkPattern!(resources,timeslots,workpattern,path::String,sheet::String,)
        columns = Dict{String,Int}("Monday"=>1,"Tuesday"=> 2, "Wednesday" => 3, "Thursday" => 4, "Friday"=> 5)
        wp_df = DataFrame(XLSX.readtable(path,sheet)...)

        for resource_df in DataFrames.groupby(wp_df,[:Type,:Resource],skipmissing = true)
            cur_resourceid = string(resource_df[1,:Type],"_",resource_df[1,:Resource])
            tempID = filter(i -> i.id == cur_resourceid,resources)

            evencalendar = Calendar()
            oddcalendar = Calendar()
            for day in columns
                evenday = Workday(day[2],Even)
                oddday = Workday(day[2],Odd)

                if ismissing(resource_df[1,Symbol(string(day[1],"_start"))]) continue end;
                for row in eachrow(resource_df)
                    if ismissing(row[Symbol(string(day[1],"_start"))]) ||row[Symbol(string(day[1],"_start"))]=="PAUSE"
                         continue
                    end

                    if row.Weeks in ("All","Even")
                        addTimeslot!(evenday,row[Symbol(string(day[1],"_start"))],row[Symbol(string(day[1],"_end"))])
                    end
                    if row.Weeks in ("All","Odd")
                        addTimeslot!(oddday,row[Symbol(string(day[1],"_start"))],row[Symbol(string(day[1],"_end"))])
                    end
                end
                addWorkday!(evencalendar,evenday)
                addWorkday!(oddcalendar,oddday)
            end

            if length(tempID) == 0
                type = string(resource_df[1,:Type])
                name = string(resource_df[1,:Resource])
                resourceid = string(resource_df[1,:Type],"_",resource_df[1,:Resource])
                intID = length(resources)+1
                wp = oddcalendar + evencalendar
                push!(rows(resources),(intID=intID,id=resourceid,type=type,name=name,qualifications=Dict("name" => name,"type"=>type),workpattern=wp,calendar=Calendar()))

            elseif length(tempID) == 1
                intID = first(tempID)
            else
                throw("Error: Multiple resources with same ID")
            end
                for day in columns
                    if ismissing(resource_df[1,Symbol(string(day[1],"_start"))]) continue end;
                    for row in eachrow(resource_df)
                        if ismissing(row[Symbol(string(day[1],"_start"))]) ||row[Symbol(string(day[1],"_start"))]=="PAUSE"
                             continue
                        end
                        push!(rows(workpattern),(resourceID = intID,weekdayID = day[2],oddWeek = !(row.Weeks in ("All","Even")),timeslotID = length(workpattern)+1, startTime = row[Symbol(string(day[1],"_start"))],endTime = row[Symbol(string(day[1],"_end"))]))
                        push!(rows(workpattern),(resourceID = intID,weekdayID = day[2],oddWeek = (row.Weeks in ("All","Odd")),timeslotID = length(workpattern)+1, startTime = row[Symbol(string(day[1],"_start"))],endTime = row[Symbol(string(day[1],"_end"))]))
                    end
                end


        end
        resources, timeslots, workpattern
end

function generateCalendarFromPattern!(resources::Array{Resource},masterCalendar::Dict{Int64,Date})#TODO Throw out old calendar
    @warn Deprecated
    for cur_resource in resources
        for day in sort(collect(masterCalendar))
            daypatterns = filter(x -> (x.weekday == dayofweek(day[2]) && week(day[2])%2 ==Int(x.weektype)%2) ,cur_resource.workpattern.workdays)

            if length(daypatterns) > 0
                length(daypatterns) > 1 &&  @warn ("Multiple day patterns for weekday $(x.weekday) of weektype $(x.weektype), using first pattern")

                daypattern = deepcopy(daypatterns[1])
                addWorkday!(cur_resource.calendar,daypattern,day)

            end

        end
    end
end

function generateCalendarFromPattern!(timeslots,resources::IndexedTable,workpattern,masterCalendar::Dict{Int64,Date},occupancyrate = 1.0)#TODO could be faster with Query
    for cur_resource in rows(resources)
        for day in sort(collect(masterCalendar))

            Lazy.@as x workpattern begin #TODO redo this to not use not use Lazy
                  filter(wptimeslot -> (wptimeslot.resourceID == cur_resource.intID && wptimeslot.weekdayID == dayofweek(day[2]) && week(day[2])%2 == wptimeslot.oddWeek),x)
                  JuliaDB.select(x,(:resourceID,:startTime,:endTime))
                  transform(x, (:dayID => fill(day[1],length(x)),:timeslotID => [i for i in (length(timeslots)+1):(length(timeslots)+length(x))],:booked => [y < occupancyrate for y in rand(length(x))] ))
                  #transform(x, (:resourceID => fill(cur_resource.intID,length(x)),:dayID => fill(day[1],length(x)),:status => [y < occupancyrate for y in rand(length(x))] ))
                  append!(rows(timeslots),rows(x))
               end
        end
    end
end




function generateRandomCalendar!(resources::Array{Resource},occupancyrate::Float64)
    for cur_resource in resources
        for cur_workday in cur_resource.calendar.workdays
            for cur_timeslot in cur_workday.timeslots
                if rand() < occupancyrate
                    cur_timeslot.status = booked
                else
                        cur_timeslot.status = free
                end
            end
        end
    end
end
