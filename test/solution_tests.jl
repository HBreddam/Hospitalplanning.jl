using Dates
using JuliaDB

path = "./test/Sample data/PatientOverview_test.xlsx"
sheet = "Sheet1"
startdate = Date("2019-01-01")
enddate = Date("2019-02-01")
mastercalendar = HP.MasterCalendar(startdate,enddate)


testpath_resources = "./test/Sample data/resourcetest_output.csv"
testpath_patient = "./test/Sample data/patienttest_output.csv"
testpath_visits = "./test/Sample data/visittest_output.csv"
testpath_timeslots = "./test/Sample data/timeslottest_output.csv"
path_TimeDelta = "./test/Sample data/GUCHamb_timeDelta.csv"

patients = HP.loadpatients(testpath_patient)
visits = HP.loadvisits(testpath_visits)
resources = HP.loadresources(testpath_resources)
timeslots = HP.loadtimeslots(testpath_timeslots)
timeDelta = HP.loadTimeDelta(path_TimeDelta)


mp, subs,sets = HP.columngeneration(patients,visits,resources,timeslots,mastercalendar,timeDelta; multithreading = false,setuponly=false)


plannedappointments = HP.extractsolution(mp,sets,timeslots,visits)
pass = true
@test HP.allvisits(visits,plannedappointments)
@test HP.correctorder(plannedappointments,timeslots,timeDelta)
@test HP.daysused(mp,plannedappointments)
@test HP.deadline()
