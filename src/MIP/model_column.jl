
EPSVALUE = 0.1


function columngeneration(patients, visits, resources, timeslots, mastercalendar, timeDelta; setuponly = false, multithreading = false)
    println("Building sets")
    timeslotsNDSparse = ndsparse(timeslots)
    subproblems = Subproblems()
    sets = Sets()
    sets.Vp = buildVp(visits)
    sets.Dv = buildDv(resources,visits)
    sets.Dp = buildDp(resources,visits)
    sets.J = keys(mastercalendar)
    sets.Jd = buildJd(timeslots,mastercalendar)
    sets.I = buildI(timeslots)
    sets.Pg = buildPg(patients,visits,sets.Vp,timeDelta)
    println("Setting up sub-problems")
    setup_sub!(subproblems,patients,visits,resources,timeslotsNDSparse,mastercalendar,timeDelta,sets,1)
    println("Setting up master")
    mp = setupmaster(subproblems,patients,resources,timeslots,mastercalendar,sets)
    generateInitialColumns!(mp,sets,timeslots,timeDelta)

    if setuponly
        return mp, subproblems, sets
    end
    iteration = 0
    done = false
    while !done
        iteration +=1
        println(iteration)
        println("Solving master")
        optimize!(mp.model)
        println("Master objective value = $(JuMP.objective_value(mp.model))")
        done = true
        status = termination_status(mp.model)
        if status != MOI.TerminationStatusCode(1)
            throw("Error: Non optimal masterproblem")
        end

        #ϕ = dual.(mp.consref_offtime)
        ϕ = []
        θ = dual.(mp.consref_onepatient)
        κ = dual.(mp.convexitycons)

        println("Solving subproblems")
        if multithreading
            subthreads = []
            for sub in values(subproblems.pricingproblems)
                push!(subthreads,Threads.@spawn solveSub!(sub,sets,ϕ,θ,κ))
            end
            #end
            for thread in subthreads
                wait(thread) #TODO remove multithreading, fix at turn MT back on
            end
        else
            for sub in values(subproblems.pricingproblems)
                solveSub!(sub,sets,ϕ,θ,κ)
                # solveSub!(sub,ϕ,θ,κ)
                # done2 = addcolumntomaster!(mp,sub,iteration,EPSVALUE) #TODO add patient info
                # done &= done2
                # count = 0
                # while !done2 && count < 0#length(sub.patients)
                #     count += 1
                #     solveSub!(sub,getIndexofPositiveVariables(sub.xvars)) #TODO time this
                #     done2 = addcolumntomaster!(mp,sub,iteration,EPSVALUE)
                # end
            end
            #end

        end
        done = addcolumntomaster!(mp,subproblems,iteration,EPSVALUE)

    end



    println("LP objective value = $(JuMP.objective_value(mp.model))")
    Gurobi.setparams!(mp.env, OutputFlag=1,TimeLimit=600)
    set_integer.(mp.lambda)
    optimize!(mp.model)
    println("MIP objective value = $(JuMP.objective_value(mp.model))")

    return mp, subproblems, sets
end

function findvisit(visits,type,patient)
   result = @from i in visits begin
      @where i.req_type == type && i.patientID == patient
      @select i.intID
      @collect
   end
   if length(result)== 1
      return first(result)
   end
   @warn "Multiple visits of same type found"
   println(type)
   println(patient)
   return -1
end

"Extracts the solution into an indexed table"
function extractsolution(mp,sets,timeslots,visits)
    plannedappointments = table((pattern = Int64[],patientgroup = Int64[],patient = Int64[],visit = Int64[], resourceID = Int64[], dayID= Int64[], timeslotID = Int64[]);pkey=[:pattern,:timeslotID] )
    tempPg = sets.Pg |>@map(copy(_.patients)) |> collect
    for x in getPositiveVariables(mp.lambda)
       patientgroup = first(filter(λ->normalized_coefficient(mp.convexitycons[λ],x)> 0,eachindex(mp.convexitycons)))[1]
       patient = pop!(tempPg[patientgroup])
       for y in eachindex(mp.consref_onepatient)
       if JuMP.normalized_coefficient(mp.consref_onepatient[y],x) > 0

          push!(rows(plannedappointments),(pattern=x.index.value,patientgroup = patientgroup,patient = patient,visit = findvisit(visits,timeslots[y[3]].type,patient), resourceID = y[1],dayID= y[2], timeslotID = y[3]))
       end
       end
    end
    plannedappointments
end

"Validate solutions "
function solutionvalidator()
    allvisits()
    correctorder()
    nooverlaps()
    deadline()
end
