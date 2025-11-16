using Test
using Jl
using IOCapture
import Aqua

@testset "Jl" begin

    @testset "help" begin
        c = IOCapture.capture() do
            Jl.main(["help"])
        end
        @test c.value == 0
        @test contains(c.output, "jl - Julia package manager command-line interface")
    end

    Aqua.test_all(Jl)
end
