using Test
using Jl
using IOCapture: capture

"Empty test/<dir> and run f inside it."
function testdir(f, dir)
    dir = normpath(@__DIR__, dir)
    rm(dir; recursive = true, force = true)
    mkpath(dir)
    tmp = realpath(dir)
    cd(tmp) do
        f(tmp)
    end
end

@testset "help" begin
    c = capture() do
        Jl.main(["help"])
    end
    @test c.value == 0
    @test contains(c.output, "jl - Julia package manager command-line interface")
end

@testset "README example workflow" begin
    testdir("readme") do tmpdir
        @show tmpdir
        # Test: jl init
        c = capture() do
            Jl.main(["init"])
        end
        @test c.value == 0
        @test contains(c.output, "Initialized empty project")
        @test isfile(joinpath(tmpdir, "Project.toml"))

        # Test: jl add Example and Runic
        c = capture() do
            Jl.main(["add", "Example", "Runic"])
        end
        @test c.value == 0

        # Create hello.jl script
        hello_script = joinpath(tmpdir, "hello.jl")
        write(hello_script, """
            using Example: hello

            println(hello("Julia"))
            """)

        # Test: jl run hello.jl
        c = capture() do
            Jl.main(["run", "hello.jl"])
        end
        @test c.value == 0
        @test contains(c.output, "Hello, Julia")

        # Test: jl app add Runic
        c = capture() do
            Jl.main(["app", "add", "Runic"])
        end
        @test c.value == 0

        # Test: jl run -m Runic --version
        c = capture() do
            Jl.main(["run", "-m", "Runic", "--version"])
        end
        @test c.value == 0
        @test contains(c.output, "runic version")
    end
end
