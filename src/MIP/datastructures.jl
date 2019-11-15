mutable struct Masterproblem
    model::JuMP.Model
    consref_offtime
    consref_onepatient
    convexitycons
    lambda
    closingtime
end

mutable struct Subproblem
        patient
    model::JuMP.Model
    xvars; yvars; tvars; kvars
    V; D; D_v; J; J_d; I; Ts; Te
    Subproblem() = new()
end



function addsubproblem(subproblems,nsub,sub::JuMP.Model,xvars,yvars,tvars,kvars, V, D ,D_v, J, J_d, I, Ts, Te)
        cursub = Subproblem()
        cursub.patient = nsub #TODO is this correct?
        cursub.model = sub
        cursub.xvars = xvars
        cursub.yvars = yvars
        cursub.tvars = tvars
        cursub.kvars = kvars
        cursub.V = V
        cursub.D = D
        cursub.D_v = D_v
        cursub.J = J
        cursub.J_d = J_d
        cursub.I = I
        cursub.Ts = Ts
        cursub.Te = Te

        subproblems[nsub] = cursub
end

function getsubproblem(subproblems,patient)
    return subproblems.models[patient], subproblems.xvars[patient], subproblems.yvars[patient], subproblems.tvars[patient]
end
