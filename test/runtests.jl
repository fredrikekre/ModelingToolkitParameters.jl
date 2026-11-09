using Test
using ModelingToolkit
using ModelingToolkitParameters
using SciMLBase

include("model.jl")

include("parent_bindings.jl")

include("unresolved_bindings.jl")

include("own_unresolved_bindings.jl")

include("symbolic_values.jl")

include("struct_parameters.jl")

include("values_and_pairs.jl")

@mtkcompile rc_model = RCModel()
rc_model_params = MTKParams(RCModel)
rc_model_params.capacitor.m = 1 #set missing value
prob = ODEProblem(rc_model, parameter_pairs(rc_model, rc_model_params), (0, 10.0))


# slow but easy update method...
rc_model_params.resistor.R = 1.5                            # change param struct 
prob′ = remake(prob; p = pdict(rc_model, rc_model_params))       # remake prob (standard call with new pdict)
@test prob′.ps[rc_model.resistor.R] == 1.5                   # check parameter update


# fast update method (mutate prob)...
setters = cache(rc_model, rc_model_params)                    # get a cache of SymbolicIndexingInterface pset
rc_model_params.resistor.R = 2.0                            # change param struct
update!(prob, setters, pdict(rc_model, rc_model_params))         # update the prob
@test prob.ps[rc_model.resistor.R] == 2.0                   # check parameter update



# fast update method (copy prob)...
rc_model_params.resistor.R = 3.0                             # change param struct
prob′ = update(prob, setters, pdict(rc_model, rc_model_params))   # copy of prob, updated with the pset cache and pdict
@test prob.ps[rc_model.resistor.R] == 2.0                    # check prob is not mutated
@test prob′.ps[rc_model.resistor.R] == 3.0                   # check new prob′ value
