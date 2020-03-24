using Dates
using Hospitalplanning
HP = Hospitalplanning



path = "./test/Sample data/PatientOverview_test.xlsx"
sheet = "Sheet1"
startdate = Date("2019-01-01")
enddate = Date("2019-02-01")
mastercalendar = HP.MasterCalendar(startdate,enddate)

columns = Dict(:Consultation => "Consultation" , :Telefon =>"Telephone" , :TTE => "TTE", :AEKG => "AEKG",  :MR => "MR", :Holter=>"Holter")
patients, visits = HP.readPatientTable(path,sheet,columns,mastercalendar)


path_resourceOverview = "./test/Sample data/GUCHamb_Timeslot_test.xlsx"
sheet_amb = "GUCH AMB"
sheet_resources = "External"
GUCHAmb_resources,timeslots,workpattern = Hospitalplanning.readWorkPattern(path_resourceOverview,sheet_amb)
external_resources = Hospitalplanning.readWorkPattern!(GUCHAmb_resources,timeslots,workpattern,path_resourceOverview,sheet_resources,)
path_TimeDelta = "./test/Sample data/GUCHamb_timeDelta.csv"
timeDelta = HP.loadTimeDelta(path_TimeDelta)
HP.generateCalendarFromPattern!(timeslots,GUCHAmb_resources,workpattern,mastercalendar,0.5)


mp, subs,sets = HP.columngeneration(patients,visits,GUCHAmb_resources,timeslots,mastercalendar,timeDelta; multithreading = false,setuponly=false)

solution = HP.extractsolution(mp,sets,timeslots,visits)
HP.save(solution,"./solution.csv")


#=-----------------------1--------------------


=#
