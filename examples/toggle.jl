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


function StructEditor.make_control!(value::Observable, ::Type{T}, sname::Symbol) where T <: StartType
    name = string(sname)
    val = getproperty(value[], sname)
    h = StructEditor.help(typeof(value[]), Val(sname) )
    select = SLSelect( [string(x) for x in instances(StartType)]; label=name, help=h)

    select.index[] = Int(val) + 1

    on(select.index) do i
        value[] = set(value[], PropertyLens(sname), StartType(i-1))
    end

    return [select]
end

function StructEditor.make_control!(value::Observable, ::Type{Union{Date, Nothing}}, sname::Symbol)
    name = string(sname)
    val = getproperty(value[], sname)
    h = StructEditor.help(typeof(value[]), Val(sname) )

    y = if isnothing(val)
        SLInput(Date(now()); label=name, disabled=true, help=h)
    else
        SLInput(val; label=name, help=h)
    end
    
    on(value) do x
        @show x
        if x.start == Specified
            y.disabled[] = false
        else
            y.disabled[] = true
            value.val = set(value[], PropertyLens(sname), nothing)
        end
    end
    on(y.value) do x
        # println(":: y ($name): $x type $(typeof(x))")
        value[] = set(value[], PropertyLens(sname), Date(x))
    end

    return [y]
end

t = Task()
file=joinpath(@__DIR__, "toggle.json")
editor(t; file)

# JSON.parsefile(file, Task)