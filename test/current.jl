
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

subproblems = HP.Subproblems(length(patients))
for i in 1:length(patients)
    HP.setup_sub!(subproblems,patients[i],GUCHAmb_resources,submastercalendar)
    JuMP.optimize!(subproblems.models[i])
    termination_status(subproblems.models[i])
end

mp = HP.setupmaster(patients,GUCHAmb_resources,submastercalendar)

optimize!(mp.model)

phi = dual.(mp.consref_offtime)
pi = dual.(mp.consref_onepatient)
kappa = dual.(mp.convexitycons)


#--------------------------------------------------------------------------

HP.getDays(GUCHAmb_resources[2],submastercalendar)
(x->x.intID).((filter(x->x.date[1]==7,GUCHAmb_resources[2].calendar.workdays)[1]).timeslots)
HP.getTS(GUCHAmb_resources[2],7)

(x->x.intID).(GUCHAmb_resources[2].calendar.workdays[2].timeslots)
subproblems = HP.Subproblems(1)
Dates.Time(HP.getTSendtime_minutes(GUCHAmb_resources[5],7,4))

latesttime
testt
Dates.value(Time(1))/60000000000
for i in iterate(I)
    println(i)
end
