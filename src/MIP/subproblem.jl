

#TODO first set up the sets, then group on the different hashes, set a subproblem for each group.
#TODO Add a variable for each patient in the group to master problem.
#TODO a weight for y_j based on how far away from best ord it is.
#TODO maybe dict of hash => subproblem or reverse for storing everything.

function setup_sub!(subproblems,patients::Array{Patient},resources::Array{Resource},mastercalendar::Dict{Int,Date},TimeDelta,months)
    for patient in patients

        #TODO length of min treatment time should be calculated and used.


        setup_sub!(subproblems,patient,resources,mastercalendar,TimeDelta,months)
    end
end
startofyear(date::Date) = Date(Year(date))
endofyear(date::Date) = Date(Year(date),Month(12),Day(31))
endofmonth(date::Date) = date + Month(1)-Day(date+Month(1))
startofmonth(date::Date) = date-Day(date)+Day(1)

function setup_sub!(subproblems,patient::Patient,resources::Array{Resource},mastercalendar::Dict{Int,Date},TimeDelta,months)
    M1 = 10
    M2 = 1000


    Tdelta = Dict(v1.intID => Dict(v2.intID => getDelta(TimeDelta,v1,v2) for v2 in patient.treatmentplan) for v1 in patient.treatmentplan)
    V = sortvisit((x->x.intID).(patient.treatmentplan),Tdelta)
    bestordmin = sort(patient.treatmentplan, by = x -> x.bestord[1])[1].bestord[2]
    bestordmax = sort(patient.treatmentplan, by = x -> x.bestord[1])[1].bestord[2]
    maxwait = sumpath(Tdelta,V[1])

    startdate = max(minimum(mastercalendar)[2],min(startofmonth(maximum(mastercalendar)[2]-Month(months)),startofmonth(bestordmin)-Month(div(months,2))))
    enddate = startdate + Month(months)-Day(1)
    subMastercalendar = MasterCalendar(mastercalendar,startdate,enddate)


    D ,D_v = getResource(resources,patient.treatmentplan)
    J = keys(subMastercalendar)
    J_d = Dict(d => getDays(resources[d],subMastercalendar) for d in D)
    I = Dict(d => Dict(j => getTimeSlot(resources[d],j) for j in J) for d in D )
    Ts = Dict(d => Dict(j => Dict(i =>getTSstarttime(resources[d],j,i) for i in I[d][j]) for j in J_d[d]) for d in D)
    Te = Dict(d => Dict(j => Dict(i =>getTSendtime(resources[d],j,i) for i in I[d][j]) for j in J_d[d]) for d in D)
    Tdelta = Dict(v1.intID => Dict(v2.intID => getDelta(TimeDelta,v1,v2) for v2 in patient.treatmentplan) for v1 in patient.treatmentplan)

    sets = addsets!(subproblems,patient.intID,V,D,D_v,J,J_d,I,Ts,Te)


    if !haskey(subproblems.pricingproblems,sets.hash)
        sub = Model(with_optimizer(Gurobi.Optimizer,OutputFlag=0))
        @variable(sub,xvars[v in V,d in D_v[v],j in J_d[d],i in I[d][j]],Bin)
        @variable(sub,yvars[j = J],Bin)
        @variable(sub,tvars[d = D,j = J_d[d]])  #TODO Only for consultations
        @variable(sub,kvars[V,V] , Bin)
        @variable(sub,gvars[V,V] , Bin)
        for v1 in V, v2 in V
            if Tdelta[v1][v2][2]
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

            @constraint(sub,sameday[v1 in V, v2 in V,j in J; v1 != v2 ],
                    sum(xvars[v1,d,j2,i] for d in D_v[v1],j2 in J_d[d], i in I[d][j2] if j2 == j)+sum(xvars[v2,d,j2,i] for d in D_v[v2],j2 in J_d[d], i in I[d][j2] if j2 == j) <= gvars[v1,v2]+ 1 )


            @constraint(sub,beginsBefore[v1 in V, v2 in V,j in J; v1 != v2] ,
                -sum(Ts[d][j2][i]*xvars[v2,d,j2,i] for d in D_v[v2],j2 in J_d[d],i in I[d][j2] if j2 == j )
                + sum(Te[d][j2][i]*xvars[v1,d,j2,i] for d in D_v[v1],j2 in J_d[d],i in I[d][j2] if j2 == j)
                <=  (1-gvars[v1,v2])*M2+(1-kvars[v1,v2])*M2)

            @constraint(sub, numberofrelations, sum(kvars[v2,v1] for v1 in V, v2 in V if v1 != v2 ) == length(V)*(length(V)-1)/2)

            @constraint(sub,timebetweenappointments[v1 in V, v2 in V;v1 != v2 ],
                sum(j*xvars[v2,d,j,i] for d in D_v[v2],j in J_d[d],i in I[d][j] )
                - sum(j*xvars[v1,d,j,i] for d in D_v[v1],j in J_d[d],i in I[d][j] )
                >= Tdelta[v1][v2][1]
                -(1-kvars[v1,v2])*M2)

        addPricingProblem(subproblems,sets.hash,sub,xvars,yvars,tvars,kvars,gvars,patient.intID,V,D,D_v,J,J_d,I,Ts,Te,Tdelta)

    else
        push!(subproblems.pricingproblems[sets.hash].patients,patient.intID)
    end

end

function solveSub!(sub,xStar)
    @constraint(sub.model,sum(sub.xvars[sol] for sol in xStar) <= length(xStar)-1)
    optimize!(sub.model)
    status = termination_status(sub.model)
    if status != MOI.TerminationStatusCode(1)
        throw("Error: Non optimal sub-problem")
    end

    return objective_value(sub.model)
end



function solveSub!(sub,phi,pi,kappa)

    @objective(sub.model, Min, sum(1000*sub.yvars[j] for j in sub.J) - sum(sub.tvars[d,j]*phi[d,j] for d in sub.D,j in sub.J_d[d],i in sub.I[d][j] ) - sum(sub.xvars[v,d,j,i] * pi[d,j,i] for v in sub.V, d in sub.D_v[v],j in sub.J_d[d],i in sub.I[d][j])-kappa[sub.intID] ) #TODO Kappa times number of patients in group

    optimize!(sub.model)
    status = termination_status(sub.model)
    if status != MOI.TerminationStatusCode(1)
        println("$(minimum(sub.J)) - $(maximum(sub.J))")
        throw("Error: Non optimal sub-problem for subproblem $(sub.intID)")

        #TODO Throw warning and extend search area
    end

    return objective_value(sub.model)
end
