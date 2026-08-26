using StructEditor
using Bonito
using Accessors
using Markdown
using Dates

#=
NOTE: Here we see how child structs are represented.  In `Special` below
      the Parent and nested Child structs are displayed inside cards and
      are fully edititable.
=#

@kwdef mutable struct Child
    name::String = "name"
end


@kwdef mutable struct Parent
    name::String = "name"
    age::Int = 0
    child::Child # this type has fields, will automatically be included in an editor card
end

@kwdef struct Special 
    num::Float64 = 1.0
    date::Date = Date(now())
    string::String = "test"
    bool::Bool = true
    markdown::Markdown.MD = md"# Header"
    person::Parent = Parent("person 1", 1, Child("kid")) # this type has fields, will automatically be included in an editor card
end


file=joinpath(@__DIR__, "special.json")

debugger = Ref{StructEditor.ApplicationState}()

# create a new file
editor(Special(); save_function=StructEditor.SaveFunction(;file), debugger)

#=
Create the below observable callback then make changes to any field, including the 
Parent and Child fields, they should all trigger top level callbacks

on(debugger[].value) do x
    println("changed!")
end
=#