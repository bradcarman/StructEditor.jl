using StructEditor
using Dates
using Markdown
using Bonito
using ShoelaceWidgets

@kwdef struct DifferentFields
    a::String = "a"
    b::String = "long string of text"
    c::String = "c"
end

# NOTE: here we can see targeting a specific field of the struct with 
#       the `make_control!(::ApplicationState, ::Val{field}, dirty)` signature
function StructEditor.make_control!(state::ApplicationState{DifferentFields}, ::Val{:b}, dirty=identity)
    sname = :b
    name = string(sname)
    val = getproperty(state.value[], sname)
    h = StructEditor.help(typeof(state.value[]), Val(sname) )

    y = SLTextarea(val; label=name, help=h)
    StructEditor.bind_field!(state, sname, y.value, dirty)

    return [y]
end

debugger = Ref{StructEditor.ApplicationState}()

editor(DifferentFields(); debugger)

#=
NOTE: Here we can see the bind_field! working, changes to the data 
       are reflected in the control

```julia
debugger[].value[] = DifferentFields("Change", "The", "Values")
```
=#