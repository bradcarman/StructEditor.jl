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
end

file=joinpath(@__DIR__, "All.json")

a = All()
StructEditor.make_control!(Ref(a), Float64, :num)
StructEditor.make_control!(Ref(a), Date, :date)
StructEditor.make_control!(Ref(a), String, :string)
StructEditor.make_control!(Ref(a), Markdown.MD, :markdown)
StructEditor.make_control!(Ref(a), Vector{Person}, :people)

# create a new file
editor(All(); file)

# load an existing file
editor(file, All, mode = StructEditor.browser)
