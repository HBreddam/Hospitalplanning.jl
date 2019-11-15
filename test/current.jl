
using Dates
using Debugger
using JuMP
using Hospitalplanning
HP = Hospitalplanning



path = "C:/Users/hebb/.julia/dev/Hospitalplanning/test/Sample data/PatientOverview_test.xlsx"
sheet = "Sheet1"
startdate = Date("2019-01-01")
enddate = Date("2019-12-31")
mastercalendar = HP.MasterCalendar(startdate,enddate)
mastercalendar[1]
columns = Dict(:Consultation => "Consultation" , :Telefon =>"Telephone" , :TTE => "TTE", :AEKG => "AEKG",  :MR => "MR", :Holter=>"Holter")
patients = HP.readPatientTable(path,sheet,columns,mastercalendar)
patients

path_resourceOverview = "C:/Users/hebb/.julia/dev/Hospitalplanning/test/Sample data/GUCHamb_Timeslot_test.xlsx"
sheet_amb = "GUCH AMB"
sheet_resources = "External"

GUCHAmb_resources = Hospitalplanning.readWorkPattern(path_resourceOverview,sheet_amb)
GUCHAmb_resources
external_resources = Hospitalplanning.readWorkPattern(path_resourceOverview,sheet_resources,GUCHAmb_resources)
HP.generateCalendarFromPattern!(GUCHAmb_resources,mastercalendar)

HP.generateRandomCalendar!(GUCHAmb_resources,0.8)


submastercalendar = HP.MasterCalendar(mastercalendar,startdate,enddate-Day(100))
patients[1].treatmentplan

HP.findqualifiedResources(GUCHAmb_resources,patients[1].treatmentplan)
HP.findqualifiedResourceIDs(GUCHAmb_resources,patients[1].treatmentplan)

subproblems = Dict{Int64,HP.Subproblem}()
for i in 1:length(patients)
    println("Setting up subproblem for patient $(i):")
    HP.setup_sub!(subproblems,patients[i],GUCHAmb_resources,submastercalendar)

end

subproblems
mp = HP.setupmaster(patients,GUCHAmb_resources,submastercalendar)

optimize!(mp.model)

phi = dual.(mp.consref_offtime)
pi = dual.(mp.consref_onepatient)
kappa = dual.(mp.convexitycons)
for i in 1:length(patients)
    println("Solving subproblem for patient $(i)")
    HP.solveSub(subproblems[i],phi,pi,kappa,1)
end


HP.addcolumntomaster(mp,subproblems,1)
mp
JuMP.objective_value(mp.model)
#--------------------------------------------------------------------------
typeof(subproblems)
HP.getIndexofPositiveVariables(mp.lambda_new)
value.((x->subproblems[1].tvars[x]).(filter(k-> value(subproblems[1].tvars[k]) > 0 ,eachindex(subproblems[1].tvars))))
filter(k-> value(subproblems[1].tvars[k]) > 0 ,eachindex(subproblems[1].tvars))

value.((x->subproblems[1].kvars[x]).(filter(k-> value(subproblems[1].kvars[k]) > 0 ,eachindex(subproblems[1].kvars))))
filter(k-> value(subproblems[1].kvars[k]) > 0 ,eachindex(subproblems[1].kvars))
HP.getIndexofPositiveVariables(subproblems[1].kvars)

test= filter(k-> value(subproblems[1].xvars[k]) ==1 ,eachindex(subproblems[1].xvars))

filter(k-> value(subproblems[1].yvars[k]) != 0 ,eachindex(subproblems[1].yvars))
subproblems[1].J
