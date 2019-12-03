
EPSVALUE = 0.1


function columngeneration(patients,resources,mastercalendar,timeDelta,setuponly = false)
    subproblems = Subproblems()

    setup_sub!(subproblems,patients,resources,mastercalendar,timeDelta,3)

    mp = setupmaster(subproblems,patients,resources,mastercalendar)
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

        phi = dual.(mp.consref_offtime)
        pie = dual.(mp.consref_onepatient)
        kappa = dual.(mp.convexitycons)
        println(kappa[1])
        subthreads = []

            for sub in values(subproblems.pricingproblems)

                push!(subthreads,Threads.@spawn solveSub!(sub,phi,pie,kappa))
                # solveSub!(sub,phi,pie,kappa)
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
