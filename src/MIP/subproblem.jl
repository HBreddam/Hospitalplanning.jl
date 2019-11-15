
function setup_sub!(subproblems,patient::Patient,resources::Array{Resource},subMastercalendar::Dict{Int,Date})
    M1 = 10
    M2 = 10000
    sub = Model(with_optimizer(Gurobi.Optimizer,OutputFlag=1))
    refDate = minimum(subMastercalendar)[2]+Time(0)
    V = (x->x.intID).(patient.treatmentplan)
    D ,D_v = getResource(resources,patient.treatmentplan)
    J = keys(subMastercalendar)
    J_d = Dict(d => getDays(resources[d],subMastercalendar) for d in D)
    I = Dict(d => Dict(j => getTimeSlot(resources[d],j) for j in J) for d in D )
    Ts = Dict(d => Dict(j => Dict(i =>getTSstarttime(resources[d],j,i,refDate) for i in I[d][j]) for j in J_d[d]) for d in D)
    Te = Dict(d => Dict(j => Dict(i =>getTSendtime(resources[d],j,i,refDate) for i in I[d][j]) for j in J_d[d]) for d in D)

    #endtime = Dict(d => Dict(j => Dict( for i in I[d][j]) for j in J[d]) for d in D )
    @variable(sub,xvars[v in V,d in D_v[v],j in J_d[d],i in I[d][j]],Bin)
    @variable(sub,yvars[j = J],Bin)
    @variable(sub,tvars[d = D,j = J_d[d]])
    @variable(sub,kvars[V,V], Bin)
    @objective(sub,Min, rand()*sum(xvars[v,d,j,i] for v in V,  d in D_v[v],j in J_d[d],i in I[d][j]))

        @constraint(sub,lastesttime[d =D ,j = J_d[d],i = I[d][j]],
            sum(xvars[v,d,j,i] for v in V if d in D_v[v] && j in J_d[d] && i in I[d][j]) *getTSendtime(resources[d],j,i) <= tvars[d,j])#TODO: somethings wrong here

        @constraint(sub,demand[v in V],
            sum(xvars[v,d,j,i] for d in D_v[v],j in J_d[d],i in I[d][j]) == 1)

        @constraint(sub,openday[j in J],
            sum(xvars[v,d,j,i] for v in V, d in D_v[v], i in I[d][j]) <= M1 * yvars[j] )

        @constraint(sub,beginsBefore[v1 in V, v2 in V ; v1 != v2] ,
            sum(Ts[d][j][i]*xvars[v1,d,j,i] for d in D_v[v1],j in J_d[d],i in I[d][j] )
            - sum(Ts[d][j][i]*xvars[v2,d,j,i] for d in D_v[v2],j in J_d[d],i in I[d][j] )
            <= kvars[v2,v1]*M2)

        @constraint(sub, numberofrelations, sum(kvars[v2,v1] for v1 in V, v2 in V if v1 != v2 ) == length(V)*(length(V)-1)/2)

        @constraint(sub,timebetweenappointments[v1 in V, v2 in V;v1 != v2],
            sum(Ts[d][j][i]*xvars[v1,d,j,i] for d in D_v[v1],j in J_d[d],i in I[d][j] )
            - sum(Te[d][j][i]*xvars[v2,d,j,i] for d in D_v[v2],j in J_d[d],i in I[d][j] )
            >= getTdelta(v1,v2)+
            -(1-kvars[v2,v1])*M2)


    addsubproblem(subproblems,patient.intID,sub,xvars,yvars,tvars,kvars,V,D,D_v,J,J_d,I,Ts,Te)
end




function solveSub(sub,phi,pi,kappa,patient)



    @objective(sub.model, Min, sum(1000*sub.yvars[j] for j in sub.J) - sum(sub.tvars[d,j]*phi[d,j] for d in sub.D,j in sub.J_d[d],i in sub.I[d][j] ) - sum(sub.xvars[v,d,j,i] * pi[d,j,i] for v in sub.V, d in sub.D_v[v],j in sub.J_d[d],i in sub.I[d][j])-kappa[patient] )
#TODO: Change the weight

    optimize!(sub.model)
    status = termination_status(sub.model)
    if status != MOI.TerminationStatusCode(1)
        throw("Error: Non optimal sub-problem")
    end

    return objective_value(sub.model)
end
