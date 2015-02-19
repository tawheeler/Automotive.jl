# Car Encounter Model

module CarEM

push!(LOAD_PATH, "/home/tim/Documents/wheelerworkspace/Bosch/model/")

using BinMaps
using BayesNets
using Features

import Base: get

include("common.jl")
include("encounter_model.jl")
include("io.jl")
include("feature_extract.jl")
include("sim.jl")

end # module