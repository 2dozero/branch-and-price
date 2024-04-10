include("data.jl")

π1 = 35.0

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

# Usage
path = [1, 3, 2, 5, 6]
path_weight = calculate_path_weight(path, start_node, end_node, arc_cost, arc_time, π1)