
EPSVALUE = 0.1



"""
columngeneration(patients, visits, resources, timeslots, mastercalendar, timeDelta; setuponly = false, multithreading = false)

Builds the optimization problem and solves it.
If the problem should only be set up and not solved, apply setuponly = true.
The problem can be solved with multithreading by setting multithreading = true

"""
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
                wait(thread)
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
"Find a visit that fits with a patient and a visittype"
function findvisit(visits,type,patient)
   result = @from i in visits begin
      @where i.req_type == type && i.patientID == patient
      @select i.intID
      @collect
   end
   if length(result)== 1
      return first(result)
   end
   if length(result) == 0
       @warn "no visits found of type $type, patient has following types: $(visits |> @filter(_.patientID ==patient) |> @map(_.req_type) |> collect )"
       return -1
   end
   @warn "Multiple visits of same type found"
   return -1
end

"Extracts the solution into an indexed table"
function extractsolution(mp,sets,timeslots,visits)
    plannedappointments = table((pattern = Int64[],patientgroupID = Int64[],patientID = Int64[],visitID = Int64[], resourceID = Int64[], dayID= Int64[], timeslotID = Int64[]);pkey=[:visitID] )
    tempPg = sets.Pg |>@map(copy(_.patients)) |> collect
    for x in getPositiveVariables(mp.lambda)
       patientgroup = first(filter(λ->normalized_coefficient(mp.convexitycons[λ],x)> 0,eachindex(mp.convexitycons)))[1]
       patient = pop!(tempPg[patientgroup])
       for y in eachindex(mp.consref_onepatient)
           if JuMP.normalized_coefficient(mp.consref_onepatient[y],x) > 0
               push!(rows(plannedappointments),(pattern=x.index.value,patientgroupID = patientgroup,patientID = patient,visitID = findvisit(visits,timeslots[y[3]].type,patient), resourceID = y[1],dayID= y[2], timeslotID = y[3]))
           end
       end
    end
    plannedappointments
end

"Used to validate that the solution contain all visits"
function allvisits(visits,plannedappointments)
    pass = true
    novisitsfound = @from i in plannedappointments begin
        @left_outer_join j in visits on i.visitID equals j.intID
        @where j.intID != i.visitID
        @select (i.pattern,i.timeslot)
        @collect
    end
    if length(novisitsfound) > 0
        for i in novisitsfound
            @warn "no corresponding visit found for pattern $(i[1]) timeslot $(i[2])"
        end
        pass = false
    end
    badvisits = @from i in visits begin
        @join j in plannedappointments on i.intID equals j.visitID into k
        @where length(k) != 1
        @select (intID = i.intID,number=length(k))
        @collect
    end
    if length(badvisits) > 0
        toomanyplanned = badvisits |> @filter(_.number > 1) |> @map(_.intID) |> collect
        if length(toomanyplanned) > 0
                @warn "To many planned appointments for visits $(toomanyplanned)"
        end
        unplannedvisits = badvisits |> @filter(_.number ==0 ) |> @map(_.intID) |> collect
        if length(unplannedvisits) > 0
            @warn "No appointments planned for vistis $(unplannedvisits)"
        end
        pass = false
    end
    if pass
        println("test for all visits passed")
    end
    return pass
end

"Used to validate that every visit is in the correct order according to timeDelta"
function correctorder(plannedappointments,timeslots,timeDelta)
    pass = true
    for patient in plannedappointments |> @groupby(_.patientID)|> @map((patientID =key(_), timeslots= map(x-> x.timeslotID,_))) |> collect
        appointmenttimeslots = timeslots |> @filter(_.timeslotID in patient.timeslots) |> collect
        for i in appointmenttimeslots, j in appointmenttimeslots
            if haskey(timeDelta,(i.type,j.type))
                if  j.dayID-i.dayID < timeDelta[i.type,j.type].delta
                    @warn "Patient $(patient.patientID) has visits of type $(i.type) and $(j.type) that should have $(timeDelta[i.type,j.type]) day between them bu have only $(j.dayID-i.dayID)"
                    pass = false
                elseif(j.dayID == i.dayID && i.endTime > j.startTime)
                    @warn "Patient $(patient.patientID) has visits of type $(i.type) and $(j.type) planned on the same day but the one that should be done first ends at $(i.endTime) and the other starts at $(j.startTime)"
                    pass = false
                end
            elseif j.dayID == i.dayID && j.startTime < i.startTime && j.endTime > i.startTime
                pass = false
            end
        end
    end
    if pass
        println("test for correct order passed")
    end
    return pass
end


function deadline()
    pass = true
    if true
        pass = false
        println("deadline not implemented")
    end
    return pass
end

"Used to validate that the objective of the masterproblem is calculated correctly"
function daysused(mp,plannedappointments)
    pass = true
    if sum(plannedappointments |> @groupby(_.patientID) |> @map(length(unique(map(x->x.dayID,_)))) |> collect) != JuMP.objective_value(mp.model)
        pass = false
        println("Mip model objective wrong")
    else
        println("Mip model objective correct")
    end
    return pass
end

"Validates solutions "
function solutionvalidator(mp,sets,timeslots,visits,timeDelta)
    plannedappointments = extractsolution(mp,sets,timeslots,visits)
    pass = true
    pass = pass && allvisits(visits,plannedappointments)
    pass = pass && correctorder(plannedappointments,timeslots,timeDelta)
    pass = pass && daysused(mp,plannedappointments)
    pass = pass && deadline()
end
