using StructEditor
using Bonito
using Accessors
using Markdown
using Dates

# use AbstractStructEditor type to automatical include in the editor
@kwdef struct Child <: AbstractStructEditor
    name::String = "name"
end

# use AbstractStructEditor type to automatical include in the editor
@kwdef struct Person <: AbstractStructEditor
    name::String = "name"
    age::Int = 0
    kid::Child # this type is an AbstractStructEditor type, will automatically be included in the editor
end

@kwdef struct Special
    num::Float64 = 1.0
    date::Date = Date(now())
    string::String = "test"
    bool::Bool = true
    markdown::Markdown.MD = md"# Header"
    person::Person = Person("person 1", 1, Child("kid")) # this type is an AbstractStructEditor type, will automatically be included in the editor
end


file=joinpath(@__DIR__, "special.json")

# create a new file
editor(Special(); file)