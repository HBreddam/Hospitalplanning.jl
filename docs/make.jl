using Documenter, Hospitalplanning

makedocs(;
    modules=[Hospitalplanning],
    format=Documenter.HTML(),
    pages=[
        "Home" => "index.md",
    ],
    repo="https://github.com/HBreddam/Hospitalplanning.jl/blob/{commit}{path}#L{line}",
    sitename="Hospitalplanning.jl",
    authors="Henrik Bøgedal Breddam",
    assets=String[],
)

deploydocs(;
    repo="github.com/HBreddam/Hospitalplanning.jl",
)
