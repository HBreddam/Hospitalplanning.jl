
using Dates
using Debugger
using JuMP
using Hospitalplanning
using XLSX
using DataFrames
HP = Hospitalplanning



path = "C:/Users/hebb/.julia/dev/Hospitalplanning/test/Sample data/PatientOverview_test.xlsx"
sheet = "Sheet1"
startdate = Date("2019-01-01")
enddate = Date("2019-08-10")
mastercalendar = HP.MasterCalendar(startdate,enddate)

columns = Dict(:Consultation => "Consultation" , :Telefon =>"Telephone" , :TTE => "TTE", :AEKG => "AEKG",  :MR => "MR", :Holter=>"Holter")
patients = HP.readPatientTable(path,sheet,columns,mastercalendar)


path_resourceOverview = "C:/Users/hebb/.julia/dev/Hospitalplanning/test/Sample data/GUCHamb_Timeslot_test.xlsx"
sheet_amb = "GUCH AMB"
sheet_resources = "External"

GUCHAmb_resources = Hospitalplanning.readWorkPattern(path_resourceOverview,sheet_amb)

external_resources = Hospitalplanning.readWorkPattern(path_resourceOverview,sheet_resources,GUCHAmb_resources)
HP.generateCalendarFromPattern!(GUCHAmb_resources,mastercalendar)

HP.generateRandomCalendar!(GUCHAmb_resources,0.6)

path_TimeDelta = "C:/Users/hebb/.julia/dev/Hospitalplanning/test/Sample data/GUCHamb_timeDelta.xlsx"
sheet_TimeDelta = "Sheet1"
timeDelta = DataFrame(XLSX.readtable(path_TimeDelta,sheet_TimeDelta)...)

submastercalendar = HP.MasterCalendar(mastercalendar,startdate,Date("2019-06-15"))

mp, subs = HP.columngeneration(patients,GUCHAmb_resources,mastercalendar,timeDelta,false)
subs.pricingproblems


test = subs.pricingproblems[subs.sets[1].hash]





#=--------------------------------------------
HP.sortvisit([3,2 , 5, 4 ,1,],test.Tdelta) # TODO her kom jeg til, der er noget galt med den

typeof(subproblems)
cnt = 1
mp.lambda
println.(value.(mp.lambda))
for l in mp.lambda
    global cnt
    println(cnt)
    cnt += 1
    println("$(l) = $(value(l))")
end

value.((x->subproblems[1].tvars[x]).(filter(k-> value(subproblems[1].tvars[k]) > 0 ,eachindex(subproblems[1].tvars))))
filter(k-> value(subproblems[1].tvars[k]) > 0 ,eachindex(subproblems[1].tvars))

value.((x->subproblems[1].kvars[x]).(filter(k-> value(subproblems[1].kvars[k]) > 0 ,eachindex(subproblems[1].kvars))))
filter(k-> value(subproblems[1].kvars[k]) > 0 ,eachindex(subproblems[1].kvars))
HP.getIndexofPositiveVariables(subproblems[1].kvars)

test= filter(k-> value(subproblems[1].xvars[k]) ==1 ,eachindex(subproblems[1].xvars))

filter(k-> value(subproblems[1].yvars[k]) != 0 ,eachindex(subproblems[1].yvars))
subproblems[1].J


# TODO Only solve once for similar patient
=#
