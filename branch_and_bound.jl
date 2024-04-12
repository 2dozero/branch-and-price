include("data.jl")
include("column_generation.jl")
using DataStructures

mutable struct BBTNode
    data::Any
    parent::Union{BBTNode, Nothing}
    children::Vector{BBTNode}
    branching_variable::Vector{Int64}
    visited::Bool
    is_pruned
    branching_variables_history
    branching_variables_values::Vector{Int64}  # new field
end

function is_fathomed(m, Z_star)
    if termination_status(m[1]) == MOI.INFEASIBLE || all(isinteger, value.(m[2]))
        if termination_status(m[1]) == MOI.OPTIMAL && all(isinteger, value.(m[2])) && objective_value(m[1]) < Z_star
            Z_star = objective_value(m[1])
        end
        println("is fathomed")
        return true, Z_star
    elseif termination_status(m[1]) == MOI.OPTIMAL && objective_value(m[1]) >= Z_star
        println("is fathomed due to non-improvement")
        return true, Z_star
    end
    return false, Z_star
end

function BranchAndBound(origin, destination, arc_cost, arc_time, paths, Cost, Time)
    Z_star = Inf
    m, λ, π1, π0, status = ColumnGeneration(origin, destination, arc_cost, arc_time, paths, Cost, Time)

    root = BBTNode((m, λ, π1, π0, paths, Cost, Time), nothing, Vector{BBTNode}(), Vector{Int64}(), false, false, Vector{Vector{Int64}}(), Vector{Int64}())
    # root = BBTNode((m, λ, π1, π0, paths, Cost, Time), nothing, [], [], false)
    subproblems = Deque{BBTNode}()
    push!(subproblems, root)

    branching_variables_history = [] ##
    branching_variables = [[start_node[i], end_node[i]] for i in 1:n_arcs]
    while !isempty(subproblems)
        node = popfirst!(subproblems)
        m, λ, π1, π0, paths, Cost, Time = node.data
        is_fathomed_result, Z_star = is_fathomed(node.data, Z_star)

        if is_fathomed_result
            continue

        else
            # branching_variables_history = [] ##
            # branching
            max_λ_index = findmax(value.(λ))[2]
            path = paths[max_λ_index]
            # @show branching_variables
            if length(branching_variables) == 0
                continue
            end
            branching_variable = popfirst!(branching_variables)
            # push!(branching_variables_history, branching_variable) ##
            @show branching_variables_history
            first_indices = findall(path -> any(path[i:i+1] == branching_variable for i in 1:length(path)-1), paths)
            second_indices = setdiff(1:length(paths), first_indices)

            indices_dict = Dict(1 => first_indices, 2 => second_indices)
            for i in 1:2
                new_paths = paths[indices_dict[i]]
                new_Cost = Cost[indices_dict[i]]
                new_Time = Time[indices_dict[i]]
                # @show branching_variable
                variable_value = i == 1 ? 1 : 0
                # @show variable_value
                branching_variables_history = copy(node.branching_variables_history)
                push!(branching_variables_history, branching_variable)
                branching_variables_values = copy(node.branching_variables_values)
                push!(branching_variables_values, variable_value)
                m, λ, π1, π0, status = ColumnGeneration(origin, destination, arc_cost, arc_time, new_paths, new_Cost, new_Time, branching_variables_history, branching_variables_values)
                if status != MOI.INFEASIBLE
                    child = BBTNode((m, λ, π1, π0, new_paths, new_Cost, new_Time), node, Vector{BBTNode}(), branching_variable, false, false, branching_variables_history, branching_variables_values)
                    push!(subproblems, child)
                end
            end
        end
    end
    return Z_star
end

BranchAndBound(origin, destination, arc_cost, arc_time, paths, Cost, Time)