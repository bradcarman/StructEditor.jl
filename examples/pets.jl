using JSON
import StructUtils
using StructEditor
using ShoelaceWidgets
using Bonito
using Accessors

abstract type Animal end

# Use the @tag macro to associate a string identifier with the type
struct Cat <: Animal
    name::String
    purrs::Bool
end

struct Dog <: Animal
    name::String
    bark_volume::Int
end

mutable struct Household
    pet::Animal
end

const ANIMALS = [Cat, Dog]
const ANIMAL_TYPES = Dict(string(x) => x for x in ANIMALS)
JSON.lower(a::Animal) = merge(
    StructUtils.make(Dict{String, Any}, a), 
    Dict("type" => string(nameof(typeof(a))))
)
JSON.@choosetype Animal dict -> ANIMAL_TYPES[JSON.parse(dict["type"], String)]

file=joinpath(@__DIR__, "pets.json")
# h = Household(Cat("Ellie", true))
# open(file, "w") do io
#     JSON.json(io, h; pretty=true)
# end
# value = JSON.parsefile(file, Household)

function StructEditor.make_control!(state::StructEditor.ApplicationState, ::Type{T}, sname::Symbol, dirty=identity) where T <: Animal
    name = string(sname)
    val = getproperty(state.value[], sname)
    local ref::StructEditor.ApplicationState
    select = SLSelect(["Dog","Cat"]; label=name)

    if val isa Dog
        select.index[] = 1
    elseif val isa Cat
        select.index[] = 2
    end

    on(select.index) do i
        if i == 1
            state.value[] = set(state.value[], PropertyLens(sname), Dog("",0))
        elseif i == 2
            state.value[] = set(state.value[], PropertyLens(sname), Cat("",false))
        end
        
        dirty(true)
    end

    button = SLButton("edit")
    dialog = SLDialog(DOM.div("---"); label=string(nameof(T)))
    

    on(dialog.open) do o
        if !o
            state.value[] = set(state.value[], PropertyLens(sname), ref.value[])

            dirty(true)
        end
    end
    
    on(button.value) do x
        val = getproperty(state.value[], sname)
        ref = StructEditor.ApplicationState(Observable(val), Dict())        
        dialog.value[] = StructEditor.make_form(ref; class="")
        dialog.open[] = true
    end

    return [DOM.div(select, button), dialog]
end

h = Household(Dog("Ellie",10))

# open editor
editor(h; save_function=StructEditor.SaveFunction(;file))

# open file
editor(file, Household; mode=StructEditor.browser)