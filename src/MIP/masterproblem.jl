

function setupmaster(subproblems,patients,resources,subMastercalendar)

    env = Gurobi.Env()
    Gurobi.setparams!(env, OutputFlag=0)
    master = Model(with_optimizer(Gurobi.Optimizer,env))
    
    K = length(patients)
    Gp = [sub.intID for sub in values(subproblems.pricingproblems)]

    P_g = Dict(sub.intID => sub.patients for sub in values(subproblems.pricingproblems))

    D = (x->x.intID).(resources)
    J = keys(subMastercalendar)
    J_d = Dict(d => getDays(resources[d],subMastercalendar) for d in D)
    I = Dict(d => Dict(j => getTimeSlot(resources[d],j) for j in J) for d in D )

    @variable(master,lambda[1:K] >= 0) #TODO make integer at relax

    @variable(master,closingtime[d in D, j in J_d[d]] >= 0)
    for d in D, j in J_d[d]
        set_lower_bound(closingtime[d,j],getTlowerbound(resources[d],j))
    end


    @objective(master, Min, sum(closingtime[d,j] for d in D, j in J_d[d]) + sum(1000000*lambda[m] for m in 1:K))

    @constraint(master,consref_offtime[d in D, j in J_d[d]], sum(lambda[m]*1000 for m in 1:K) <= closingtime[d,j]) #TODO Only for consultations

    @constraint(master,convexitycons[g in Gp],
       sum(lambda[m] for m in 1:K if m in P_g[g]) == length(P_g[g]) )


    @constraint(master,consref_onepatient[ d in D, j in J_d[d], i in I[d][j]],
        0 <=1 )


    return Masterproblem(master,consref_offtime,consref_onepatient,convexitycons,lambda,closingtime,I,env)
    # return consref_offtime, consref_onepatient, convexitycons,lambda,closingtime
end
"Return the sum of the maximal path that of visits that visit x must preceed"
function sumpath(Tdelta,x)
    sum = []
    for y in filter(t->t[2][2]==true ,Tdelta[x])
        push!(sum,y[2][1]+sumpath(Tdelta,y[1]))
    end
    if length(sum)> 0
        return maximum(sum)
    else
        return 0
    end
end

function visit(v,temp,perm,Tdelta,L)
    if v in perm
        return
    end
    v in temp ? error("Delta graph is not a DAG") :
    push!(temp,v)
    for v2 in filter(x-> x[2][2]==true, Tdelta[v])
        visit(v2[1],temp,perm,Tdelta,L)
    end
    filter!(x->x!= v ,temp)
    push!(perm,v)
    prepend!(L,v)
    l = 1
    while l < length(L)
        Tdelta[v][L[l+1]][2] == true ?  break : l += 1
    end
    if l < length(L) && l > 1
        L[1:l] = sort!(L[1:l] ,by = x-> sumpath(Tdelta,x),rev= true)
    end
end

function sortvisit(V_input,Tdelta)
    L = Int64[]; temp = Int64[]; perm = Int64[]
    V = copy(V_input)
    while length(V) > 0
        visit(pop!(V),temp,perm,Tdelta,L)
    end
    return L
end


function generateInitialColumns!(masterproblem::Masterproblem,subproblems::Subproblems)

    g = SimpleGraph()

    for sub in subproblems.pricingproblems
        Vsorted = sortvisit(sub.V)
        for patient in sub.patients

                for d in sub.D_v[Vsorted[1]]
                 for J in sort(sub.J_d, by = x ->x[1])
                     for i in I[d][j]

                     end
                 end
                end
            vend
            if length(Vsorted)> 2
                for v in Vsorted[2:end-1]


                end
            end
        end
    end
end





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

function addcolumntomaster!(masterproblem::Masterproblem,pricingproblem::PricingProblem,iteration::Int64,EPSVALUE)
        if objective_value(pricingproblem.model) < -EPSVALUE
            println("Subproblem objective value = $(JuMP.objective_value(pricingproblem.model))")
            addcolumntomaster!(masterproblem,pricingproblem,iteration)
            return false
        end
    return true
end


function addcolumntomaster!(masterproblem::Masterproblem,pricingproblem::PricingProblem,iteration::Int64)

    touchedconstraints = ConstraintRef[]
    constraint_coefficients = Float64[]
    #
    # mptemp = zeros(length(P))
    # mptemp[patient] = 1
    # Atemp = zeros(length(P),length(DR),length(I),length(J))
    # ttemp = zeros(length(DR),length(I),length(J))
    # TODO Use the filter function for this
    for t in getIndexofPositiveVariables(pricingproblem.tvars)
        # if tvalues[j,d] == xtimes[i,j,d]
            #TODO they are all choosing same day, why is this
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
    JuMP.set_objective_coefficient(masterproblem.model,masterproblem.lambda[end],1000*sum(value.(pricingproblem.yvars)))
    JuMP.set_normalized_coefficient.(touchedconstraints,masterproblem.lambda[end],constraint_coefficients)


end
