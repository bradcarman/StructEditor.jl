using StructEditor
using Bonito
using Accessors
using Markdown
using Dates


@kwdef struct Child
    name::String = "name"
end


@kwdef struct Person
    name::String = "name"
    age::Int = 0
    kid::Child # this type has fields, will automatically be included in an editor card
end

@kwdef struct Special 
    num::Float64 = 1.0
    date::Date = Date(now())
    string::String = "test"
    bool::Bool = true
    markdown::Markdown.MD = md"# Header"
    person::Person = Person("person 1", 1, Child("kid")) # this type has fields, will automatically be included in an editor card
end


file=joinpath(@__DIR__, "special.json")

# create a new file
editor(Special(); file)