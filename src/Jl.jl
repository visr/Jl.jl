module Jl

using Pkg: Pkg, REPLMode, Types

const JL_VERSION = pkgversion(@__MODULE__)

function print_help()
    println("jl - Julia package manager command-line interface\n")
    println("Full documentation available at https://pkgdocs.julialang.org/\n")

    printstyled("OPTIONS:\n", bold = true)
    println("  +CHANNEL          Specify Julia version as a juliaup channel (e.g., +1.12)")
    println("  --project=PATH    Set the project environment (default: current project)")
    println("  --offline         Work in offline mode")
    println("  --help            Show this help message")
    println("  --version         Show jl version\n")

    printstyled("SYNOPSIS:\n", bold = true)
    println("  jl [opts] cmd [args]\n")
    println("Multiple commands can be given on the same line by interleaving a ; between")
    println("the commands. Some commands have an alias, indicated below.\n")

    printstyled("COMMANDS:\n", bold = true)

    print("    ")
    printstyled("init", color = :cyan)
    println(": initialize an empty project (optionally at a specified path)")

    print("\n    ")
    printstyled("run", color = :cyan)
    println(": run a Julia script")

    # Group commands by category
    for (category_name, category_title) in [
            ("package", "Package management commands"),
            ("registry", "Registry commands"),
            ("app", "App commands"),
        ]
        category_specs = get(REPLMode.SPECS, category_name, nothing)
        category_specs === nothing && continue

        println()
        printstyled("  $category_title\n", bold = true)

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
            printstyled(full_cmd, color = :cyan)
            if spec.short_name !== nothing
                print(", ")
                printstyled(spec.short_name, color = :cyan)
            end
            println(": $(spec.description)")
        end
    end
    return
end

function (@main)(args)::Int32
    # Reset LOAD_PATH to allow normal Julia project resolution
    # The shim sets JULIA_LOAD_PATH to the app environment, but we want
    # to respect the user's current directory for project resolution
    # Only needed in ENV for the child processes
    sep = Sys.iswindows() ? ';' : ':'
    ENV["JULIA_LOAD_PATH"] = join(Base.DEFAULT_LOAD_PATH, sep)

    # Parse options before the command
    project_path = nothing
    juliaup_channel = nothing
    offline_mode = false
    idx = 1

    while idx <= length(args)
        arg = args[idx]

        if startswith(arg, "--project=")
            project_path = arg[(length("--project=") + 1):end]
            idx += 1
        elseif arg == "--project" && idx < length(args)
            idx += 1
            project_path = args[idx]
            idx += 1
        elseif startswith(arg, "+")
            juliaup_channel = arg[2:end]
            idx += 1
        elseif arg == "--offline"
            offline_mode = true
            idx += 1
        elseif arg == "--help"
            print_help()
            return 0
        elseif arg == "--version"
            println("jl version $JL_VERSION")
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
    remaining_args = args[idx:end]

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
    if project_path === nothing
        # Look for project path to activate
        # If a script is specified, use its directory as the starting point
        script_arg = findfirst(arg -> endswith(arg, ".jl"), remaining_args)
        base_dir = if script_arg !== nothing
            dirname(abspath(remaining_args[script_arg]))
        else
            pwd()
        end
        current_proj = Base.current_project(base_dir)
        if current_proj === nothing
            # No project found, use default environment
            Pkg.activate(; io = devnull)
        else
            Pkg.activate(current_proj; io = devnull)
        end
    else
        Pkg.activate(project_path; io = devnull)
    end

    # Set offline mode if requested
    if offline_mode
        Pkg.offline(true)
    end

    # Set Julia channel if requested
    if juliaup_channel !== nothing
        # Unfotunately this way it won't auto install despite
        # juliaup config autoinstallchannels true
        # see https://github.com/JuliaLang/juliaup/issues/1331
        # Hence for now we add it manually, but only on init for perf reasons
        if remaining_args[1] == "init"
            run(`juliaup add $juliaup_channel`)
        end
        ENV["JULIAUP_CHANNEL"] = juliaup_channel
    end

    # Execute the Pkg REPL command
    try
        return run_subcommand(remaining_args)
    catch e
        if e isa InterruptException
            return 130  # Standard exit code for SIGINT
        end
        println(stderr, "Error: ", sprint(showerror, e))
        return 1
    end
end

function run_subcommand(args::Vector{String})::Int32
    if args[1] == "init"
        return run_init(args)
    elseif args[1] == "run"
        return run_run(args)
    else
        return run_pkg(args)
    end
end

function run_init(args::Vector{String})::Int32
    # TODO Copy uv: If a Project.toml is found in any of the parent directories of the target path, the project will be added as a workspace member of the parent.
    # TODO test behavior on existing project, clear error

    project_path = length(args) > 1 ? args[2] : pwd()
    code = """
    import Pkg
    Pkg.activate($(repr(project_path)); io = devnull)
    # Only writes a Project.toml the second time
    Pkg.instantiate(; io = devnull)
    Pkg.instantiate(; io = devnull)
    """
    julia_cmd = `julia --startup-file=no --eval $code`
    pipe = pipeline(julia_cmd; stdin, stdout, stderr)
    process = run(pipe; wait = false)
    wait(process)

    println("Initialized empty project at $(abspath(project_path))")
    return Int32(process.exitcode)
end

function run_run(args::Vector{String})::Int32
    if length(args) == 1
        error("No script specified: `jl run script.jl`.")
    end
    Pkg.instantiate(; io = devnull)
    run_args = args[2:end]
    # Pass the currently active project to the child Julia process
    active_project = Base.active_project()
    cmd = `julia --startup-file=no --threads=auto --project=$active_project $run_args`
    pipe = pipeline(cmd; stdin, stdout, stderr)
    process = run(pipe; wait = false)
    wait(process)
    return Int32(process.exitcode)
end

function run_pkg(args::Vector{String})::Int32
    # Delegate to Pkg REPLMode via subprocess
    pkg_command = join(args, " ")
    active_project = Base.active_project()
    code = """
    using Pkg: REPLMode

    # Disable interactivity warning (pkg should be used interactively)
    if isdefined(REPLMode, :PRINTED_REPL_WARNING)
        REPLMode.PRINTED_REPL_WARNING[] = true
    end

    REPLMode.pkgstr($(repr(pkg_command)))
    """
    cmd = `julia --startup-file=no --threads=auto --project=$active_project --eval $code`
    pipe = pipeline(cmd; stdin, stdout, stderr)
    process = run(pipe; wait = false)
    wait(process)
    return Int32(process.exitcode)
end

end # module Jl
