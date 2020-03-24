
"Sets up the master problem"
function setupmaster(subproblems,patients,resources,timeslots,subMastercalendar,sets)
    env = Gurobi.Env()
    Gurobi.setparams!(env, OutputFlag=0)
    master = Model(with_optimizer(Gurobi.Optimizer,env))

    K = length(patients)
    Pg = sets.Pg
    Gp = [i for i in 1:length(Pg)]
    D = JuliaDB.select(resources,:intID)
    J = keys(subMastercalendar)
    Jd = sets.Jd
    I = sets.I

    @variable(master,lambda[1:K] >= 0)
    #@variable(master,closingtime[d in D, j in Jd[d].j] >= 0)
    # for d in D, j in Jd[d].j
    #     set_lower_bound(closingtime[d,j],getTlowerbound(timeslots,d,j))
    # end


    #@objective(master, Min, sum(closingtime[d,j] for d in D, j in Jd[d].j) + sum(1000000*lambda[m] for m in 1:K))
    @objective(master, Min, sum(1000000*lambda[m] for m in 1:K))
    #@constraint(master,consref_offtime[d in D, j in Jd[d].j], sum(lambda[m]*1000 for m in 1:K) <= closingtime[d,j]) #TODO Only for consultations

    @constraint(master,convexitycons[g in Gp],
       sum(lambda[m] for m in 1:K if m in Pg[g].patients) == length(Pg[g].patients) )


    @constraint(master,consref_onepatient[ d in D, j in Jd[d].j, i in I[d,j].i],
        0 <=1 )

    return Masterproblem(master,[],consref_onepatient,convexitycons,lambda,[],I,env)
    #return Masterproblem(master,consref_offtime,consref_onepatient,convexitycons,lambda,closingtime,I,env)

end
"Return the sum of the maximal path of visits that visit x must preceed"
function sumpath(Tdelta,x)
    sum = []
    for y in (Tdelta |> @filter(_.visit1 == x) |> @map(_.visit2) |> collect)
        push!(sum,Tdelta[x,y].delta+sumpath(Tdelta,y))
    end
    if length(sum)> 0
        return maximum(sum)
    else
        return 0
    end
end



"Sorts visits in in the scheduling order for the heuristic"
function sortvisit(V_input,Tdelta_input)
    V = copy(V_input)
    result = []
    Tdelta = Tdelta_input |> @filter(_.visit1 in V_input && _.visit2 in V_input) |> NDSparse
    curr = "Consultation"
    V = filter!(x-> x != curr,V)
    push!(result,curr)
    while length(V)>0
        temp = Tdelta |> @filter(_.visit1 in V && _.visit2 in result) |> @orderby_descending(sumpath(Tdelta,_.visit1))|> @map(_.visit1)|> collect
        if length(temp)> 0
            curr = first(temp)
        else
            curr = rand(V)
        end
        while true
            temp2 = Tdelta[curr,:] |> @filter(!(_.visit2 in result))|> @orderby_descending(sumpath(Tdelta,_.visit2))|> @map(_.visit2)|> collect
            if length(temp2)> 0
                curr = first(temp2)
            else
                break
            end
        end
        push!(result,curr)
        V = filter!(x-> x != curr,V)
    end
    result
end
"used to check if a timeslot on dayID, with startTime and endTime is feasible with the current already plannedslots for the patient, such that there are no overlap and the visit order given in timedelta is kept."
function isfree(plannedslots,timeDelta,type,dayID,startTime,endTime)
    for p in plannedslots
        if p.dayID == dayID && ((startTime< p.endTime && endTime > p.startTime) || (haskey(timeDelta,(type,p.type)) && endTime > p.startTime))
            return false
        end
    end
    true
end

"Checks if the day with dayID, is already used in the plan, such that the patient is already at hospital"
function daystoopen(plannedslots,dayID)
    if dayID in (x->x.dayID).(plannedslots)
        return 0
    else
        return 1
    end
end
"Calculates the latest day that a visit of the type 'type' can be scheduled according to the data of timeDelta"
function lastestday(plannedslots,timeDelta,type)
    if length(plannedslots) > 0
        x = (x-> x.dayID -get(timeDelta,(type,x.type),(delta = -1,)).delta).(plannedslots)
        return minimum(x)
    end
    return 100000
end


"Builds schedule using a greedy heuristic. For each type of visit (in sorted order), the algorithm places the last one and then plans the most constrained visit (according to the already planned visits) next, until all visits are planned."
function buildschedule(timeslots,appointments,types, timeDelta)
    plannedslots = []
    for type in types
        latest = lastestday(plannedslots,timeDelta,type)
        x = @from i in timeslots begin
            @where i.type == type && i.dayID <= latest && isfree(plannedslots,timeDelta,i.type,i.dayID,i.startTime,i.endTime)#TODO her mangler vi at tjekke for starttid
            @left_outer_join j in appointments on i.timeslotID equals j.timeslotID
            @where i.timeslotID != j.timeslotID
            @orderby daystoopen(plannedslots,i.dayID), descending(i.dayID)
            @select a=i.timeslotID
            @collect
        end
        length(x) == 0 && return []
        y = first(x)
        push!(plannedslots,timeslots[y])
    end
    return plannedslots
