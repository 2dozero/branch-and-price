data = [
    1 2 1 10
    1 3 10 3
    2 4 1 1 
    2 5 2 3 
    3 2 1 2
    3 4 5 7
    3 5 12 3
    4 5 10 1
    4 6 1 7
    5 6 2 2
]
start_node = data[:, 1]
end_node = data[:, 2]
arc_cost = data[:, 3]
arc_time = data[:, 4]

origin, destination = 1, 6

n_nodes = 6
n_arcs = length(start_node)

using JuMP, HiGHS
using Graphs, SimpleWeightedGraphs

# path1 = [1, 2, 4, 5, 6]
# path2 = [1, 2, 4, 6]

# paths = [path1, path2]
# Cost = [14, 3]
# Time = [14, 18]

path1 = [1, 2, 4, 5, 6]
path2 = [1, 2, 4, 6]
path3 = [1, 3, 2, 5, 6]
path4 = [1, 2, 5, 6]

paths = [path1, path2, path3, path4]
Cost = [14, 3, 15, 5]
Time = [14, 18, 10, 15]

