using StructEditor
using Dates
import ConstructionBase

#=
This example shows how to make certain field readonly using the StructEditor.readonly function.  Also
demonstrated is the computed property `add`.  Computed/readonly properties can be provided by:
- overriding getproperty
- overriding propertynames - this way StructEditor knows to build the control
- adding readonly for the property
=#

@enum Gender Male Female

@kwdef struct Address
    street::String = "123 Main St"
    city::String = "Springfield"
end

@kwdef mutable struct Person
    name::String = "Alice"
    age::Int = 30
    gender::Gender = Female
    joined::Date = Date(2020, 1, 1)
    tags::Vector{String} = ["a", "b"]
    address::Address = Address()
    x::Int = 1
    y::Int = 2
end

function Base.getproperty(c::Person, sym::Symbol)
    if sym == :add
        return c.x + c.y
    else
        # Fallback for actual struct fields (like :radius)
        return getfield(c, sym)
    end
end

function Base.propertynames(c::Person)
    return (fieldnames(typeof(c))..., :add)
end

# NOTE: use this below for immutable structs
# Person is immutable, so every field edit goes through Accessors.set ->
# ConstructionBase.setproperties. Overloading propertynames above breaks
# ConstructionBase's default derivation (it can no longer assume propertynames ==
# fieldnames), so it must be told explicitly how to rebuild a Person from a patch.
# `:add` is readonly and computed, so it never appears in `patch` here.
# function ConstructionBase.setproperties(c::Person, patch::NamedTuple)
#     fields = ConstructionBase.getfields(c)
#     return Person(; merge(fields, patch)...)
# end

StructEditor.readonly(::Type{Person}, ::Val{:add}) = true

# scalar controls (SLInput/SLCheckbox/SLTextarea) render disabled but still reactive
StructEditor.readonly(::Type{Person}, ::Val{:name}) = true

# SLSelect has no disabled mode, so this falls back to the plain-text viewer rendering
StructEditor.readonly(::Type{Person}, ::Val{:gender}) = true

# ListManager has no disabled mode either, same fallback
StructEditor.readonly(::Type{Person}, ::Val{:tags}) = true

# marking a nested composite field readonly cascades: every control inside the
# Address card (street, city) becomes readonly too, with no readonly() methods
# needed on Address itself
StructEditor.readonly(::Type{Person}, ::Val{:address}) = true

editor(Person())
