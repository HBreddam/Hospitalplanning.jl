
getDays(resource,subcal) = (x->x.date[1]).(filter(day ->day.date in subcal,resource.calendar.workdays))

function buildJd(timeslots,subcal)
     timeslots |> @filter(_.dayID in keys(subcal) && !_.booked)|>@groupby(_.resourceID) |>@map((d = key(_),j = unique(map(x->x.dayID,_)))) |> NDSparse
end
function buildI(timeslots)
    timeslots|> @filter(!_.booked) |> @groupby((_.resourceID,_.dayID)) |> @map({d=key(_)[1],j=key(_)[2],i=map(x->x.timeslotID,_)})|> NDSparse
end



function getTlowerbound(timeslots,resourceID,dayID)
    bookedslots = timeslots |> @filter(_.resourceID == resourceID && _.dayID == dayID && _.booked )|> @orderby(_.endTime) |> @take(1)  |>@map(_.endTime) |> collect
    if length(bookedslots) == 1
        value = Dates.value(first(bookedslots))/60000000000
    else
        value = 0
    end
    return value
end

getTSendtime(resource,dayID,slotID) = Dates.value(filter(x->x.date[1]==dayID,resource.calendar.workdays)[1].timeslots[slotID].endTime)/60000000000
function getTSendtime(resource,dayID,slotID,refDate)
    workday = filter(x->x.date[1]==dayID,resource.calendar.workdays)[1]
    datetime = workday.timeslots[slotID].endTime + workday.date[2]
    Dates.value(datetime-refDate)/60000
end
function getTSstarttime(resource,dayID,slotID,refDate)
    workday = filter(x->x.date[1]==dayID,resource.calendar.workdays)[1]
    test = length(workday.timeslots)
    slotID > test ? error("slotID out of range") :
    datetime = workday.timeslots[slotID].startTime + workday.date[2]
    Dates.value(datetime-refDate)/60000
end
getTSstarttime(resource,dayID,slotID) = Dates.value(filter(x->x.date[1]==dayID,resource.calendar.workdays)[1].timeslots[slotID].startTime)/60000000000

function buildVp(visits)
    visits |> @groupby(_.patientID) |> @map((p = key(_),v = map(x->x.intID,_))) |> NDSparse
end
function buildDv(resources,visits)
    visits |> @groupjoin(resources,_.req_type,_.type, (v=Int64(_.intID),d=map(x->x.intID,__))) |> NDSparse
end


function buildDp(resources,visits)
    visits |> @groupjoin(resources,_.req_type,_.type, (v=_.intID,p=_.patientID,d=map(x->x.intID,__))) |> @groupby(_.p) |>@map((p = key(_),d = (collect(Iterators.flatten(_.d)) ))) |>NDSparse
end

"Helper function for grouping patients. Produces a tuple of the patients group"
function patientgroup(visits,Vp,id)
   tempvisits = visits[Vp[id].v]

   (sort(JuliaDB.select(tempvisits,:req_type)),
   Dates.Month(reduce(max,tempvisits,select=:bestord_date)),
   Dates.Month(reduce(min,tempvisits,select=:bestord_date)))
end

"Produces a IndexedTable of patient groups based on the function patientgroup()"
function buildPg(patients,visits,Vp,timeDelta)
    table(patients |> @groupby(patientgroup(visits,Vp,_.intID))|> @map((types=sortvisit(key(_)[1],timeDelta),startmonth=key(_)[2],endmonths=key(_)[3],patients= map(x->x.intID,_))) |> collect)
end


getIndexofPositiveVariables(vars) = filter(k-> value(vars[k]) > 0 ,eachindex(vars))
getvalueofPositiveVariables(vars) = value.((x->vars[x]).(filter(k-> value(vars[k]) > 0 ,eachindex(vars))))
getPositiveVariables(vars) = (x->vars[x]).(filter(k-> value(vars[k]) > 0 ,eachindex(vars)))
getPositiveVariablesAndValues(vars) = (x->(vars[x], value(vars[x]))).(filter(k-> value(vars[k]) > 0 ,eachindex(vars)))

hashSets(subproblem) = hash((subproblem.D_v,subproblem.J_d,subproblem.I,subproblem.Ts,subproblem.Te))
