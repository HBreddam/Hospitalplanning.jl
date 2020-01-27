
EPSVALUE = 0.1


function columngeneration(patients, visits, resources, timeslots, mastercalendar, timeDelta, setuponly = false)
    timeslotsNDSparse = ndsparse(timeslots)
    subproblems = Subproblems()
    sets = Sets()
    sets.Vp = buildVp(visits)
    sets.Dv = buildDv(resources,visits)
    sets.Dp = buildDp(resources,visits)
    sets.J = keys(mastercalendar)
    sets.Jd = buildJd(timeslots,mastercalendar)
    sets.I = buildI(timeslots)
    sets.Pg = buildPg(patients,visits,sets.Vp)

    setup_sub!(subproblems,patients,visits,resources,timeslotsNDSparse,mastercalendar,timeDelta,sets,1)

    mp = setupmaster(subproblems,patients,resources,timeslots,mastercalendar,sets)
    #generateInitialColumns(mp,subproblems)
    if setuponly
        return mp, subproblems
    end
    iteration = 0
    done = false
    while !done
        iteration +=1
        println(iteration)
        optimize!(mp.model)
        println("Master objective value = $(JuMP.objective_value(mp.model))")
        println.(getPositiveVariables(mp.lambda))
        done = true
        status = termination_status(mp.model)
        if status != MOI.TerminationStatusCode(1)
            throw("Error: Non optimal masterproblem")
        end

        ϕ = dual.(mp.consref_offtime)
        θ = dual.(mp.consref_onepatient)
        κ = dual.(mp.convexitycons)

        subthreads = []

        for sub in values(subproblems.pricingproblems)

            push!(subthreads,Threads.@spawn solveSub!(sub,ϕ,θ,κ))
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
        for thread in subthreads
            wait(thread)
        end
        done = addcolumntomaster!(mp,subproblems,iteration,EPSVALUE)

    end


    #TODO group the patients if they are alike
    println("LP objective value = $(JuMP.objective_value(mp.model))")
    Gurobi.setparams!(mp.env, OutputFlag=1,TimeLimit=600)
    set_integer.(mp.lambda)
    optimize!(mp.model)
    println("MIP objective value = $(JuMP.objective_value(mp.model))")

    return mp, subproblems
end
