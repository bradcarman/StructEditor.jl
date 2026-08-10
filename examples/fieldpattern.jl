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

function StructEditor.make_control!(state::StructEditor.ApplicationState{DifferentFields}, ::Val{:b}, dirty=identity)
    sname = :b
    name = string(sname)
    val = getproperty(state.value[], sname)
    h = StructEditor.help(typeof(state.value[]), Val(sname) )

    y = SLTextarea(val; label=name, help=h)
    StructEditor.bind_field!(state.value, sname, y.value, dirty)

    return [y]
end

debugger = Ref{StructEditor.ApplicationState}()

editor(DifferentFields(); debugger)

# debugger[].value[] = DifferentFields("Change", "The", "Values")

