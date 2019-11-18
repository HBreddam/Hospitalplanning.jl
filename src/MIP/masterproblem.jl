

function setupmaster(patients,resources,subMastercalendar)


    master = Model(with_optimizer(Gurobi.Optimizer,OutputFlag=0))

    K = length(patients)

    P = (x->x.intID).(patients)
    D = (x->x.intID).(resources)
    J = keys(subMastercalendar)
    J_d = Dict(d => getDays(resources[d],subMastercalendar) for d in D)
    I = Dict(d => Dict(j => getTimeSlot(resources[d],j) for j in J) for d in D )
    @variable(master,lambda[1:K] >= 0) #TODO make integer at relax

    @variable(master,closingtime[d in D, j in J_d[d]] >= 0)

    @objective(master, Min, sum(closingtime[d,j]/1000 for d in D, j in J_d[d]) + sum(1000*lambda[m] for p in P, m in 1:K))

    @constraint(master,consref_offtime[d in D, j in J_d[d]], sum(lambda[m]*1000 for m in 1:K) <= closingtime[d,j])

    @constraint(master,convexitycons[p in P],
       sum(lambda[m] for m in 1:K if m == p) == 1 )


    @constraint(master,consref_onepatient[ d in D, j in J_d[d], i in I[d][j]],
        sum(lambda[m]*0 for p in P, m in 1:K) <=1 )


    return Masterproblem(master,consref_offtime,consref_onepatient,convexitycons,lambda,closingtime)
    # return consref_offtime, consref_onepatient, convexitycons,lambda,closingtime
end

function addcolumntomaster(masterproblem::Masterproblem,subproblems::Dict{Int64,Subproblem},iteration::Int64)
    for sub in values(subproblems)
        if objective_value(sub.model) < 0
            println("Adding column for patient $(sub.patient)")
            addcolumntomaster(masterproblem,sub,iteration)
        end

    end
end

function addcolumntomaster(masterproblem::Masterproblem,subproblem::Subproblem,iteration::Int64)

    touchedconstraints = ConstraintRef[]
    constraint_coefficients = Float64[]
    #
    # mptemp = zeros(length(P))
    # mptemp[patient] = 1
    # Atemp = zeros(length(P),length(DR),length(I),length(J))
    # ttemp = zeros(length(DR),length(I),length(J))
    # TODO Use the filter function for this
    for t in getIndexofPositiveVariables(subproblem.tvars)
        # if tvalues[j,d] == xtimes[i,j,d]
            #TODO they are all choosing same day, why is this
            push!(touchedconstraints,masterproblem.consref_offtime[t])
            push!(constraint_coefficients,value(subproblem.tvars[t]))
    end
    for x in getIndexofPositiveVariables(subproblem.xvars)
        println(x)
        push!(touchedconstraints,masterproblem.consref_onepatient[x[2:end]])
        push!(constraint_coefficients,1)
    end

    push!(touchedconstraints,masterproblem.convexitycons[subproblem.patient])
    push!(constraint_coefficients,1)

    push!(masterproblem.lambda,@variable(
        masterproblem.model,
        lower_bound = 0,
        base_name = "lambda_new[$(subproblem.patient),$(iteration)]_$(length(masterproblem.lambda))" ,

    ))
    JuMP.set_objective_coefficient(masterproblem.model,masterproblem.lambda[end],sum(value.(subproblem.yvars)))
    JuMP.set_coefficient.(touchedconstraints,masterproblem.lambda[end],constraint_coefficients)


end