end

"Generates initial columns for the masterproblem using the buildschedule greedy heuristic that ensures that no columns overlap."
function generateInitialColumns!(masterproblem::Masterproblem,sets,timeslots,timeDelta)

    appointments = table((timeslots |> @filter(_.booked) |> @map((timeslotID = _.timeslotID ,resourceID=_.resourceID ,visitID= 0)) |> collect);pkey=[:timeslotID])
    while true
        done = true
        for group in 1:length(sets.Pg)
            types = sets.Pg[group].types
            for patient in sets.Pg[group].patients
                plannedslots = buildschedule(timeslots,appointments,types,timeDelta)
                if length(plannedslots)> 0
                    done = false
                    appointments = append!(rows(appointments),(timeslotID = (x->x.timeslotID).(plannedslots),resourceID = (x->x.resourceID).(plannedslots),visitID  =-1 ))
                    addcolumntomaster!(masterproblem,plannedslots,group,0)
                end
            end
        end
        done && break

    end
end




"adds columns from suproblems that have objective value beloew -EPSVALUE"
function addcolumntomaster!(masterproblem::Masterproblem,subproblems::Subproblems,iteration::Int64,EPSVALUE)
    done = true
    for sub in values(subproblems.pricingproblems)
        if objective_value(sub.model) < -EPSVALUE
            println("Subproblem objective value = $(JuMP.objective_value(sub.model))")
            addcolumntomaster!(masterproblem,sub,iteration)
            done = false
        end
    end
    return done
end

"adds column from a single pricingproblems if the objective is below -EPSVALUE"
function addcolumntomaster!(masterproblem::Masterproblem,pricingproblem::PricingProblem,iteration::Int64,EPSVALUE)
        if objective_value(pricingproblem.model) < -EPSVALUE
            println("Subproblem objective value = $(JuMP.objective_value(pricingproblem.model))")
            addcolumntomaster!(masterproblem,pricingproblem,iteration)
            return false
        end
    return true
end

"adds column from a single pricingproblems"
function addcolumntomaster!(masterproblem::Masterproblem,pricingproblem::PricingProblem,iteration::Int64)

    touchedconstraints = ConstraintRef[]
    constraint_coefficients = Float64[]


    for t in getIndexofPositiveVariables(pricingproblem.tvars)

            push!(touchedconstraints,masterproblem.consref_offtime[t])
            push!(constraint_coefficients,value(pricingproblem.tvars[t]))
    end
    for x in getIndexofPositiveVariables(pricingproblem.xvars)

        push!(touchedconstraints,masterproblem.consref_onepatient[x[2:end]])
        push!(constraint_coefficients,1)
    end

    push!(touchedconstraints,masterproblem.convexitycons[pricingproblem.intID])
    push!(constraint_coefficients,1)

    push!(masterproblem.lambda,@variable(
        masterproblem.model,
        lower_bound = 0,
        base_name = "lambda_new[$(pricingproblem.intID),$(iteration)]_$(length(masterproblem.lambda))" ,

    ))
    JuMP.set_objective_coefficient(masterproblem.model,masterproblem.lambda[end],sum(value.(pricingproblem.yvars)))
    JuMP.set_normalized_coefficient.(touchedconstraints,masterproblem.lambda[end],constraint_coefficients)
end

"Adds column to master problem that uses the timeslots given in 'timeslots' for a patientgroup. Used to add columns from Heuristic"
function addcolumntomaster!(masterproblem::Masterproblem,timeslots,patientgroup::Int64,iteration)
    touchedconstraints = ConstraintRef[]
    constraint_coefficients = Float64[]
    for timeslot in timeslots
        d = timeslot.resourceID
        j = timeslot.dayID
        i = timeslot.timeslotID
        push!(touchedconstraints,masterproblem.consref_onepatient[d,j,i])
        push!(constraint_coefficients,1)
    end
    push!(touchedconstraints,masterproblem.convexitycons[patientgroup])
    push!(constraint_coefficients,1)

    push!(masterproblem.lambda,@variable(
        masterproblem.model,
        lower_bound = 0,
        base_name = "lambda_[$(patientgroup),$(iteration)]_$(length(masterproblem.lambda))" ,

    ))
    columnprice = float(length(timeslots|> @groupby(_.dayID) |> collect))

    JuMP.set_objective_coefficient(masterproblem.model,masterproblem.lambda[end],columnprice)
    JuMP.set_normalized_coefficient.(touchedconstraints,masterproblem.lambda[end],constraint_coefficients)
end
