include("data.jl")
include("column_generation.jl")
using DataStructures

mutable struct BBTNode
    data::Any
    parent::Union{BBTNode, Nothing}
    children::Vector{BBTNode}
    branching_variable::Vector{Int64}
    visited::Bool
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

    root = BBTNode((m, λ, π1, π0, paths, Cost, Time), nothing, [], Vector{Int64}(), false)
    # root = BBTNode((m, λ, π1, π0, paths, Cost, Time), nothing, [], [], false)
    subproblems = Deque{BBTNode}()
    push!(subproblems, root)

    while !isempty(subproblems)
        node = popfirst!(subproblems)
        m, λ, π1, π0, paths, Cost, Time = node.data
        is_fathomed_result, Z_star = is_fathomed(node.data, Z_star)

        if is_fathomed_result
            continue

        else
            branching_variables_history = [] ##
            # branching
            max_λ_index = findmax(value.(λ))[2]
            path = paths[max_λ_index]
            branching_variables = [[start_node[i], end_node[i]] for i in 1:n_arcs]
            # @show branching_variables
            branching_variable = popfirst!(branching_variables)
            push!(branching_variables_history, branching_variable) ##
            @show branching_variables_history
            first_indices = findall(path -> any(path[i:i+1] == branching_variable for i in 1:length(path)-1), paths)
            second_indices = setdiff(1:length(paths), first_indices)

            indices_dict = Dict(1 => first_indices, 2 => second_indices)
            # variable_value = Dict(1 => 0, 2 => 1)
            for i in 1:2
                new_paths = paths[indices_dict[i]]
                new_Cost = Cost[indices_dict[i]]
                new_Time = Time[indices_dict[i]]
                @show branching_variable
                variable_value = i == 1 ? 1 : 0
                @show variable_value
                m, λ, π1, π0, status = ColumnGeneration(origin, destination, arc_cost, arc_time, new_paths, new_Cost, new_Time, branching_variables_history, variable_value)
                if status != MOI.INFEASIBLE
                    child = BBTNode((m, λ, π1, π0, new_paths, new_Cost, new_Time), node, [], branching_variable, false)
                    push!(subproblems, child)
                    # branching_variable_history가 저장이 안되고 있는 느낌. tree구조에서 어떻게 저장할 수 있지?
                end
            end
        end
    end
    return Z_star
end


BranchAndBound(origin, destination, arc_cost, arc_time, paths, Cost, Time)