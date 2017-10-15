"""
    LaneChangeChoice
A choice of whether to change lanes, and what direction to do it in
"""
const DIR_RIGHT = -1
const DIR_MIDDLE =  0
const DIR_LEFT =  1
struct LaneChangeChoice
    dir::Int # -1, 0, 1
end
Base.show(io::IO, a::LaneChangeChoice) = @printf(io, "LaneChangeChoice(%d)", dir)
Base.length(::Type{LaneChangeChoice}) = 1
Base.convert(::Type{LaneChangeChoice}, v::Vector{Float64}) = LaneChangeChoice(convert(Int, v[1]))
function Base.copy!(v::Vector{Float64}, a::LaneChangeChoice)
    v[1] = a.dir
    v
end

####################

abstract type LaneChangeModel end
get_name(::LaneChangeModel) = "???"
set_desired_speed!(::LaneChangeModel, v_des::Float64) = model # # do nothing by default
reset_hidden_state!(model::LaneChangeModel) = model # do nothing by default
Base.rand(model::LaneChangeModel) = error("rand not implemented for model $model")