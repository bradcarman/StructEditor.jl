using StructEditor
using Dates
using Markdown

@enum StateType Proposal Current Closed Forecast Archived

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
    vec::Vector{Int} = [1,2,3,4]
    skip::String = "skip me"
    state::StateType = Closed
end


file=joinpath(@__DIR__, "All.json")

StructEditor.skip_field(::Type{All}, ::Val{:skip}) = true
StructEditor.add_mode(::Type{All}, ::Val{:people}) = FunctionAdd
StructEditor.edit_mode(::Type{All}, ::Val{:people}) = DialogEdit

# create a new file
all = All();
editor(all; save_function=StructEditor.SaveFunction(;file))

# load an existing file
# editor(file, All, mode = StructEditor.browser)
