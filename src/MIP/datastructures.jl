mutable struct Masterproblem
    model::JuMP.Model
    consref_offtime
    consref_onepatient
    convexitycons
    lambda
    closingtime
end

mutable struct PricingProblem
        model::JuMP.Model
        xvars; yvars; tvars; kvars
        V; D; D_v; J; J_d; I; Ts; Te
        patients

        PricingProblem() = new()
end

mutable struct PPSets
        patient
        V; D; D_v; J; J_d; I; Ts; Te
        hash

        PPSets() = new()
end

mutable struct Subproblems
        pricingproblems::Dict{Int128,PricingProblem}
        sets::Dict{Int64,PPSets}

        Subproblems() = new(Dict{String,PricingProblem}(),Dict{Int128,PPSets}())
end

function addsets!(subproblems,patient,V,D,D_v,J,J_d,I,Ts,Te)
        curset = PPSets()
        curset.patient = patient #TODO is this correct?
        curset.V = V
        curset.D = D
        curset.D_v = D_v
        curset.J = J
        curset.J_d = J_d
        curset.I = I
        curset.Ts = Ts
        curset.Te = Te
        curset.hash = hashSets(curset)

        subproblems.sets[patient] = curset
        return curset
end


function addPricingProblem(subproblems,hashofsets,sub::JuMP.Model,xvars,yvars,tvars,kvars,patient,V,D,D_v,J,J_d,I,Ts,Te)
        curPP = PricingProblem()
        curPP.model = sub
        curPP.xvars = xvars
        curPP.yvars = yvars
        curPP.tvars = tvars
        curPP.kvars = kvars
        curPP.patients = [patient]
        curPP.V = V
        curPP.D = D
        curPP.D_v = D_v
        curPP.J = J
        curPP.J_d = J_d
        curPP.I = I
        curPP.Ts = Ts
        curPP.Te = Te

        subproblems.pricingproblems[hashofsets] = curPP
end

function getsubproblem(subproblems,patient)
    return subproblems.models[patient], subproblems.xvars[patient], subproblems.yvars[patient], subproblems.tvars[patient]
end
