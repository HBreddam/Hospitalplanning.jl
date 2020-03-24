

#TODO sort treatmentplan by default
function generateTreatmentplan!(visits::IndexedTable,row,bestord,columns::Dict{Symbol,String},patientID)
        for col in columns
            if !ismissing(row[col[1]])
                if row[col[1]] == 1 || rand() < row[col[1]]
                    push!(rows(visits),(intID=length(visits)+1,patientID=patientID,bestord=bestord[1],bestord_date=bestord[2],req_type=col[2]))
                end
            end
        end

end

"""
readPatientTable(path::String,sheet::String,columns::Dict{Symbol,String},mastercalendar::Dict{Int64,Date})

Read aggregated table data of the format found in 'test/Sample data/PatientOverview_test.xlsx'.
Produces a table of patients and a table of visists with the patients best.ord./deadline spread uniformly across everyday of the master calendar.
columns is a Dict{Symbol,String} making it possible to translate the column headers into types of visits

# Examples
```julia-repl
julia> columns = Dict(:Consultation => "Consultation" , :Telefon =>"Telephone" , :TTE => "TTE", :AEKG => "AEKG",  :MR => "MR", :Holter=>"Holter")
Dict{Symbol,String} with 6 entries:
  :MR           => "MR"
  :Telefon      => "Telephone"
  :AEKG         => "AEKG"
  :Holter       => "Holter"
  :Consultation => "Consultation"
  :TTE          => "TTE"

julia> patients, visits = readPatientTable(path,sheet,columns,mastercalendar)
(Table with 40 rows, 4 columns:
intID  diagnosis  bestord  bestord_date
───────────────────────────────────────
1      "test"     31       2019-01-31
2      "test"     22       2019-01-22
3      "test"     16       2019-01-16
4      "test"     28       2019-01-28
5      "test"     8        2019-01-08
6      "test"     2        2019-01-02
⋮
37     "test"     8        2019-01-08
38     "test"     2        2019-01-02
39     "test"     25       2019-01-25
40     "test"     17       2019-01-17, Table with 130 rows, 5 columns:
intID  patientID  bestord  bestord_date  req_type
───────────────────────────────────────────────────────
1      1          31       2019-01-31    "AEKG"
2      1          31       2019-01-31    "Consultation"
3      1          31       2019-01-31    "TTE"
4      2          22       2019-01-22    "AEKG"
5      2          22       2019-01-22    "Consultation"
6      2          22       2019-01-22    "TTE"
⋮
127    39         25       2019-01-25    "TTE"
128    40         17       2019-01-17    "MR"
129    40         17       2019-01-17    "Consultation"
130    40         17       2019-01-17    "TTE")
```
"""
function readPatientTable(path,sheet,columns,mastercalendar)
    patientOverview = DataFrame(XLSX.readtable(path,sheet)...)
    patients = JuliaDB.table((intID=Int64[],diagnosis=String[],bestord=Int64[],bestord_date=Date[]);pkey=[:intID])
    visits =  JuliaDB.table((intID=Int64[],patientID=Int64[],bestord=Int64[],bestord_date=Date[],req_type=String[]);pkey=[:intID])
    for row in eachrow(patientOverview)
        if row.Kategori === missing
            continue
        end
        for i = 1:Int(row.Antal)
            bestord = rand(mastercalendar)
            intID=length(patients)+1
            generateTreatmentplan!(visits,row,bestord,columns,intID)
            push!(rows(patients),(intID=intID,diagnosis="test",bestord=bestord[1],bestord_date=bestord[2]))
        end
    end
    patients, visits
end
"""
readWorkPattern(path_resourceOverview,sheet_amb)

Creates a list of resources, a workpattern which is a list of timeslots in even and odd weeks, and lastly an empty list of timeslots. The data is take from sheet 'sheet_amb' in the excel file given in path_resourceOverview. The format for the files can be seen in 'test/Sample data/GUCHamb_Timeslot_test.xlsx'

# Examples
```julia-repl
julia> readWorkPattern(path_resourceOverview,sheet_amb)
(Table with 3 rows, 4 columns:
intID  id                     type            name
──────────────────────────────────────────────────────
1      "Consultation_GUCH L"  "Consultation"  "GUCH L"
2      "Consultation_MRS"     "Consultation"  "MRS"
3      "Consultation_NV"      "Consultation"  "NV",
Table with 0 rows, 7 columns:
resourceID  type  dayID  timeslotID  startTime  endTime  booked
───────────────────────────────────────────────────────────────,
Table with 82 rows, 7 columns:
resourceID  type            weekdayID  oddWeek  timeslotID  startTime  endTime
───────────────────────────────────────────────────────────────────────────────
1           "Consultation"  5          false    1           09:00:00   09:30:00
1           "Consultation"  5          true     2           09:00:00   09:30:00
⋮
3           "Consultation"  1          false    81          11:15:00   12:00:00
3           "Consultation"  1          false    82          11:15:00   12:00:00)
```
"""
function readWorkPattern(path::String,sheet::String)
    resources = JuliaDB.table((intID=Int64[],id=String[],type=String[],name=String[],);pkey=[:intID])
    #resources = JuliaDB.table((intID=Int64[],id=String[],type=String[],name=String[],qualifications=Dict{String,String}[],);pkey=[:intID])
    workpattern = JuliaDB.table((resourceID=Int64[],type = String[],weekdayID=Int64[],oddWeek=Bool[],timeslotID=Int64[],startTime=Time[],endTime=Time[]);pkey=[:resourceID,:weekdayID,:timeslotID])
    timeslots = JuliaDB.table((resourceID=Int64[],type = String[], dayID=Int64[],timeslotID=Int64[],startTime=Time[],endTime=Time[],booked=Bool[]);pkey=[:resourceID,:dayID,:timeslotID])
    readWorkPattern!(resources,timeslots,workpattern,path::String,sheet::String,)
end


"""
readWorkPattern!(resources,timeslots,workpattern,path::String,sheet::String,)

Adds additional resources to the list of resources and creates workpattern for these added to workpattern

"""
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

"""
generateCalendarFromPattern!(timeslots,resources::IndexedTable,workpattern,masterCalendar::Dict{Int64,Date},occupancyrate = 0)

Populates the variable timeslots with appropriate timeslots from workpattern list for everyday in the mastercalendar. occupancyrate is the part of the timeslots that should be randomly booked (meaning that they are completely taken out of the planning problem). 0 means no booked, 0.5 means half of all slots are booked and 1 means all slots are booked.

"""
function generateCalendarFromPattern!(timeslots,resources::IndexedTable,workpattern,masterCalendar::Dict{Int64,Date},occupancyrate = 0)#
    for cur_resource in rows(resources)
        for _day in sort(collect(masterCalendar))
            xtemp  =  @from i in workpattern begin
                    @where i.resourceID == cur_resource.intID && i.weekdayID == dayofweek(_day[2]) && week(_day[2])%2 == i.oddWeek
                    @select {resourceID=i.resourceID,type= i.type,startTime= i.startTime,endTime = i.endTime}
                    @collect
                end
            if length(xtemp) > 0
                x = table(xtemp)
                y = (:dayID => fill(_day[1],length(x)),:timeslotID => [i for i in (length(rows(timeslots))+1):(length(rows(timeslots))+length(x))],:booked => [y <= (1-occupancyrate)  for y in rand(length(x))] )
                x = transform(x, y)
                append!(rows(timeslots),rows(x))
            end
        end
    end
end
