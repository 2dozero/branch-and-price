include("data.jl")
include("column_generation.jl")
using DataStructures
# 현재 ColumnGeneration code를 구현해두었어. 하지만 나는 해당 코드를 이용한 branch-and-bound algorithm을 구현하고 싶어.
# 이를 위해서는 ColumnGeneration 코드를 수정해도 괜찮아. 특히 branch-and-bound algorithm에서 braching을 할때, branching variable이 0 또는 1 중에 선택되면 이를 반영하여 RestrictedMaster를 풀어야 하기 때문에 이를 고려해서 코드를 수정해야 할거야.
# 매 branching마다 ColumnGeneration을 다시 반복해서 풀어야겠지?
# branching variable 선택 방식은 다음과 같아. ColumnGeneration을 풀고 나온 최종 결과의 각 path의 λ 값들 중 가장 높은 λ 값을 가지는 path중 하나의 arc를 branching variable로 선택할거야.
# 이를 통해 branching variable이 선택되면 해당 arc가 있는 path만 골라내서 다시 RestrictedMaster를 풀어야 해.

# branch-and-bound는 다음 3가지 과정으로 이루어져 있어. 1) branching, 2) bounding, 3) fathoming
# Fathoming test는 다음과 같아. A subproblm is fathomed (dismissed from further consideration) if Test1) Its bound >= Z* or Test2) Its LP relaxation has no feasible solutions or Test3) The optimal solution for its LP relaxation is integer.(If this solution is better than the incumbent, it becomes the new incumbent, and test1 is reapplied to all unfathomed subproblems with the new smaller Z*)
# Initialization : Set Z* = ∞. If not fathomed, clsssify this problem as the one remaining "subproblem" for performing the first full iteration below.
# Branching : Among the remaining (unfathomed) subproblems, select the one that was created most recently. Branch from the node for this subproblem to create two new subproblems by fixing the next variable (the branching variable) at either 0 or 1.
# Bounding : For each new subproblem, solve its LP relaxation to obtain an optimal solution. If this value of Z is not an integer, round it up to an integer (If it was already an integer, no change is needed.) This integer value of Z is the bound for the subproblem.
# Fathoming : For each new subproblem, apply the three fathoming tests summarized above, and discard those subproblems that are fathomed by any of the tests.
# Optimality test : Stop when there are no remaining subproblems that have not been fathomed. The current incumbent is optimal. Otherwise, return to perform another iteration.
# 이를 통해 branch-and-bound algorithm을 julia로 구현해줘.
# branch-and-bound algorithm은 tree 구조를 가져야해. 그래야 fathomed되었을때, 더 이상 해당 branch를 진행하지 않고 parent node를 backtracking하여 다른 branch를 진행할 수 있어. 이를 고려해서 subproblems를 저장할 수 있는 자료구조를 사용해야 해.

struct TreeNode
    data::Any
    parent::Union{TreeNode, Nothing}
    children::Vector{TreeNode}
    visited::Bool
end

# function add_child(parent::TreeNode, data::Any)
#     child = TreeNode(data, parent, [])
#     push!(parent.children, child)
#     return child
# end

# function backtrack(node::TreeNode)
#     return node.parent
# end

# collect(subproblems)[1].data[7]
# value.(collect(subproblems)[1].data[2]) : λ값들

function is_fathomed(m, Z_star)
    @show objective_value(m[1]) 
    # Test 1: Its bound >= Z*
    if objective_value(m[1]) >= Z_star
        println("fathomed : Test 1")
        return true
    end

    # Test 2: Its LP relaxation has no feasible solutions
    @show termination_status(m[1])
    if termination_status(m[1]) != MOI.OPTIMAL
        println("fathomed : Test 2")
        return true
    end

    # Test 3: The optimal solution for its LP relaxation is integer
    # @show value.(λ)
    @show value.(m[2])
    if all(isinteger, value.(m[2]))
        # incumbent update
        if objective_value(m[1]) < Z_star
            Z_star = objective_value(m[1])
            println("Is integer : ", value.(m[2]))
            @show Z_star
        end
        println("fathomed : Test 3")
        println("λ : ", value.(m[2]))
        return true
    end
    return false
end

function BranchAndBound(origin, destination, arc_cost, arc_time, paths, Cost, Time)
    # Initialization
    Z_star = Inf
    m, λ, π1, π0 = ColumnGeneration(origin, destination, arc_cost, arc_time, paths, Cost, Time)
    root = TreeNode((m, λ, π1, π0, paths, Cost, Time), nothing, []) # Create a root node for the initial subproblem
    subproblems = Deque{TreeNode}() # Create an empty Deque of TreeNodes
    push!(subproblems, root) # Push the root node into the deque
    # Branching
    while !isempty(subproblems)
        # Among the remaining (unfathomed) subproblems, select the one that was created most recently.
        node = popfirst!(subproblems)
        m, λ, π1, π0, paths, Cost, Time = node.data
        # Branch from the node for this subproblem to create two new subproblems by fixing the next variable (the branching variable) at either 0 or 1.
        @show value.(λ)
        max_λ_index = findmax(value.(λ))[2]
        @show max_λ_index
        path = paths[max_λ_index]
        @show paths
        @show path
        branching_variables = []
        for i in 1:n_arcs
            push!(branching_variables, [start_node[i], end_node[i]])
        end
        branching_variable = popfirst!(branching_variables)
        @show branching_variable
        first_indices = findall(path -> any(path[i:i+1] == branching_variable for i in 1:length(path)-1), paths)
        @show first_indices
        second_indices = setdiff(1:length(paths), first_indices)
        @show second_indices

        indices_dict = Dict(1 => first_indices, 2 => second_indices)
        for i in 1:2
            new_paths = copy(paths)
            new_Cost = copy(Cost)
            new_Time = copy(Time)
            i_indices = indices_dict[i]
            new_paths = new_paths[i_indices]
            new_Cost = new_Cost[i_indices]
            new_Time = new_Time[i_indices]
            # println("------")
            # @show new_paths
            # @show new_Cost
            # @show new_Time
            # println("------")
            m, λ, π1, π0 = ColumnGeneration(origin, destination, arc_cost, arc_time, new_paths, new_Cost, new_Time) # 제약을 여기서 줬어야 하는거 아닌가?
            child = TreeNode((m, λ, π1, π0, new_paths, new_Cost, new_Time), node, []) # Create a new TreeNode for each child subproblem
            push!(subproblems, child)
        end
        # 지금 이런 방식이면 dfs든, bfs든 할 수 없지 않을까? -> parent 관계 정의되어 있음
        # println("------")
        # @show subproblems
        # println("------")
        for node in subproblems
            if !is_fathomed(node.data, Z_star)
                m, λ, π1, π0, new_paths, new_Cost, new_Time = node.data

                end
            end
        end
    end
    return Z_star
end

BranchAndBound(origin, destination, arc_cost, arc_time, paths, Cost, Time)
# if objective_value(m) != round(objective_value(m))
#     set_objective_function(m, round(objective_value(m)))