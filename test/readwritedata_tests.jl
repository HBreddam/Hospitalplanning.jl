using Dates
using JuliaDB


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
GUCHAmb_resources[1]
path_TimeDelta = "./test/Sample data/GUCHamb_timeDelta.csv"
timeDelta = HP.loadTimeDelta(path_TimeDelta)
HP.generateCalendarFromPattern!(timeslots,GUCHAmb_resources,workpattern,mastercalendar,0.5)
timeslots2 = ndsparse(timeslots)

testpath_resources = "./test/Sample data/resourcetest_output.csv"
HP.save(GUCHAmb_resources,testpath_resources)
resources_read = HP.loadresources(testpath_resources)
@test GUCHAmb_resources == resources_read

testpath_patient = "./test/Sample data/patienttest_output.csv"
HP.save(patients,testpath_patient)
patients_read = HP.loadpatients(testpath_patient)
@test patients == patients_read

testpath_visits = "./test/Sample data/visittest_output.csv"
HP.save(visits,testpath_visits)
visits_read = HP.loadvisits(testpath_visits)
@test visits == visits_read


testpath_timeslots = "./test/Sample data/timeslottest_output.csv"
HP.save(timeslots,testpath_timeslots)
timeslots_read = HP.loadtimeslots(testpath_timeslots)
@test timeslots == timeslots_read
timeslots2_read = ndsparse(timeslots_read)
@test timeslots2 == timeslots2_read




testpath_solution_input = "./test/Sample data/solutiontest_input.csv"
testpath_solution_output = "./test/Sample data/solutiontest_output.csv"
solution_read = HP.loadsolution(testpath_solution_input)

HP.save(solution_read,testpath_solution_output)
solution_read2 = HP.loadsolution(testpath_solution_output)

@test solution_read2 == solution_read
