using JuMP, Gurobi

path1 = [1, 2, 4, 5, 6]
path2 = [1, 2, 4, 6]
path3 = [1, 2, 5, 6]
path4 = [1, 3, 2, 4, 5, 6]
path5 = [1, 3, 2, 4, 6]
path6 = [1, 3, 2, 5, 6]
path7 = [1, 3, 4, 5, 6]
path8 = [1, 3, 4, 6]
path9 = [1, 3, 5, 6]
all_paths = [path1, path2, path3, path4, path5, path6, path7, path8, path9]
all_Cost = [14, 3, 5, 24, 13, 15, 27, 16, 24]
all_Time = [14, 18, 15, 9, 13, 10, 13, 17, 8]


function RestrictedMaster(paths, Cost, Time)
    m = Model(Gurobi.Optimizer)
    @variable(m, λ[1:length(paths)] >= 0, Int) # relaxation with integer constraint
    @objective(m, Min, sum(Cost[i] * λ[i] for i in 1:length(paths)))
    @constraint(m, resource, sum(Time[i] * λ[i] for i in 1:length(paths)) <= 14)
    @constraint(m, convexity, sum(λ[i] for i in 1:length(paths)) == 1)
    optimize!(m)

    # status = termination_status(m)
    # if status == MOI.INFEASIBLE
    #     π1 = nothing
    #     π0 = nothing
    # else
    #     π1 = dual(resource)
    #     π0 = dual(convexity)
    # end
    # return m, λ, π1, π0, status
    return objective_value(m)
end

RestrictedMaster(all_paths, all_Cost, all_Time)