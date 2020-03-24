
"Loads csv with timeslots formatted as in 'test/Sample data/timeslottest_output.csv' "
function loadtimeslots(path)
    colparser = Dict(:startTime => dateformat"H:M:S",:endTime => dateformat"H:M:S")
    res = loadtable(path,colparsers=colparser)|> @map((resourceID = _.resourceID, type= _.type,dayID = _.dayID,timeslotID = _.timeslotID,startTime = Time(_.startTime),endTime= Time(_.endTime),booked = _.booked == "true"  )) |> collect
    return table(res,pkey = [:resourceID,:dayID,:timeslotID])
end

"Saves any object to a CSV file"
function save(object,path::String)
    CSVFiles.save(path, object)
end

function loadresources(path)
    loadtable(path,indexcols= [:intID])
end
"Loads csv with patientdata formatted as in 'test/Sample data/patienttest_output.csv' "
function loadpatients(path)
        loadtable(path,indexcols= [:intID])
end
"Loads csv with \"time delta\" which is the number of days that need to be in between two types of visits. Data should be formatted as in 'test/Sample data/GUCHamb_timeDelta.csv' "
function loadTimeDelta(path_TimeDelta::String)
    loadndsparse(path_TimeDelta,indexcols=1:2)
end

"Loads csv with visitdata formatted as in 'test/Sample data/visittest_output.csv' "
function loadvisits(path)
    loadtable(path,indexcols= [:intID])
end

"Loads csv with a solution formatted as in 'test/Sample data/solutiontest_input.csv' "
function loadsolution(path)
    loadtable(path;indexcols=[:visitID])
end
