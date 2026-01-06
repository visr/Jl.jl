using Test
using Jl
using IOCapture: capture
import TOML

"Empty test/<dir> and run f inside it."
function testdir(f, dir)
    dir = normpath(@__DIR__, dir)
    rm(dir; recursive = true, force = true)
    mkpath(dir)
    tmp = realpath(dir)
    return cd(tmp) do
        f(tmp)
    end
end

@testset "Jl" begin
    @testset "help" begin
        c = capture() do
            Jl.main(["help"])
        end
        @test c.value == 0
        @test contains(c.output, "jl - Julia package manager command-line interface")
    end

    @testset "README example workflow" begin
        testdir("readme") do tmpdir
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
            write(
                hello_script, """
                using Example: hello

                println(hello("Julia"))
                """
            )

            # Test: jl run hello.jl
            c = capture() do
                Jl.main(["run", "hello.jl"])
            end
            @test c.value == 0
            @test contains(c.output, "Hello, Julia")

            # Test exit code propagation, from other directory
            exit_script = joinpath(tmpdir, "exit.jl")
            write(exit_script, "exit(5)")
            c = capture() do
                cd("../..") do
                    Jl.main(["run", "test/readme/exit.jl"])
                end
            end
            @test c.value == 5

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
            @test contains(c.output, "julia version")
            # Run with versions different than in the Manifest.toml
            for v in ["1.12.0", "1.12.1"]
                c = capture() do
                    Jl.main(["+$v", "run", "-m", "Runic", "--version"])
                end
                @test contains(c.output, "julia version $v")
            end
        end
    end
    @testset "Specify juliaup channel" begin
        testdir("channel") do tmpdir
            # Initialize with a given Julia version
            c = capture() do
                Jl.main(["+1.12.0", "init"])
            end
            @test c.value == 0
            @test contains(c.output, "Initialized empty project")
            @test isfile(joinpath(tmpdir, "Project.toml"))
            manifest = TOML.parsefile(joinpath(tmpdir, "Manifest.toml"))
            @test manifest["julia_version"] == "1.12.0"

            # Add preserves the julia_version in the Manifest.toml
            c = capture() do
                Jl.main(["add", "Example"])
            end
            @test c.value == 0
            manifest = TOML.parsefile(joinpath(tmpdir, "Manifest.toml"))
            @test manifest["julia_version"] == "1.12.0"

            # Adding with a different version changes the version
            c = capture() do
                Jl.main(["+1.12.1", "add", "Example"])
            end
            @test c.value == 0
            manifest = TOML.parsefile(joinpath(tmpdir, "Manifest.toml"))
            @test manifest["julia_version"] == "1.12.1"
        end
    end
end
