using Revise
using Dates
using Debugger
using Hospitalplanning
HP = Hospitalplanning



path = "C:/Users/hebb/OneDrive - Danmarks Tekniske Universitet/Project/RH/Data/Sample data/PatientOverview.xlsx"
sheet = "Sheet1"
startdate = Date("2019-01-01")
enddate = Date("2019-12-31")
mastercalendar = HP.MasterCalendar(startdate,enddate)
mastercalendar[1]
columns = Dict(:Visits => "Consultation" , :Telefon =>"Telephone" , :TTE => "TTE", :AEKG => "EKG",  :MR => "MR", :Holter=>"Holter")
HP.readPatientTable(path,sheet,columns,mastercalendar)


path_resourceOverview = "C:/Users/hebb/OneDrive - Danmarks Tekniske Universitet/Project/RH/Data/Sample data/GUCHamb_Timeslots.xlsx"
sheet_amb = "GUCH AMB"
sheet_resources = "External"

GUCHAmb_resources = Hospitalplanning.readWorkPattern(path_resourceOverview,sheet_amb)
GUCHAmb_resources
external_resources = Hospitalplanning.readWorkPattern(path_resourceOverview,sheet_resources,GUCHAmb_resources)
HP.generateCalendarFromPattern!(GUCHAmb_resources,mastercalendar)
GUCHAmb_resources
HP.generateRandomCalendar!(GUCHAmb_resources,0.8)
GUCHAmb_resources

submastercalendar = HP.MasterCalendar(mastercalendar,startdate,enddate-Day(100))
(x->x.intID).(GUCHAmb_resources)
(x->x.date[1]).(filter(day ->day.date in submastercalendar,GUCHAmb_resources[2].calendar.workdays))
(x->x.date[1]).(filter(day ->day.date in submastercalendar,GUCHAmb_resources[2].calendar.workdays))
x = GUCHAmb_resources[1]

y = x

x.intID = 1

y
