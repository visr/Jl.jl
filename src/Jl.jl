module Jl

using Pkg: Pkg, REPLMode, Types

function print_help()
    println("jl - Julia package manager command-line interface\n")
    println("Full documentation available at https://pkgdocs.julialang.org/\n")

    printstyled("OPTIONS:\n", bold=true)
    println("  --project=PATH    Set the project environment (default: current project)")
    println("  --offline         Work in offline mode")
    println("  --help            Show this help message")
    println("  --version         Show Pkg version\n")

    printstyled("SYNOPSIS:\n", bold=true)
    println("  jl [opts] cmd [args]\n")
    println("Multiple commands can be given on the same line by interleaving a ; between")
    println("the commands. Some commands have an alias, indicated below.\n")

    printstyled("COMMANDS:\n", bold=true)

    print("\n    ")
    printstyled("run", color=:cyan)
    println(": run a Julia script")

    # Group commands by category
    for (category_name, category_title) in [
        ("package", "Package management commands"),
        ("registry", "Registry commands"),
        ("app", "App commands")
    ]
        category_specs = get(REPLMode.SPECS, category_name, nothing)
        category_specs === nothing && continue

        println()
        printstyled("  $category_title\n", bold=true)

        # Get unique specs for this category and sort them
        specs_dict = Dict{String, Any}()
        for (name, spec) in category_specs
            specs_dict[spec.canonical_name] = spec
        end

        for cmd_name in sort(collect(keys(specs_dict)))
            spec = specs_dict[cmd_name]
            # For non-package commands, prefix with category
            full_cmd = category_name == "package" ? cmd_name : "$category_name $cmd_name"
            print("    ")
            printstyled(full_cmd, color=:cyan)
            if spec.short_name !== nothing
                print(", ")
                printstyled(spec.short_name, color=:cyan)
            end
            println(": $(spec.description)")
        end
    end
end

function (@main)(ARGS)::Int32
    # Disable interactivity warning (pkg should be used interactively)
    if isdefined(REPLMode, :PRINTED_REPL_WARNING)
        REPLMode.PRINTED_REPL_WARNING[] = true
    end

    # Reset LOAD_PATH to allow normal Julia project resolution
    # The shim sets JULIA_LOAD_PATH to the app environment, but we want
    # to respect the user's current directory for project resolution
    empty!(LOAD_PATH)
    append!(LOAD_PATH, Base.DEFAULT_LOAD_PATH)
    # also in ENV for the child processes
    sep = Sys.iswindows() ? ';' : ':'
    ENV["JULIA_LOAD_PATH"] = join(Base.DEFAULT_LOAD_PATH, sep)

    # Parse options before the command
    project_path = nothing
    offline_mode = false
    idx = 1

    while idx <= length(ARGS)
        arg = ARGS[idx]

        if startswith(arg, "--project=")
            project_path = arg[length("--project=")+1:end]
            idx += 1
        elseif arg == "--project" && idx < length(ARGS)
            idx += 1
            project_path = ARGS[idx]
            idx += 1
        elseif arg == "--offline"
            offline_mode = true
            idx += 1
        elseif arg == "--help"
            print_help()
            return 0
        elseif arg == "--version"
            println("Pkg version $(Types.TOML.parsefile(joinpath(@__DIR__, "..", "Project.toml"))["version"])")
            return 0
        elseif startswith(arg, "--")
            println(stderr, "Error: Unknown option: $arg")
            println(stderr, "Use --help for usage information")
            return 1
        else
            # Found the command, stop parsing options
            break
        end
    end

    # Get the remaining arguments (the Pkg command)
    remaining_args = ARGS[idx:end]

    if isempty(remaining_args)
        print_help()
        return 0
    end

    # Handle help command
    if remaining_args[1] == "help"
        if length(remaining_args) == 1
            # Just "help" with no arguments - show our CLI help
            print_help()
            return 0
        else
            # "help <command>" - convert to "?" for REPL compatibility
            # e.g., "help registry add" -> "? registry add"
            remaining_args[1] = "?"
        end
    end

    # Set project if specified, otherwise use Julia's default logic
    if project_path !== nothing
        Pkg.activate(project_path; io=devnull)
    else
        # Look for Project.toml in pwd or parent directories
        current_proj = Base.current_project(pwd())
        if current_proj !== nothing
            Pkg.activate(current_proj; io=devnull)
        else
            # No project found, use default environment
            Pkg.activate(; io=devnull)
        end
    end

    # Set offline mode if requested
    if offline_mode
        Pkg.offline(true)
    end

    # Execute the Pkg REPL command
    try
        run_jl(remaining_args)
        return 0
    catch e
        if e isa InterruptException
            return 130  # Standard exit code for SIGINT
        end
        println(stderr, "Error: ", sprint(showerror, e))
        return 1
    end
end

function run_jl(remaining_args::Vector{String})::Nothing
    if remaining_args[1] == "run"
        if length(remaining_args) == 1
            error("No script specified: `jl run script.jl`.")
        end
        Pkg.instantiate()
        run_args = remaining_args[2:end]
        run(`$(Base.julia_cmd()) --project $run_args`)
    else
        pkg_command = join(remaining_args, " ")
        REPLMode.pkgstr(pkg_command)
    end
    return nothing
end

end # module Jl
