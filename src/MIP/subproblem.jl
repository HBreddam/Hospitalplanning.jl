



#TODO a weight for y_j based on how far away from best ord it is.


function setup_sub!(subproblems,patients::IndexedTable,visits,resources::IndexedTable,timeslots,mastercalendar::Dict{Int,Date},TimeDelta,sets,months)


    for patientgroup in [i for i in 1:length(sets.Pg)]

        #TODO length of min treatment time should be calculated and used.


        setup_sub!(subproblems,patientgroup,visits,resources,timeslots,mastercalendar,TimeDelta,sets,months)
    end
end
startofyear(date::Date) = Date(Year(date))
endofyear(date::Date) = Date(Year(date),Month(12),Day(31))
endofmonth(date::Date) = date + Month(1)-Day(date+Month(1))
startofmonth(date::Date) = date-Day(date)+Day(1)

function getTimeDelta(timeDelta,visits,v1,v2)
    k = (visits[v1].req_type,visits[v2].req_type)
    if haskey(timeDelta,k)
        timeDelta[k[1],k[2]].delta
    else
        -1
    end
end


function setup_sub!(subproblems,patientgroup::Int64,visits,resources::IndexedTable,timeslots,mastercalendar::Dict{Int,Date},timeDelta,sets,months)
    M1 = 10
    M2 = 1000

    Td(v1,v2) = getTimeDelta(timeDelta,visits,v1,v2)
    p = sets.Pg[patientgroup].patients[1]
    V = sets.Vp[p].v; Dv = sets.Dv; J = sets.J ;Jd = sets.Jd; I = sets.I
    Ts(d,j,i) = Dates.value(timeslots[d,j,i].startTime)/60000000000
    Te(d,j,i) = Dates.value(timeslots[d,j,i].endTime)/60000000000

    (bestordmin,bestordmax) = reduce((min,max),visits[V],select=:bestord)
    startdate = max(minimum(mastercalendar)[2],min(startofmonth(maximum(mastercalendar)[2]-Month(months)),startofmonth(bestordmin[2])-Month(div(months,2))))
    enddate = startdate + Month(months)-Day(1)
    subMastercalendar = MasterCalendar(mastercalendar,startdate,enddate)
    if p== 6
        println("V = $V")
        for v in V
            println(Dv[v].d)
        end
    end

        sub = Model(with_optimizer(Gurobi.Optimizer,OutputFlag=0))
        @variable(sub,xvars[v in V,d in Dv[v].d,j in Jd[d].j,i in I[d,j].i],Bin)
        @variable(sub,yvars[j = J],Bin)
        #@variable(sub,tvars[d = D,j = Jd[d].j])  #TODO Only for consultations
        @variable(sub,kvars[V,V], Bin)
        @variable(sub,gvars[V,V], Bin)
        for v1 in V, v2 in V
            if Td(v1,v2) >= 0
                fix(kvars[v1,v2],1)
            end
        end

        @objective(sub,Min, 0)

        #    @constraint(sub,lastesttime[d =D ,j = Jd[d].j,i = I[d,j].i],
        #        sum(xvars[v,d,j,i] for v in V if d in Dv[v].d && j in Jd[d].j && i in I[d,j].i) *Te(d,j,i) <= tvars[d,j])#TODO: somethings wrong here

            @constraint(sub,demand[v in V],
                sum(xvars[v,d,j,i] for d in Dv[v].d,j in Jd[d].j,i in I[d,j].i) == 1)

            @constraint(sub,openday[j in J],
                sum(xvars[v,d,j2,i] for v in V, d in Dv[v].d, j2 in Jd[d].j, i in I[d,j2].i if j2 ==j) <= M1 * yvars[j] )

            @constraint(sub,sameday[v1 in V, v2 in V,j in J; v1 != v2 ],
                    sum(xvars[v1,d,j2,i] for d in Dv[v1].d,j2 in Jd[d].j, i in I[d,j2].i if j2 == j)+sum(xvars[v2,d,j2,i] for d in Dv[v2].d,j2 in Jd[d].j, i in I[d,j2].i if j2 == j) <= gvars[v1,v2]+ 1 )


            @constraint(sub,beginsBefore[v1 in V, v2 in V,j in J; v1 != v2] ,
                -sum(Ts(d,j2,i)*xvars[v2,d,j2,i] for d in Dv[v2].d,j2 in Jd[d].j,i in I[d,j2].i if j2 == j )
                + sum(Te(d,j2,i)*xvars[v1,d,j2,i] for d in Dv[v1].d,j2 in Jd[d].j,i in I[d,j2].i if j2 == j)
                <=  (1-gvars[v1,v2])*M2+(1-kvars[v1,v2])*M2)

            @constraint(sub, numberofrelations, sum(kvars[v2,v1] for v1 in V, v2 in V if v1 != v2 ) == length(V)*(length(V)-1)/2)

            @constraint(sub,timebetweenappointments[v1 in V, v2 in V;v1 != v2 ],
                sum(j*xvars[v2,d,j,i] for d in Dv[v2].d,j in Jd[d].j,i in I[d,j].i )
                - sum(j*xvars[v1,d,j,i] for d in Dv[v1].d,j in Jd[d].j,i in I[d,j].i )
                >= Td(v1,v2)
                -(1-kvars[v1,v2])*M2)


        addPricingProblem(subproblems,patientgroup,sub,xvars,yvars,[],kvars,gvars,p,) ##TODO stop adding all that stuff

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



function solveSub!(sub,sets,ϕ,θ,κ)
    p = sets.Pg[sub.intID].patients[1]

    #@objective(sub.model, Min, sum(1000*sub.yvars[j] for j in sets.J) - sum(sub.tvars[d,j]*ϕ[d,j] for d in sets.Dp[p].d,j in sets.Jd[d].j,i in sets.I[d,j].i ) - sum(sub.xvars[v,d,j,i] * θ[d,j,i] for v in sets.Vp[p].v, d in sets.Dv[v].d,j in sets.Jd[d].j,i in sets.I[d,j].i)-κ[sub.intID] )
    @objective(sub.model, Min, sum(1000*sub.yvars[j] for j in sets.J)  - sum(sub.xvars[v,d,j,i] * θ[d,j,i] for v in sets.Vp[p].v, d in sets.Dv[v].d,j in sets.Jd[d].j,i in sets.I[d,j].i)-κ[sub.intID] )

    optimize!(sub.model)
    status = termination_status(sub.model)
    if status != MOI.TerminationStatusCode(1)

        throw("Error: Non optimal sub-problem for subproblem $(sub.intID)")

        #TODO Throw warning and extend search area
    end

    return objective_value(sub.model)
end
