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
columns = [(:Visits,"Consultation"),(:Telefon,"Telephone"),(:TTE,"TTE"),(:AEKG,"EKG"),(:MR,"MR"),(:Holter,"Holter")]
HP.readPatientTable(path,sheet,columns,mastercalendar)

path_resourceOverview = "C:/Users/hebb/OneDrive - Danmarks Tekniske Universitet/Project/RH/Data/Sample data/GUCHamb_Timeslots.xlsx"
sheet_amb = "GUCH AMB"
sheet_resources = "External"

GUCHAmb_resources = Hospitalplanning.readWorkPattern(path_resourceOverview,sheet_amb)
external_resources = Hospitalplanning.readWorkPattern(path_resourceOverview,sheet_resources)
HP.generateCalendarFromPattern!(resources,mastercalendar)
resources
HP.generateRandomCalendar!(resources,0.8)
resources
