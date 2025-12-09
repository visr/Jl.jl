# Jl

An early prototype for an app to run Julia scripts and manage packages.

`jl` uses [Pkg.jl](https://github.com/JuliaLang/Pkg.jl) and only slightly extends the `pkg` app from https://github.com/JuliaLang/Pkg.jl/pull/4473. It adds `init` and `run` subcommands as shown below.

## Installation

This [app](https://pkgdocs.julialang.org/v1/apps/) requires Julia 1.12 or higher.

```
pkg> app add https://github.com/visr/Jl.jl
```

This will place a `jl` shim in `~/.julia/bin`.
If that is in your PATH environment variable, you can run `jl` from anywhere.

## Usage

Create a new project in the current directory and add Example.

```sh
jl init
jl add Example
```

Add a Julia script called `hello.jl` with these contents:

```jl
using Example: hello

println(hello("Julia"))
```

You can now run the script like this:

```sh
jl run hello.jl
```

This is similar to `julia --project hello.jl`, except it will first instantiate the project.
This means that you can share the project and script with someone, and they only need to run this command.

Now let's add the Runic formatter to the project.
We can install this as a Pkg app just like `jl`.

```sh
jl app add Runic
```

However if we want to avoid relying on global apps we can add Runic to our project.
This can make it easier to share setups or use specific versions.

```
jl add Runic
```

And we can use the `-m` flag to run it.

```
jl run -m Runic --inplace .
```

Possibly we could support `jl run runic --inplace .`, where it accepts any apps in the current project or its dependencies.
Ideas welcome!

## Background

I was triggered by Miles Cranmer's call to [ship a built-in CLI for Pkg](https://github.com/JuliaLang/julia/issues/59370#issuecomment-3225803493).
He made a [PR adding `juliapkg` besides `juliaup`](https://github.com/JuliaLang/juliaup/pull/1230).
Later on Kristoffer Carlsson made a PR to add [a Pkg app called pkg to Pkg](https://github.com/JuliaLang/Pkg.jl/pull/4473).
This uses the experimental [Pkg app support](https://pkgdocs.julialang.org/v1/apps/) added in Julia 1.12.

As a regular user of [uv](https://docs.astral.sh/uv/) and [Pixi](https://pixi.sh/latest/) I like how they make it easy to not only do package management, but also facilitate running scripts, downloading dependencies as needed.
Currently having to explain to new users about `Pkg.instantiate()` and the `--project` flag seems too complicated compared to these tools.
People have argued about changing defaults, but usually security concerns are brought up, listing [Nefarious.jl](https://github.com/StefanKarpinski/Nefarious.jl) and https://github.com/JuliaLang/Pkg.jl/pull/2024 as examples.
See also discussion in [Make activate instantiate by default · Issue #1415 · Pkg.jl](https://github.com/JuliaLang/Pkg.jl/issues/1415).
So we should probably mention that `jl` should only be used if you trust the project you are in and its dependencies.

I put this code out there to get early feedback.
In the global namespace of CLI tools `jl` is short and easily associated with Julia, we should consider using it as a community.
It goes a bit beyond the currently proposed `pkg` app in scope, but if Pkg maintainers consider it in scope for Pkg, that would be a great home as almost all functionality comes from there already.
In the end it would be nice if users installing Julia directly get `jl` in their path somehow.
The `juliaup / juliapkg` approach is good for that, though I prefer to explore the Pkg app space for now, coding in Julia.
I don't plan on registering this package in General, so I just went with Jl to match the app name.
