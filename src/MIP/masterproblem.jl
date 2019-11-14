

function setupmaster(patients,resources,subMastercalendar)


    master = Model(with_optimizer(Gurobi.Optimizer,OutputFlag=1))

    K = length(patients)

    P = (x->x.intID).(patients)
    D = (x->x.intID).(resources)
    J = keys(subMastercalendar)
    J_d = Dict(d => getDays(resources[d],subMastercalendar) for d in D)
    I = Dict(d => Dict(j => getTimeSlot(resources[d],j) for j in J) for d in D )
    @variable(master,lambda[1:K] >= 0)

    @variable(master,closingtime[d in D, j in J_d[d]] >= 0)

    @objective(master, Min, sum(closingtime[d,j] for d in D, j in J_d[d]) + sum(100000*lambda[m] for p in P, m in 1:K))

    @constraint(master,consref_offtime[d in D, j in J_d[d] ,i in I[d][j]], sum(lambda[m]*10000 for m in 1:K) <= closingtime[d,j])

    @constraint(master,convexitycons[p in P],
       sum(lambda[m] for m in 1:K if m == p) == 1 )

    println("test1")
    @constraint(master,consref_onepatient[ d in D, j in J_d[d], i in I[d][j]],
        sum(lambda[m]*0 for p in P, m in 1:K) <=1 )
        println("test2")

    return Masterproblem(master,consref_offtime,consref_onepatient,convexitycons,lambda,closingtime)
    # return consref_offtime, consref_onepatient, convexitycons,lambda,closingtime
end


function addcolumntomaster(masterproblem::Masterproblem,yvalues,xvalues,tvalues,patient,param,iteration,plandata,srproblem)
    P, I, J, D, R, DR, w1,w2,activities,M,timeofday = get(param)
    touchedconstraints = ConstraintRef[]
    constraint_coefficients = Float64[]

    mptemp = zeros(length(P))
    mptemp[patient] = 1
    Atemp = zeros(length(P),length(DR),length(I),length(J))
    ttemp = zeros(length(DR),length(I),length(J))

    for i in I, j in J, d in D
        # if tvalues[j,d] == xtimes[i,j,d]
        if xvalues[i,j,d] != 0
            push!(touchedconstraints,masterproblem.consref_offtime[i,j,d])
            push!(constraint_coefficients,tvalues[j,d])
            ttemp[d,i,j] = tvalues[j,d]
        end
    end
    for i in I, j in J, d in DR
        if xvalues[i,j,d] != 0
            push!(touchedconstraints,masterproblem.consref_onepatient[i,j,d])
            push!(constraint_coefficients,1)
            Atemp[patient,d,i,j] = 1
        end
    end

    push!(touchedconstraints,masterproblem.convexitycons[patient])
    push!(constraint_coefficients,1)

    push!(masterproblem.lambda,@variable(
        masterproblem.model,
        lower_bound = 0,
        base_name = "lambda_new[$(patient),$(iteration)]" ,
        # objective = sum(yvalues)*w2[patient],
        #inconstraints= touchedconstraints,
        #coefficients = constraint_coefficients
    ))
JuMP.set_objective_coefficient(masterproblem.model,masterproblem.lambda[end],sum(yvalues)*w2[patient])
JuMP.set_coefficient.(touchedconstraints,masterproblem.lambda[end],constraint_coefficients)


    addplan(plandata,Atemp,ttemp,sum(yvalues)*w2[patient],mptemp)

end
