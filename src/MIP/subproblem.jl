

#TODO first set up the sets, then group on the different hashes, set a subproblem for each group.
#TODO Add a variable for each patient in the group to master problem.
#TODO a weight for y_j based on how far away from best ord it is.
#TODO maybe dict of hash => subproblem or reverse for storing everything.
function setup_sub!(subproblems,patients::Array{Patient},resources::Array{Resource},subMastercalendar::Dict{Int,Date},TimeDelta)
    for patient in patients
        setup_sub!(subproblems,patient,resources,subMastercalendar,TimeDelta)
    end
end


function setup_sub!(subproblems,patient::Patient,resources::Array{Resource},subMastercalendar::Dict{Int,Date},TimeDelta)
    M1 = 10
    M2 = 10000

    refDate = minimum(subMastercalendar)[2]+Time(0)
    V = (x->x.intID).(patient.treatmentplan)
    D ,D_v = getResource(resources,patient.treatmentplan)
    J = keys(subMastercalendar)
    J_d = Dict(d => getDays(resources[d],subMastercalendar) for d in D)
    I = Dict(d => Dict(j => getTimeSlot(resources[d],j) for j in J) for d in D )
    Ts = Dict(d => Dict(j => Dict(i =>getTSstarttime(resources[d],j,i,refDate) for i in I[d][j]) for j in J_d[d]) for d in D)
    Te = Dict(d => Dict(j => Dict(i =>getTSendtime(resources[d],j,i,refDate) for i in I[d][j]) for j in J_d[d]) for d in D)
    Td = Dict(v1.intID => Dict(v2.intID => getDelta(TimeDelta,v1,v2) for v2 in patient.treatmentplan) for v1 in patient.treatmentplan)
    sets = addsets!(subproblems,patient.intID,V,D,D_v,J,J_d,I,Ts,Te)


    if !haskey(subproblems.pricingproblems,sets.hash)

        sub = Model(with_optimizer(Gurobi.Optimizer,OutputFlag=0))
        @variable(sub,xvars[v in V,d in D_v[v],j in J_d[d],i in I[d][j]],Bin)
        @variable(sub,yvars[j = J],Bin)
        @variable(sub,tvars[d = D,j = J_d[d]])
        @variable(sub,kvars[V,V] , Bin)
        for v1 in V, v2 in V
            if Td[v1][v2][2]
                fix(kvars[v1,v2],1)
            end
        end

        @objective(sub,Min, 0)

            @constraint(sub,lastesttime[d =D ,j = J_d[d],i = I[d][j]],
                sum(xvars[v,d,j,i] for v in V if d in D_v[v] && j in J_d[d] && i in I[d][j]) *Te[d][j][i] <= tvars[d,j])#TODO: somethings wrong here

            @constraint(sub,demand[v in V],
                sum(xvars[v,d,j,i] for d in D_v[v],j in J_d[d],i in I[d][j]) == 1)

            @constraint(sub,openday[j in J],
                sum(xvars[v,d,j,i] for v in V, d in D_v[v], i in I[d][j]) <= M1 * yvars[j] )

            @constraint(sub,beginsBefore[v1 in V, v2 in V ; v1 != v2] ,
                sum(Ts[d][j][i]*xvars[v1,d,j,i] for d in D_v[v1],j in J_d[d],i in I[d][j] )
                - sum(Ts[d][j][i]*xvars[v2,d,j,i] for d in D_v[v2],j in J_d[d],i in I[d][j] )
                <= kvars[v1,v2]*M2)

            @constraint(sub, numberofrelations, sum(kvars[v2,v1] for v1 in V, v2 in V if v1 != v2 ) == length(V)*(length(V)-1)/2)

            @constraint(sub,timebetweenappointments[v1 in V, v2 in V;v1 != v2],
                sum(Ts[d][j][i]*xvars[v1,d,j,i] for d in D_v[v1],j in J_d[d],i in I[d][j] )
                - sum(Te[d][j][i]*xvars[v2,d,j,i] for d in D_v[v2],j in J_d[d],i in I[d][j] )
                >= Td[v1][v2][1]+
                -(1-kvars[v1,v2])*M2)

        addPricingProblem(subproblems,sets.hash,sub,xvars,yvars,tvars,kvars,patient.intID,V,D,D_v,J,J_d,I,Ts,Te)

    else
        push!(subproblems.pricingproblems[sets.hash].patients,patient.intID)
    end


end

function solveSub(sub,xStar)
    @constraint(sub.model,sum(sub.xvars[sol] for sol in xStar) <= length(xStar)-1)
    optimize!(sub.model)
    status = termination_status(sub.model)
    if status != MOI.TerminationStatusCode(1)
        throw("Error: Non optimal sub-problem")
    end
    
    return objective_value(sub.model)
end



function solveSub(sub,phi,pi,kappa)

    @objective(sub.model, Min, sum(1000*sub.yvars[j] for j in sub.J) - sum(sub.tvars[d,j]*phi[d,j] for d in sub.D,j in sub.J_d[d],i in sub.I[d][j] ) - sum(sub.xvars[v,d,j,i] * pi[d,j,i] for v in sub.V, d in sub.D_v[v],j in sub.J_d[d],i in sub.I[d][j])-kappa[sub.patients[1]] )

    #TODO add hamiltonian constraints

    optimize!(sub.model)
    status = termination_status(sub.model)
    if status != MOI.TerminationStatusCode(1)
        throw("Error: Non optimal sub-problem")
    end

    return objective_value(sub.model)
end
