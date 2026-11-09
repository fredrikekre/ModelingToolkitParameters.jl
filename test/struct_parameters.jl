# Struct-typed parameters: saved to and loaded from TOML as `{type = ..., fields...}` tables
# (no `eval`), and still settable after `ModelingToolkit.respecialize`.
using Test, ModelingToolkit, ModelingToolkitParameters, SciMLBase, SymbolicIndexingInterface
using ModelingToolkit: t_nounits as t, D_nounits as D

abstract type AbstractStuff end
struct Plain <: AbstractStuff
    k::Float64
end
struct Scaled <: AbstractStuff
    k::Float64
    s::Float64
end
rate(x::Plain) = x.k
rate(x::Scaled) = x.k * x.s
@register_symbolic rate(x::AbstractStuff)

@component function Decay(; name, stuff = Plain(1.0))
    _stuff = stuff
    pars = @parameters (stuff::AbstractStuff)
    vars = @variables x(t)
    System([D(x) ~ -rate(stuff) * x], t, vars, pars; name,
           initial_conditions = [stuff => _stuff, x => 1.0])
end

@component function Outer(; name, stuff = Plain(1.0))
    _stuff = stuff
    pars = @parameters (stuff::AbstractStuff)
    @named inner = Decay(; stuff)                       # passed down from the parent
    System(Equation[], t, [], pars; name, systems = [inner],
           initial_conditions = [stuff => _stuff])
end

@testset "struct parameters" begin
    @testset "TOML round-trip without eval" begin
        pars = MTKParams(Outer)
        pars.stuff = Scaled(2.0, 3.0)
        f = joinpath(mktempdir(), "p.toml")
        save_parameters(pars, f)
        s = read(f, String)
        @test occursin("type = \"Scaled\"", s)
        @test !occursin("inner", s)                     # the passed-down value is not written
        @test load_parameters(f, Outer).stuff === Scaled(2.0, 3.0)

        write(f, "stuff = {type = \"Plain\", k = 4.0}\n")
        @test load_parameters(f, Outer).stuff === Plain(4.0)
        for bad in ("stuff = {type = \"Base.Libc\", k = 1.0}", "stuff = {type = \"Plain\"}",
                    "stuff = {type = \"Plain\", k = 1.0, z = 2.0}", "stuff = {k = 1.0}")
            write(f, bad)
            @test_throws ErrorException load_parameters(f, Outer)
        end
    end

    @testset "after respecialize" begin
        @named outer = Outer()
        sys = ModelingToolkit.respecialize(mtkcompile(outer))
        prob = ODEProblem(sys, [], (0.0, 1.0))
        inner_stuff = only(filter(p -> ModelingToolkit.getname(p) == :inner₊stuff, parameters(sys)))
        pars = MTKParams(Outer)
        pars.stuff = Plain(5.0)                         # same concrete type as the default
        fast = remake(prob, cache(sys, pars), pdict(sys, pars))
        slow = remake(prob; p = pdict(sys, pars))
        @test fast.ps[inner_stuff] === Plain(5.0)
        @test slow.ps[inner_stuff] === Plain(5.0)
    end
end
