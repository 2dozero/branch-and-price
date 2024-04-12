include("data.jl")

function calculate_path_weight(path, start_node, end_node, arc_cost, arc_time, π1)
    total_weight = 0
    for i in 1:(length(path) - 1)
        for j in 1:length(start_node)
            if start_node[j] == path[i] && end_node[j] == path[i+1]
                weight = arc_cost[j] - arc_time[j] * π1
                total_weight += weight
                break
            end
        end
    end
    return total_weight
end

function RestrictedMaster(paths, Cost, Time)
    # @show paths, Cost, Time
    m = Model(HiGHS.Optimizer)
    @variable(m, λ[1:length(paths)] >= 0) # relaxation
    # @show λ
    @objective(m, Min, sum(Cost[i] * λ[i] for i in 1:length(paths)))
    @constraint(m, resource, sum(Time[i] * λ[i] for i in 1:length(paths)) <= 15)
    @constraint(m, convexity, sum(λ[i] for i in 1:length(paths)) == 1)
    optimize!(m)

    status = termination_status(m)
    if status == MOI.INFEASIBLE
        π1 = nothing
        π0 = nothing
    else
        π1 = dual(resource)
        π0 = dual(convexity)
    end
    return m, λ, π1, π0, status
end

function PricingSubproblem(π1, π0, origin, destination, arc_cost, arc_time)
    g = SimpleWeightedDiGraph(n_nodes)
    for i in 1:n_arcs
        add_edge!(g, start_node[i], end_node[i], arc_cost[i] - arc_time[i] * π1) # cost redifined
    end
    bf_state = bellman_ford_shortest_paths(g, origin)
    min_reduced_cost = bf_state.dists[destination] - π0
    new_column = enumerate_paths(bf_state)[destination]
    return min_reduced_cost, new_column
end

function PricingSubproblem(π1, π0, origin, destination, arc_cost, arc_time, branching_variables_history, variable_value)
    # @show branching_variables_history
    # @show variable_value
    g = SimpleWeightedDiGraph(n_nodes)
    epsilon = 1e-6
    for i in 1:n_arcs
        weight = arc_cost[i] - arc_time[i] * π1
        if [start_node[i], end_node[i]] in branching_variables_history
            weight *= variable_value == 0 ? Inf : -epsilon
        end
        add_edge!(g, start_node[i], end_node[i], weight) # cost redifined
    end
    bf_state = bellman_ford_shortest_paths(g, origin)
    @show bf_state
    min_reduced_cost = bf_state.dists[destination] - π0 
    @show min_reduced_cost
    new_column = enumerate_paths(bf_state)[destination]
    path_weight = calculate_path_weight(new_column, start_node, end_node, arc_cost, arc_time, π1) - π0
    return path_weight, new_column
end

function ColumnGeneration(origin, destination, arc_cost, arc_time, paths, Cost, Time)
    m, λ, π1, π0, status = RestrictedMaster(paths, Cost, Time)
    if status == MOI.INFEASIBLE
        return m, λ, π1, π0, status
    end
    min_reduced_cost, new_column = PricingSubproblem(π1, π0, origin, destination, arc_cost, arc_time)
    if min_reduced_cost < 0
        # @show paths
        # @show min_reduced_cost
        push!(paths, new_column)
        new_cost = 0
        new_time = 0
        for i in 1:(length(new_column)-1)
            for j in 1:n_arcs
                if start_node[j] == new_column[i] && end_node[j] == new_column[i+1]
                    new_cost += arc_cost[j]
                    new_time += arc_time[j]
                end
            end
        end
        push!(Cost, new_cost)
        # @show Cost
        push!(Time, new_time)
        # @show Time
        # @show paths
        m, λ, π1, π0, status = RestrictedMaster(paths, Cost, Time)
        @show paths
        return ColumnGeneration(origin, destination, arc_cost, arc_time, paths, Cost, Time)
    else
        return m, λ, π1, π0, status
        # @show raw_status(m)
        # @show objective_value(m)
        # @show value.(λ)
        # @show π1, π0
    end
end

function ColumnGeneration(origin, destination, arc_cost, arc_time, paths, Cost, Time, branching_variables_history, variable_value)
    m, λ, π1, π0, status = RestrictedMaster(paths, Cost, Time)
    if status == MOI.INFEASIBLE
        return m, λ, π1, π0, status
    end
    min_reduced_cost, new_column = PricingSubproblem(π1, π0, origin, destination, arc_cost, arc_time, branching_variables_history, variable_value)
    if min_reduced_cost < 0
        # @show paths
        # @show min_reduced_cost
        push!(paths, new_column)
        new_cost = 0
        new_time = 0
        for i in 1:(length(new_column)-1)
            for j in 1:n_arcs
                if start_node[j] == new_column[i] && end_node[j] == new_column[i+1]
                    new_cost += arc_cost[j]
                    new_time += arc_time[j]
                end
            end
        end
        push!(Cost, new_cost)
        # @show Cost
        push!(Time, new_time)
        # @show Time
        # @show paths
        m, λ, π1, π0, status = RestrictedMaster(paths, Cost, Time)
        @show paths
        return ColumnGeneration(origin, destination, arc_cost, arc_time, paths, Cost, Time)
    else
        return m, λ, π1, π0, status
        # @show raw_status(m)
        # @show objective_value(m)
        # @show value.(λ)
        # @show π1, π0
    end
end

# ColumnGeneration(origin, destination, arc_cost, arc_time, paths, Cost, Time)
# @show value.(λ)
# @show π1, π0
# @show objective_value(m)