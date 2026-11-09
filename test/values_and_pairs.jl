# `get_defs` holds values as given (not symbolic constants), and `parameter_pairs` replaces
# the former `Base.Pair(::System, ::MTKParams)` method. No methods on functions the package
# does not own beyond the property/copy/equality/show protocols of its own types.
using Test, ModelingToolkit, ModelingToolkitParameters, SciMLBase, Symbolics
using ModelingToolkit: t_nounits as t, D_nounits as D

@component function Leaf(; name, k = 2.0)
    pars = @parameters k = k
    vars = @variables x(t) = 1.0
    System([D(x) ~ -k * x], t, vars, pars; name)
end

@component function Trunk(; name, g = 3.0)
    pars = @parameters g = g
    @named leaf = Leaf()
    # passed down: the child's initial condition is the parent's parameter
    System(Equation[], t, [], pars; name, systems = [leaf], initial_conditions = [leaf.k => g])
end

@testset "values and pairs" begin
    @testset "get_defs values are not symbolic constants" begin
        pars = MTKParams(Trunk)
        defs = get_defs(pars)
        @test defs[ModelingToolkit.unwrap(get_parent(pars).g)] === 3.0
        pars.g = 4.5
        @test defs[ModelingToolkit.unwrap(get_parent(pars).g)] === 4.5
        @test pars.g === 4.5
        # a value a parent passes down stays an expression of its source
        v = defs[ModelingToolkit.unwrap(getproperty(get_parent(pars).leaf, :k))]
        @test !(v isa Number)
        @test isequal(collect(Symbolics.get_variables(v)), [ModelingToolkit.unwrap(get_parent(pars).g)])
        # copies are independent and keep plain values
        p2 = copy(pars); p2.g = 1.0
        @test pars.g === 4.5 && p2.g === 1.0
    end

    @testset "parameter_pairs, and no method on Base.Pair" begin
        @test all(m -> m.module !== ModelingToolkitParameters, methods(Pair))
        @named sys = Trunk()
        pars = MTKParams(sys)
        @test (sys => pars) isa Pair
        pars.g = 5.0
        csys = mtkcompile(sys)
        prs = parameter_pairs(csys, pars)
        @test prs isa Vector{<:Pair}
        prob = ODEProblem(csys, prs, (0.0, 1.0))
        @test prob.ps[csys.g] == 5.0
        @test prob.ps[csys.leaf.k] == 5.0                # follows its source
        @test Symbolics.value(pdict(csys, pars)[ModelingToolkit.unwrap(csys.g)]) == 5.0
    end

    @testset "no extra methods on Base or SciMLBase" begin
        own(f) = filter(m -> m.module === ModelingToolkitParameters, collect(methods(f)))
        @test isempty(own(Pair))
        @test isempty(own(ismutable))
        @test isempty(own(SciMLBase.remake))
        @test isempty(filter(m -> length(m.sig.parameters) != 4, own(setproperty!)))  # only the 3-arg protocol
        pars = MTKParams(Trunk)
        @test ismutable(pars)                            # StructEditor edits in place on this
    end

    @testset "hash agrees with isequal" begin
        a = MTKParams(Trunk); b = MTKParams(Trunk)
        @test isequal(a, b) && hash(a) == hash(b)
        b.g = 7.0
        @test !isequal(a, b)
        @test length(Set([a, copy(a), b])) == 2
    end

    @testset "update!(pars, dict)" begin
        pars = MTKParams(Trunk)
        @test update!(pars, Dict("g" => 6.0)) === pars
        @test pars.g == 6.0
        @test update!(pars, Dict(pars)) === pars && pars.g == 6.0     # Dict round-trip
    end
end
