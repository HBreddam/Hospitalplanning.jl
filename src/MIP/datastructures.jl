

mutable struct Subproblems
    models::Array{JuMP.Model,1}
    xvars
    yvars
    tvars
    kvars

    Subproblems(nsub) = new(Vector{JuMP.Model}(undef,nsub),[],[],[],[])
end

function addsubproblem(subproblems::Subproblems,sub::JuMP.Model,xvars,yvars,tvars,kvars,nsub)
        subproblems.models[nsub] = sub
        push!(subproblems.xvars, xvars)
        push!(subproblems.yvars, yvars)
        push!(subproblems.tvars, tvars)
        push!(subproblems.kvars, kvars)
end

function getsubproblem(subproblems,patient)
    return subproblems.models[patient], subproblems.xvars[patient], subproblems.yvars[patient], subproblems.tvars[patient]
end
