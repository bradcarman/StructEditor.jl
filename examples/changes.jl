using StructEditor
using Bonito
using ShoelaceWidgets

#=
In this example it's shown how changes to the struct Observable
are properly reflected in the control thru proper bindings.  

Both choice and chosen are bound, so changing one changes the other.
=#

@enum Choices A B C

@kwdef struct Chooser
    choice::Choices=A
    chosen::Int=1
end



function StructEditor.make_control!(state::StructEditor.ApplicationState{Chooser}, ::Type{T}, sname::Symbol, dirty=identity) where T <: Base.Enum
    name = string(sname)
    val = getproperty(state.value[], sname)
    

    opts = instances(T)
    select = SLSelect([string(x) for x in opts]; label=name)
    select.index[] = something(findfirst(==(val), opts), 1)

    # widget space here is the 1-based option index; `valid` keeps a cleared selection
    # (index 0) from indexing `opts` out of bounds
    StructEditor.bind_field!(state, sname, select.index, dirty;
                 to_field = i -> opts[i],
                 to_widget = v -> something(findfirst(==(v), opts), 1),
                 valid = i -> 1 <= i <= length(opts))

    StructEditor.bind_field!(state, :chosen, select.index, identity)

    return [select]
end
    
c = Chooser()
editor(c)

