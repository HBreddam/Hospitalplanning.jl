using XLSX
using DataFrames
using Random
using UUIDs


function generateTreatmentplan(row::DataFrameRow,bestord::Pair{Int64,Date},columns::Dict{Symbol,String})
    treatmentplan = []
        for col in columns
            if !ismissing(row[col[1]])

                if row[col[1]] == 1
                    push!(treatmentplan,Hospitalplanning.UnplannedVisit(length(treatmentplan)+1,string(uuid4()),bestord,col[2]))
                elseif rand() < row[col[1]]
                    push!(treatmentplan,Hospitalplanning.UnplannedVisit(length(treatmentplan)+1,string(uuid4()),bestord,col[2]))
                end
            end
        end
    treatmentplan
end

function readPatientTable(path,sheet,columns,mastercalendar)
    patientOverview = DataFrame(XLSX.readtable(path,sheet)...)
    patients = Patient[]
    for row in eachrow(patientOverview)
        if row.Kategori === missing
            continue
        end
        for i = 1:Int(row.Antal)
            bestord = rand(mastercalendar)
            treatmentplan = generateTreatmentplan(row,bestord,columns)
            addNewPatient!(patients,string(row.Kategori, "_" , i),0,row.Diagnoser1,treatmentplan)
        end
    end
    patients
end

function readWorkPattern(path::String,sheet::String,resources::Array{Resource}=Resource[])
        columns = Dict{String,Int}("Monday"=>1,"Tuesday"=> 2, "Wednesday" => 3, "Thursday" => 4, "Friday"=> 5)
        wp_df = DataFrame(XLSX.readtable(path,sheet)...)
        for resource_df in groupby(wp_df,[:Type,:Resource],skipmissing = true)
            cur_resourceid = string(resource_df[1,:Type],"_",resource_df[1,:Resource])
            cur_resourcelocation = findfirst(x -> x.id == cur_resourceid, resources)
            if isnothing(cur_resourcelocation)
                addNewResource!(resources,string(resource_df[1,:Type]),string(resource_df[1,:Resource]))
                cur_resourcelocation = length(resources)
            end
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
            addWorkPattern(resources[cur_resourcelocation],oddcalendar,evencalendar)


        end
        resources
end

function generateCalendarFromPattern!(resources::Array{Resource},masterCalendar::Dict{Int64,Date})
    for cur_resource in resources
        for day in sort(collect(masterCalendar))
            daypatterns = filter(x -> (x.weekday == dayofweek(day[2]) && week(day[2])%2 ==Int(x.weektype)%2) ,cur_resource.workpattern.workdays)

            if length(daypatterns) > 0
                length(daypatterns) > 1 &&  @warn ("Multiple day patterns for weekday $(x.weekday) of weektype $(x.weektype), using first pattern")
                # daypatterns[1].date = day

                # for y in daypatterns[1].timeslots
                #     y.date = day
                # end
                daypattern = deepcopy(daypatterns[1])
                addWorkday!(cur_resource.calendar,daypattern,day)

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
