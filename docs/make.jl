using Documenter, PCM

makedocs(
    modules = [PCM],
    format = :html,
    checkdocs = :exports,
    sitename = "PCM.jl",
    pages = Any["index.md"]
)

deploydocs(
    repo = "github.com/hildebrandmw/PCM.jl.git",
)
