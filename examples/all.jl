using StructEditor
using Dates
using Markdown

@kwdef struct Person
    name::String = "name"
    age::Int = 0
end

@kwdef struct All
    num::Float64 = 1.0
    date::Date = Date(now())
    string::String = "test"
    bool::Bool = true
    markdown::Markdown.MD = md"# Header"
    people::Vector{Person} = [Person("person 1", 1), Person("person 2", 2)]
    skip::String = "skip me"
end


file=joinpath(@__DIR__, "All.json")

StructEditor.skip_field(::Type{All}, ::Val{:skip}) = true

# create a new file
editor(All(); file)

# load an existing file
# editor(file, All, mode = StructEditor.browser)
