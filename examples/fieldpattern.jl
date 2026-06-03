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

function StructEditor.make_control!(value::Observable{DifferentFields}, ::Val{:b})
    sname = :b
    name = string(sname)
    val = getproperty(value[], sname)
    h = StructEditor.help(typeof(value[]), Val(sname) )

    y = SLTextarea(val; label=name, help=h)
    on(y.value) do x
        # println(":: y ($name): $x")
        if ismutable(value[])
            setproperty!(value[], sname, x)
        else
            value[] = set(value[], PropertyLens(sname), x)
        end
    end

    return [y]
end

editor(DifferentFields())


