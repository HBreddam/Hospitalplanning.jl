
using Dates
using Debugger
using JuMP
using Gurobi

using DataFrames
using JuliaDB
using Query
using BenchmarkTools
using Hospitalplanning
HP = Hospitalplanning



path = "C:/Users/hebb/.julia/dev/Hospitalplanning/test/Sample data/PatientOverview_test.xlsx"
sheet = "Sheet1"
startdate = Date("2019-01-01")
enddate = Date("2019-03-10")
mastercalendar = HP.MasterCalendar(startdate,enddate)

columns = Dict(:Consultation => "Consultation" , :Telefon =>"Telephone" , :TTE => "TTE", :AEKG => "AEKG",  :MR => "MR", :Holter=>"Holter")
patients, visits = HP.readPatientTable(path,sheet,columns,mastercalendar)
visits

path_resourceOverview = "C:/Users/hebb/.julia/dev/Hospitalplanning/test/Sample data/GUCHamb_Timeslot_test.xlsx"
sheet_amb = "GUCH AMB"
sheet_resources = "External"

GUCHAmb_resources,timeslots,workpattern = Hospitalplanning.readWorkPattern(path_resourceOverview,sheet_amb)
external_resources = Hospitalplanning.readWorkPattern!(GUCHAmb_resources,timeslots,workpattern,path_resourceOverview,sheet_resources,)
GUCHAmb_resources
HP.generateCalendarFromPattern!(timeslots,GUCHAmb_resources,workpattern,mastercalendar,0.5)


path_TimeDelta = "C:/Users/hebb/.julia/dev/Hospitalplanning/test/Sample data/GUCHamb_timeDelta.csv"
timeDelta = loadndsparse(path_TimeDelta,indexcols=1:2)

submastercalendar = HP.MasterCalendar(mastercalendar,startdate,Date("2019-06-15"))

mp, subs = HP.columngeneration(patients,visits,GUCHAmb_resources,timeslots,mastercalendar,timeDelta,false)


#=-------------------------------------------


=#
