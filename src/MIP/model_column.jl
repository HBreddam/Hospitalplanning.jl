
EPSVALUE = 0.01


function columngeneration(patients,resources,mastercalendar,timeDelta)
    subproblems = Subproblems()

    setup_sub!(subproblems,patients,resources,mastercalendar,timeDelta) #TODO: should be sub mastercalendar

    mp = setupmaster(patients,resources,mastercalendar)

    iteration = 0
    done = false
    while !done
        iteration +=1

        optimize!(mp.model)
        done = true
        status = termination_status(mp.model)
        if status != MOI.TerminationStatusCode(1)
            throw("Error: Non optimal masterproblem")
        end

        phi = dual.(mp.consref_offtime)
        pie = dual.(mp.consref_onepatient)
        kappa = dual.(mp.convexitycons)


        for sub in values(subproblems.pricingproblems)

            solveSub(sub,phi,pie,kappa)

            done2 = addcolumntomaster!(mp,sub,iteration,EPSVALUE) #TODO add patient info
            done &= done2
            count = 0
            while !done2 && count < 0
                count += 1
                solveSub(sub,getIndexofPositiveVariables(sub.xvars)) #TODO time this
                done2 = addcolumntomaster!(mp,sub,iteration,EPSVALUE)
            end


            #TODO Save values at check if convergence seem to be correct!
        end


    end


    #TODO group the patients if they are alike
    println("LP objective value = $(JuMP.objective_value(mp.model))")
    set_integer.(mp.lambda)
    optimize!(mp.model)
    println("MIP objective value = $(JuMP.objective_value(mp.model))")

    return mp, subproblems
end
