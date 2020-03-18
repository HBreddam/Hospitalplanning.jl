

function savepatients(object,path::String)
    CSVFiles.save(path, object)
end

function savetimeslots(object,path::String)
    CSVFiles.save(path, object)
end


function loadtimeslots(path)
    colparser = Dict(:startTime => dateformat"H:M:S",:endTime => dateformat"H:M:S")
    res = loadtable(path,colparsers=colparser)|> @map((resourceID = _.resourceID, type= _.type,dayID = _.dayID,timeslotID = _.timeslotID,startTime = Time(_.startTime),endTime= Time(_.endTime),booked = _.booked == "true"  )) |> collect
    return table(res,pkey = [:resourceID,:dayID,:timeslotID])
end


function save(object,path::String)
    CSVFiles.save(path, object)
end

function loadresources(path)
    loadtable(path,indexcols= [:intID])
end

function loadpatients(path,indexcols=[])
    if length(indexcols) == 0
        loadtable(path,)
    else
        loadndsparse(path,indexcols)
    end
end
function loadTimeDelta(path_TimeDelta::String)
    loadndsparse(path_TimeDelta,indexcols=1:2)
end

function loadvisits(path)
    loadtable(path,indexcols= [:intID])
end

function loadsolution(path)
    loadtable(path;indexcols=[:visitID])
end
