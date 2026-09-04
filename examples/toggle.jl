using JSON
using StructUtils
using StructEditor
using ShoelaceWidgets
using Bonito
using Accessors
using Dates

@enum StartType Next Parallel Delayed Specified

@kwdef struct Task
    start::StartType=Next
    start_date::Union{Date, Nothing}=nothing
end

StructEditor.help(::Type{Task}, ::Val{:start}) = "Note: \"Specified\" means the date should be set by `start_date`"

# rule, if start_date is nothing, then start should be Next, Parallel, or Delayed, otherwise it should be specified

function StructEditor.make_control!(state::ApplicationState, ::Type{Union{Date, Nothing}}, sname::Symbol, dirty=identity)
    name = string(sname)
    val = getproperty(state.value[], sname)
    h = StructEditor.help(typeof(state.value[]), Val(sname) )

    y = if isnothing(val)
        SLInput(Date(now()); label=name, disabled=true, help=h)
    else
        SLInput(val; label=name, help=h)
    end


    function to_field(w::String)
        x = state.value[]

        if x.start == Specified
            return Date(w)
        else
            return nothing
        end
    end

    function to_widget(field::Union{Date, Nothing})
        if isnothing(field)
            return string(Date(now()))
        else
            return string(field)
        end
    end

    function getproperty_callback(x::Task, sname::Symbol)

        if x.start == Specified
            y.disabled[] = false
            return getproperty(x, sname)
        else
            y.disabled[] = true
            return nothing
        end
    end


    StructEditor.bind_field!(state, sname, y.value, dirty; to_field, to_widget, getproperty_callback)

    return [y]
end

t = Task()
file=joinpath(@__DIR__, "toggle.json")
debugger = Ref{ApplicationState}()
editor(t; save_function=StructEditor.SaveFunction(;file), debugger)

# JSON.parsefile(file, Task)