using LightGraphs, MetaGraphs,SimpleWeightedGraphs
using GraphPlot

function edgeallowed(g,n1,n2,prev)


end

### Constructs graph for the specific set of data given solving the shortest path should be equivalent to getting the a patient plan ###
function constructGraph(sets,weightofday)
    g = MetaDiGraph(0,0.0)
    # adding start and end vertex
    add_vertex!(g,Dict(:coord => (0,0,0,0),:v=>0,:d=>0,:j=>0,:i=>0,:Te => 0, :Ts => 0,:Δ => Dict()))
    add_vertex!(g,Dict(:coord => (length(test.V)+1,0,0,0),:v=>length(test.V)+1,:d=>0,:j=>0,:i=>0,:Δ => Dict()))
    set_indexing_prop!(g,:coord)
    prev_v = 0
    for v in sets.V
        let prev_v = prev_v
            for d in sets.D_v[v]
                for j in sort(sets.J_d[d], by = x ->x[1])
                    for i in sets.I[d][j]
                        add_vertex!(g,:coord,(v,d,j,i))
                        curnode = vertices(g)[end]
                        Te = sets.Te[d][j][i]
                        Ts = sets.Ts[d][j][i]
                        set_props!(g,curnode,Dict(:v=>v,:d=>d,:j=>j,:i=>i,:Te=>Te,:Ts=>Ts,:Δ => sets.Tdelta[v]))

                        for n in filter(λ-> (get_prop(g,λ,:v) == prev_v
                                            && (prev_v == 0
                                            || (get_prop(g,λ,:j)+get_prop(g,λ,:Δ)[v][1] <= j
                                            && get_prop(g,λ,:Te) <= Ts))) #TODO we have Tdelta for source node, maybe use get
                                            ,vertices(g))
                            get_prop(g,n,:j) != j ? weight = weightofday : weight = 0

                            add_edge!(g,n,curnode)
                            v_out = get_prop(g,n,:v)
                            d_out = get_prop(g,n,:d)
                            j_out = get_prop(g,n,:j)
                            i_out = get_prop(g,n,:i)
                            Te_out = get_prop(g,n,:Te)
                            set_props!(g,n,curnode,Dict(:weight=>weight,:Te => Te_out,:v=>v_out,:d=>d_out,:j=>j_out,:i=>i_out))
                            Δ_out = get_prop(g,n,:Δ)
                            Δ = get_prop(g,curnode,:Δ)
                            if prev_v != 0
                                for key in keys(sets.Tdelta[v_out])
                                    Δ[key] =  max(Δ_out[key], sets.Tdelta[v_out][key])
                                end
                            end
                        end

                    end
                end
            end

        end
        prev_v = v
    end
    for n in filter(λ->  get_prop(g,λ,:v)==sets.V[end] ,vertices(g))
        add_edge!(g,n,2)
        v_out = get_prop(g,n,:v)
        d_out = get_prop(g,n,:d)
        j_out = get_prop(g,n,:j)
        i_out = get_prop(g,n,:i)
        Te_out = get_prop(g,n,:Te)
        set_props!(g,n,2,Dict(:weight=>0,:v=>length(test.V)+1,:Te => Te_out,:v=>v_out,:d=>d_out,:j=>j_out,:i=>i_out))
    end

    return g
end
function addnumbertoweight!(g,edge,number)
    curweight = get_prop(g,edge,:weight)
    set_prop!(g,edge,:weight,curweight+number)
end

### Deprecated ###
function adddualvariablestoweights!(g,ϕ,θ)
    for dv in eachindex(ϕ)
        for edge in collect(filter_edges(g, (g, x) -> get_prop(g, x, :d) == dv[1] && get_prop(g, x, :j) == dv[2] ))
            addnumbertoweight!(g,edge,ϕ[dv])
        end
    end
    for dv in eachindex(θ)
        for e in collect(filter_edges(g, (g, x) -> get_prop(g, x, :d) == dv[1] && get_prop(g, x, :j) == dv[2] && get_prop(g, x, :i) == dv[3]  ))
            addnumbertoweight!(g,edge,θ[dv])
        end
    end
end
function adddualvariablestoweights!(g,ϕ,θ)
    for edge in edges(g)
        curweight = get_prop(g,edge,:weight)
        change = 0
        d = get_prop(g,edge,:d)
        j = get_prop(g,edge,:j)
        i = get_prop(g,edge,:i)
        Te = get_prop(g,edge,:Te)

        if haskey(ϕ,(d,j))   change -=  ϕ[d,j]*Te end
        if haskey(θ,(d,j,i)) change -=  θ[d,j,i] end
        if change != 0       set_prop!(g,edge,:weight,curweight + change) end
    end
end

function calculateshortestpath(g)
    state = dijkstra_shortest_paths(g,1)
    path = enumerate_paths(state,2)
    return state.dists[2], get_prop.(Ref(g),path[2:end-1],:coord)
end

function calculateshortestpath!(g,ϕ,θ,κ)
    adddualvariablestoweights!(g,ϕ,θ)
    calculateshortestpath(g)
end

g = constructGraph(test,1000)
collect(filter_vertices(g,Dict(:v=>1,:d=>2)))
collect(filter_vertices(g, (g, x) -> get_prop(g, x, :d) == 1 && get_prop(g, x, :j) < 110 ))
calculateshortestpath(g)
for i in 1:100
    println(i)
    g = constructGraph(test,1000)
    calculateshortestpath!(g,ϕ,θ,κ)
    optimize!(mp.model)
end
dijkstra_shortest_paths(g,1)
x = calculateshortestpath(g)
haskey(ϕ,(2,70))
x =collect(filter_edges(g, (g, x) -> get_prop(g, x, :d) == 3 && get_prop(g, x, :j) == 64 && get_prop(g, x, :i) == 1  ))
get = get_prop.(Ref(g),x,:Te)
κ
test.Tdelta

Te = test.Te[4][92][5]
Ts = test.Ts[4][92][5]
Te = test.Te[1][92][5]
Ts = test.Ts[1][92][5]
test.V
[test.D_v[v] for v in test.V]
#TODO something wrong in sort of V
#TODO Only make edge is wait of previous edges is overholdt

g = MetaDiGraph(0,0.0)
add_vertex!(g,Dict(:coord => (0,0,0,0),:v=>0,:d=>0,:j=>0,:i=>0,:Te => 0, :Ts => 0,:Δ => Dict()))
add_vertex!(g,Dict(:coord => (length(test.V)+1,0,0,0),:v=>length(test.V)+1,:d=>0,:j=>0,:i=>0,:Δ => Dict()))
x = get_prop(g,12,:Δ)
x[1] = 10
get_prop(g,1,:Δ)

ctest.
[1]#TODO her kom jeg til findt en måde at få et Dict ud der er uden true false
(x-> x[1]).(())
test.Tdelta
