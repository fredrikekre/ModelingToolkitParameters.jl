# Parameter files through StructUtils (`ParameterFileStyle`): field tags and defaults on the
# value's type, a value saved as a reference (lower/lift), and what a file may not contain.
using Test, ModelingToolkit, ModelingToolkitParameters, StructUtils
using ModelingToolkit: t_nounits as t, D_nounits as D

abstract type AbstractMat end
@kwarg struct Alloy <: AbstractMat
    rho::Float64 = 8.9 &(params = (name = "density",),)    # written as `density`
    factor::Float64 = 1.0
    note::String = "" &(params = (ignore = true,),)         # never written
end
struct Ceramic <: AbstractMat
    rho::Float64
end
massdensity(m::Alloy) = m.rho * m.factor
massdensity(m::Ceramic) = m.rho
@register_symbolic massdensity(m::AbstractMat)

# Large data, saved by name and rebuilt from it (as a named data set would be).
struct Dataset
    name::String
    table::Vector{Float64}
end
const DATASETS = Dict("small" => [1.0, 2.0], "large" => [3.0, 4.0, 5.0])
load_dataset(name) = Dataset(name, DATASETS[name])
StructUtils.structlike(::ParameterFileStyle, ::Type{Dataset}) = false
StructUtils.lower(::ParameterFileStyle, m::Dataset) = Dict("name" => m.name)
StructUtils.lift(::ParameterFileStyle, ::Type{Dataset}, d) = (load_dataset(d["name"]), nothing)
datagain(m::Dataset) = sum(m.table)
@register_symbolic datagain(m::Dataset)

@component function Pot(; name, mat = Alloy(), data = load_dataset("small"))
    _mat, _data = mat, data
    pars = @parameters begin
        (mat::AbstractMat)
        (data::Dataset)
        k = 1.0
        q                                                     # no value: unset
    end
    vars = @variables x(t)
    System([D(x) ~ -massdensity(mat) * datagain(data) * k * q * x], t, vars, pars; name,
           initial_conditions = [mat => _mat, data => _data, x => 1.0])
end

loads(s) = (f = joinpath(mktempdir(), "p.toml"); write(f, s); load_parameters(f, Pot))

@testset "parameter files" begin
    @testset "round trip with tags and a reference" begin
        pars = MTKParams(Pot)
        pars.mat = Alloy(rho = 7.0, factor = 2.0, note = "not saved")
        pars.data = load_dataset("large")
        f = joinpath(mktempdir(), "p.toml")
        save_parameters(pars, f)
        s = read(f, String)
        @test occursin("density = 7.0", s) && !occursin("rho", s) && !occursin("note", s)
        @test occursin("name = \"large\"", s) && !occursin("table", s)
        @test !occursin(r"^q\b"m, s)                          # unset values are not written
        back = load_parameters(f, Pot)
        @test back.mat == Alloy(rho = 7.0, factor = 2.0)
        @test back.data.name == "large" && back.data.table == [3.0, 4.0, 5.0]
        @test back.k == 1.0 && back.q === nothing
    end

    @testset "defaults, concrete subtypes, missing" begin
        @test loads("mat = {type = \"Alloy\"}").mat == Alloy()            # all fields defaulted
        @test loads("mat = {type = \"Alloy\", factor = 3.0}").mat == Alloy(factor = 3.0)
        @test loads("mat = {type = \"Ceramic\", rho = 2.5}").mat === Ceramic(2.5)
        @test loads("data = {type = \"Dataset\", name = \"small\"}").data.table == [1.0, 2.0]
        @test loads("k = \"missing\"").k === missing
    end

    @testset "rejected" begin
        err(s) = try loads(s); "" catch e; sprint(showerror, e) end
        @test occursin("no field `densty`", err("mat = {type = \"Alloy\", densty = 1.0}"))
        @test occursin("not `AbstractMat` or one of its concrete subtypes",
                       err("mat = {type = \"Dataset\", name = \"small\"}"))
        @test occursin("needs a `type` entry", err("mat = {rho = 1.0}"))
        @test occursin("rho", err("mat = {type = \"Ceramic\"}"))         # no default
        # strings are data, never code
        @test occursin("only accepted for a `String` parameter", err("k = \"error(1)\""))
    end

    @testset "no method ambiguities with StructUtils" begin
        @test isempty(filter(a -> any(m -> m.module === ModelingToolkitParameters, a),
                             Test.detect_ambiguities(ModelingToolkitParameters, StructUtils)))
    end
end
