getDays(resource,subcal) = (x->x.date[1]).(filter(day ->day.date in subcal,resource.calendar.workdays))

function getTimeSlot(resource,dayID)
    workdays = filter(x->x.date[1]==dayID,resource.calendar.workdays)
    length(workdays) > 1 ? error("Multiple days with same dayID") :
    length(workdays) == 1 ? (x->x.intID).(workdays[1].timeslots) : Int64[]
end
getTSendtime(resource,dayID,slotID) = Dates.value(filter(x->x.date[1]==dayID,resource.calendar.workdays)[1].timeslots[slotID].endTime)/60000000000
function getTSendtime(resource,dayID,slotID,refDate)
    workday = filter(x->x.date[1]==dayID,resource.calendar.workdays)[1]
    datetime = workday.timeslots[slotID].endTime + workday.date[2]
    Dates.value(datetime-refDate)/60000000000
end
function getTSstarttime(resource,dayID,slotID,refDate)
    workday = filter(x->x.date[1]==dayID,resource.calendar.workdays)[1]
    test = length(workday.timeslots)
    slotID > test ? error("slotID out of range") :
    datetime = workday.timeslots[slotID].startTime + workday.date[2]
    Dates.value(datetime-refDate)/60000000000
end
getTSstarttime(resource,dayID,slotID) = Dates.value(filter(x->x.date[1]==dayID,resource.calendar.workdays)[1].timeslots[slotID].startTime)/60000000000
getResource(resources,visits) = findqualifiedResourceIDs(resources,visits)
getTdelta(v1,v2) = v1 == 1 ? 1440 - 8*60 : 0  #TODO create this funtion correctly

function setup_sub!(subproblems::Subproblems,patient::Patient,resources::Array{Resource},subMastercalendar::Dict{Int,Date})
    M = 10000
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
    @variable(sub,yvars[j = J])
    @variable(sub,tvars[d = D,j = J_d[d]])
    @variable(sub,kvars[V,V], Bin)
    @objective(sub,Min, rand()*sum(xvars[v,d,j,i] for v in V,  d in D_v[v],j in J_d[d],i in I[d][j]))

        @constraint(sub,lastesttime[d =D ,j = J_d[d],i = I[d][j]],
            sum(xvars[v,d,j,i] for v in V, d1 in D_v[v] if d1 == d) *getTSendtime(resources[d],j,i) <= tvars[d,j])

        @constraint(sub,demand[v in V],
            sum(xvars[v,d,j,i] for d in D_v[v],j in J_d[d],i in I[d][j]) == 1)

        @constraint(sub,openday[j in J],
            sum(xvars[v,d,j,i] for v in V, d in D_v[v], i in I[d][j]) <= M * yvars[j] )

        @constraint(sub,beginsBefore[v1 in V, v2 in V ; v1 != v2] ,
            sum(Ts[d][j][i]*xvars[v1,d,j,i] for d in D_v[v1],j in J_d[d],i in I[d][j] )
            - sum(Ts[d][j][i]*xvars[v2,d,j,i] for d in D_v[v2],j in J_d[d],i in I[d][j] )
            <= kvars[v2,v1]*M)

        @constraint(sub,timebetweenappointments[v1 in V, v2 in V;v1 != v2],
            sum(Ts[d][j][i]*xvars[v1,d,j,i] for d in D_v[v1],j in J_d[d],i in I[d][j] )
            - sum(Te[d][j][i]*xvars[v2,d,j,i] for d in D_v[v2],j in J_d[d],i in I[d][j] )
            >= getTdelta(v1,v2)+
            -(1-kvars[v2,v1])*M) #TODO Te, Ts, Tdelta


    addsubproblem(subproblems,sub,xvars,yvars,tvars,kvars,patient.intID)
end




# function solveSub(subproblems,phi,pi,kappa,patient,param::Parameters)
#     P, I, J, D, R, DR, w1,w2,activities,M,timeofday = get(param)
#     sub,xvars_sub, yvars_sub, tvars_sub = getsubproblem(subproblems,patient)
#
#     @objective(sub, Min, sum(yvars_sub[j]*w2[patient] for j in J) - sum(tvars_sub[j,d]*phi[i,j,d] for i in I, j in J, d in D ) - sum(xvars_sub[i,j,d] * pi[i,j,d] for i in I, j in J, d in DR)-kappa[patient] )
#
#
#     optimize!(sub)
#     status = termination_status(sub)
#     if status != MOI.TerminationStatusCode(1)
#         throw("Error: Non optimal sub-problem")
#     end
#
#     return objective_value(sub), value.(xvars_sub), value.(yvars_sub),value.(tvars_sub)
# end
