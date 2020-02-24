
using Dates
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
enddate = Date("2019-02-01")
mastercalendar = HP.MasterCalendar(startdate,enddate)

columns = Dict(:Consultation => "Consultation" , :Telefon =>"Telephone" , :TTE => "TTE", :AEKG => "AEKG",  :MR => "MR", :Holter=>"Holter")
patients, visits = HP.readPatientTable(path,sheet,columns,mastercalendar)


path_resourceOverview = "C:/Users/hebb/.julia/dev/Hospitalplanning/test/Sample data/GUCHamb_Timeslot_test.xlsx"
sheet_amb = "GUCH AMB"
sheet_resources = "External"

GUCHAmb_resources,timeslots,workpattern = Hospitalplanning.readWorkPattern(path_resourceOverview,sheet_amb)
external_resources = Hospitalplanning.readWorkPattern!(GUCHAmb_resources,timeslots,workpattern,path_resourceOverview,sheet_resources,)
GUCHAmb_resources
timeDelta
HP.generateCalendarFromPattern!(timeslots,GUCHAmb_resources,workpattern,mastercalendar,0.5)

submastercalendar = HP.MasterCalendar(mastercalendar,startdate,Date("2019-06-15"))
visits
mp, subs,sets = HP.columngeneration(patients,visits,GUCHAmb_resources,timeslots,mastercalendar,timeDelta; multithreading = true,setuponly=false)

test = HP.extractsolution(mp,sets,timeslots,visits)
HP.findvisit(visits,"AEKG",33)
test|> @filter(_.pattern == 179)
visits[105]
visits |> @filter(_.patientID == 33)
testpg =  copy(sets.Pg)
tempPg = sets.Pg |>@map(_.patients) |> collect
sets.Pg[1]
tempPg[1]
x = pop!(tempPg[1])
timeslots[100].type
function findvisit(visits,type,patient)
   result = @from i in visits begin
      @where i.req_type == timeslots[100].type && i.patientID == x
      @select i.intID
      @collect
   end
   if length(result)== 1
      return first(result)
   end
   @warn "Multiple visits of same type found"
   return -1
end
findvisit(visits,timeslots[100].type, x)
visits
#=-----------------------1--------------------


=#
