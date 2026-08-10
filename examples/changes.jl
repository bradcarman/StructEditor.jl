using StructEditor
using Bonito
using ShoelaceWidgets

@enum Choices A B C

@kwdef struct Chooser
    choice::Choices=A
    chosen::Vector{String}=String[]
end

function StructEditor.make_control!(state::StructEditor.ApplicationState{Chooser}, ::Type{T}, sname::Symbol, dirty=identity) where T <: Base.Enum
    name = string(sname)
    val = getproperty(state.value[], sname)
    

    opts = instances(T)
    select = SLSelect([string(x) for x in opts]; label=name)
    select.index[] = something(findfirst(==(val), opts), 1)

    on(select.index) do i
        i = Int(i)
        if i > 0
            push!(state.value[].chosen, select.values[i])
            notify(state.value)
        end
    end

    # widget space here is the 1-based option index; `valid` keeps a cleared selection
    # (index 0) from indexing `opts` out of bounds
    StructEditor.bind_field!(state.value, sname, select.index, dirty;
                to_field = i -> opts[i],
                to_widget = v -> something(findfirst(==(v), opts), 1),
                valid = i -> 1 <= i <= length(opts))

    return [select]
end
    
c = Chooser()
editor(c)