getDays(resource,subcal) = (x->x.date[1]).(filter(day ->day.date in subcal,resource.calendar.workdays))

function getTimeSlot(resource,dayID)
    workdays = filter(x->x.date[1]==dayID,resource.calendar.workdays)
    length(workdays) > 1 ? error("Multiple days with same dayID") :
    length(workdays) == 1 ? (x->x.intID).(filter(x-> x.status == free ,workdays[1].timeslots)) : Int64[]
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
getResource(resources,visits) = findqualifiedResourceIDs(resources,visits)
function getDelta(TimeDelta,visit1,visit2)
    rows = filter(row-> row[:Visit1] == visit1.required_qualifications["type"] && row[:Visit2] == visit2.required_qualifications["type"],TimeDelta)
    if nrow(rows) == 1
        return rows[1,:Min_days], rows[1,:Preceed]
    else
        return 0, false
        @warn "Multiple results for delta lookup"
    end
end


getIndexofPositiveVariables(vars) = filter(k-> value(vars[k]) > 0 ,eachindex(vars))
getvalueofPositiveVariables(vars) = value.((x->vars[x]).(filter(k-> value(vars[k]) > 0 ,eachindex(vars))))
