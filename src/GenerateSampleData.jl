using XLSX
using DataFrames
using Random
using UUIDs
using JuliaDB
using Lazy

#TODO sort treatmentplan by default
function generateTreatmentplan!(visits::IndexedTable,row::DataFrameRow,bestord::Pair{Int64,Date},columns::Dict{Symbol,String},patientID)
        for col in columns
            if !ismissing(row[col[1]])
                if row[col[1]] == 1 || rand() < row[col[1]]
                    push!(rows(visits),(intID=length(visits)+1,patientID=patientID,bestord=bestord,req_type=col[2]))
                end
            end
        end

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
            generateTreatmentplan!(visits,row,bestord,columns,intID)
            push!(rows(patients),(intID=intID,diagnosis="test",bestord=bestord,))
        end
    end
    patients, visits
end

function readWorkPattern(path::String,sheet::String)
    resources = JuliaDB.table((intID=Int64[],id=String[],type=String[],name=String[],qualifications=Dict{String,String}[],);pkey=[:intID])
    workpattern = JuliaDB.table((resourceID=Int64[],type = String[],weekdayID=Int64[],oddWeek=Bool[],timeslotID=Int64[],startTime=Time[],endTime=Time[]);pkey=[:resourceID,:weekdayID,:timeslotID])
    timeslots = JuliaDB.table((resourceID=Int64[],type = String[], dayID=Int64[],timeslotID=Int64[],startTime=Time[],endTime=Time[],booked=Bool[]);pkey=[:resourceID,:dayID,:timeslotID])
    readWorkPattern!(resources,timeslots,workpattern,path::String,sheet::String,)
end

function readWorkPattern!(resources,timeslots,workpattern,path::String,sheet::String,)
        columns = Dict{String,Int}("Monday"=>1,"Tuesday"=> 2, "Wednesday" => 3, "Thursday" => 4, "Friday"=> 5)
        wp_df = DataFrame(XLSX.readtable(path,sheet)...)
        for resource_df in DataFrames.groupby(wp_df,[:Type,:Resource],skipmissing = true)
            cur_resourceid = string(resource_df[1,:Type],"_",resource_df[1,:Resource])
            tempID = filter(i -> i.id == cur_resourceid,resources)
            if length(tempID) == 0
                type = string(resource_df[1,:Type])
                name = string(resource_df[1,:Resource])
                resourceid = string(resource_df[1,:Type],"_",resource_df[1,:Resource])
                intID = length(resources)+1

                push!(rows(resources),(intID=intID,id=resourceid,type=type,name=name,qualifications=Dict("name" => name,"type"=>type)))

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
                    push!(rows(workpattern),(resourceID = intID,type = string(resource_df[1,:Type]),weekdayID = day[2],oddWeek = !(row.Weeks in ("All","Even")),timeslotID = length(workpattern)+1, startTime = row[Symbol(string(day[1],"_start"))],endTime = row[Symbol(string(day[1],"_end"))]))
                    push!(rows(workpattern),(resourceID = intID,type = string(resource_df[1,:Type]),weekdayID = day[2],oddWeek = (row.Weeks in ("All","Odd")),timeslotID = length(workpattern)+1, startTime = row[Symbol(string(day[1],"_start"))],endTime = row[Symbol(string(day[1],"_end"))]))
                end
            end
        end
        resources, timeslots, workpattern
end


function generateCalendarFromPattern!(timeslots,resources::IndexedTable,workpattern,masterCalendar::Dict{Int64,Date},occupancyrate = 1.0)#
    for cur_resource in rows(resources)
        for _day in sort(collect(masterCalendar))
            xtemp  =  @from i in workpattern begin
                    @where i.resourceID == cur_resource.intID && i.weekdayID == dayofweek(_day[2]) && week(_day[2])%2 == i.oddWeek
                    @select {resourceID=i.resourceID,type= i.type,startTime= i.startTime,endTime = i.endTime}
                    @collect
                end
            if length(xtemp) > 0
                x = table(xtemp)
                y = (:dayID => fill(_day[1],length(x)),:timeslotID => [i for i in (length(rows(timeslots))+1):(length(rows(timeslots))+length(x))],:booked => [y < occupancyrate  for y in rand(length(x))] )
                x = transform(x, y)
                append!(rows(timeslots),rows(x))
            end
        end
    end
end
