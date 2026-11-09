# API Reference

## Parameter Object Generation

```@docs
ModelingToolkitParameters.MTKParams
@mtkparams
```

## Parameter Map Generation

```@docs
ModelingToolkitParameters.pdict
ModelingToolkitParameters.parameter_pairs
```

## Caching and Updates

```@docs
ModelingToolkitParameters.cache
ModelingToolkitParameters.resolve
ModelingToolkitParameters.update!
ModelingToolkitParameters.update
```

## Transferring Solved Parameters

```@docs
ModelingToolkitParameters.transfer
```

## Comparing Parameter Objects

```@docs
ModelingToolkitParameters.compare
ModelingToolkitParameters.MTKParamsDiff
```

## Display Options

```@docs
ModelingToolkitParameters.show_missing!
ModelingToolkitParameters.hide_missing!
```

## Serialization

```@docs
ModelingToolkitParameters.save_parameters
ModelingToolkitParameters.load_parameters
ModelingToolkitParameters.parameters_to_string
ModelingToolkitParameters.string_to_parameters
```

## Type Conversions

```julia
Base.Dict(::MTKParams)
update!(::MTKParams, ::AbstractDict)
Base.copy(::MTKParams)
```

# Internals
Use this functions to access the internal properties of a `MTKParams` 

```@docs
get_parent
get_defs
```
