# v0.7.0 (unreleased)
**Breaking.**
- `model => pars` no longer flattens a `MTKParams`: it builds an ordinary `Pair`. Use
  `parameter_pairs(model, pars)` (e.g. `ODEProblem(sys, parameter_pairs(sys, pars), tspan)`, or
  `[parameter_pairs(source, special)...]` in `initial_conditions`). The method this removes was on
  `Base.Pair`, and loading the package invalidated ~90,000 compiled methods because of it.
- `remake(prob, setters, pdict)` is now `update(prob, setters, pdict)`, the non-mutating
  counterpart of `update!`. It was a `SciMLBase.remake` method on argument types this package does
  not own.
- `setproperty!(pars, dict)` is now `update!(pars, dict)`. The unused
  `setproperty!(dict, pars, sys)` is removed.
- `MTKParams` is a `mutable struct`, replacing the `Base.ismutable` method it had (StructEditor
  checks `ismutable` to edit in place). Loading the package now invalidates no compiled methods.
- `hash` is defined to agree with `isequal`.
- `get_defs` holds values as given: a number is a `Number`, not a symbolic constant. Only values
  that are expressions of other parameters are symbolic. `getproperty` is unchanged.

# v0.5.0
Depricated `Params` and replaced with `MTKParams`.  Structs no longer need to be manually generated, only a model function or instantiated model is needed.  