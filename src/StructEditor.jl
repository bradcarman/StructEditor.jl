module StructEditor
using Dates
using Markdown
using ShoelaceWidgets
using Bonito
using Accessors
using JSON
using StructUtils

StructUtils.structlike(::StructUtils.StructStyle, ::Type{Markdown.MD}) = false
StructUtils.lower(md::Markdown.MD) = Markdown.plain(md)
StructUtils.lift(::Type{Markdown.MD}, s::AbstractString) = Markdown.parse(s)

export editor

const STYLE_CSS = """
    sl-button,
    sl-select,
    sl-checkbox,
    sl-textarea,
    sl-tag,
    sl-input {
        margin: 2px;
    }

    sl-tree {
        margin: 2px;
        border: 1px solid lightgray;
    }

    .shoelace-label {
        /* Matches sl-input label styling */
        display: inline-block;
        color: var(--sl-input-label-color);
        font-family: var(--sl-input-font-family);
        font-size: var(--sl-input-label-font-size-medium);
        padding: 0;
        margin-bottom: var(--sl-spacing-3x-small);
        cursor: default;
    }
"""

make_control!(value::Ref, ::Type{T}, sname::Symbol) where T = error("type $T not supported, add a `StructEditor.make_control!(value::Ref, ::Type{$T}, sname::Symbol)` function to your package.")

function make_control!(value::Ref, ::Type{Bool}, sname::Symbol)
    name = string(sname)
    val = getproperty(value[], sname)

    checkbox = SLCheckbox(name; checked=val)
    on(checkbox.value) do x
        # println(":: checkbox ($name): $x")
        value[] = set(value[], PropertyLens(sname), x)
    end

    return [checkbox]
end

function make_control!(value::Ref, ::Union{Type{<:Number},Type{String}}, sname::Symbol)
    name = string(sname)
    val = getproperty(value[], sname)

    y = SLInput(val; label=name)
    on(y.value) do x
        # println(":: y ($name): $x")
        value[] = set(value[], PropertyLens(sname), x)
    end

    return [y]
end

function make_control!(value::Ref, ::Type{Date}, sname::Symbol)
    name = string(sname)
    val = getproperty(value[], sname)

    y = SLInput(val; label=name)
    on(y.value) do x
        # println(":: y ($name): $x type $(typeof(x))")
        value[] = set(value[], PropertyLens(sname), Date(x))
    end

    return [y]
end

function make_control!(value::Ref, ::Type{Markdown.MD}, sname::Symbol)
    name = string(sname)
    val = getproperty(value[], sname)
    
    sval = Markdown.plain(val)
    y = SLTextarea(sval; label=name, rows=max(5, min(count('\n', sval) + 1, 20)))
    on(y.value) do x
        # println(":: y ($name): $x type $(typeof(x))")
        value[] = set(value[], PropertyLens(sname), Markdown.parse(x))
    end

    return [y]
end

function make_control!(value::Ref, ::Type{<:Vector}, sname::Symbol)
    name = string(sname)
    val = getproperty(value[], sname)

    dialogs = []

    items = SLTreeItem[]
    
    for (i,item) in enumerate(val)
        label = "$i : $(typeof(item))"
        push!(items, SLTreeItem(label))
        ref = Ref(val[i])
        dialog = SLDialog(make_form(ref; file=""); label)

        on(dialog.open) do o
            if !o
                # update item...
                getproperty(value[], sname)[i] = ref[]
            end
        end

        push!(dialogs, dialog)
    end
    label = DOM.label(name; class="shoelace-label")
    y = SLTree(items)
    on(y.value) do x
        # println(":: y ($name): $x type $(typeof(x))")
        i = tryparse(Int, strip(split(x, ':')[1]))
        if !isnothing(i)
            dialogs[i].open[] = true
        end
    end

    return [label, y, dialogs...]
end




function make_form(value::Ref{T}; file="value.json", padding=25, width=500) where T

    form = []
    
    for (sname, ftype) in zip(fieldnames(T), fieldtypes(T))
        append!(form, make_control!(value, ftype, sname))
    end


    if !isempty(file)
        save = SLButton("save")
        on(save.value) do x
            open(file, "w") do io
                JSON.json(io, value[]; pretty=true)
            end
        end

        # TODO: maybe implement this, complication arrises because the order of editors is linked to the `form` vector, but this prevents adding any non-control elements
        # load = SLButton("load")
        # on(load.value) do x
        #     value[] = open(file) do io
        #         JSON3.read(io, T)
        #     end
            
        #     for (sname, ftype, f) in zip(fieldnames(T), fieldtypes(T), form)
        #         name = string(sname)
        #         val = getproperty(value[], sname)
        #         # println("$name = $val")
        #         if val isa Date
        #             val = string(val)
        #         end
        #         if val isa Markdown.MD
        #             val = Markdown.plain(val)
        #             f.rows[] = min(count('\n', val) + 1, 20)
        #         end
        #         f.value[] = val
        #     end
        
        # end

        return DOM.div(form..., DOM.hr(), save; style="padding:$(padding)px; max-width:$(width)px")
    else
        return DOM.div(form...)
    end
end

function make_form(file::String, T::Type)
    value = JSON.parsefile(file, T)
    return make_form(Ref(value); file)
end

@enum Mode vscode browser

function editor(file::String, T::Type; mode=vscode, kwargs...)
    value = JSON.parsefile(file, T)
    return editor(value; file, mode, kwargs...)
end

function editor(value::T; file="value.json", mode=vscode, kwargs...) where T

    form = make_form(Ref(value); file, kwargs...)

    app = App() do session
        DOM.html(
            DOM.head(
                get_shoelace()...,
                DOM.style(STYLE_CSS)
            ),
            DOM.body(
                form
            )
        )
    end

    if mode == vscode
        return app
    elseif mode == browser
        server = Bonito.Server(app, "0.0.0.0", 8080)                                                                                                                             
        Bonito.HTTPServer.openurl(Bonito.HTTPServer.local_url(server, ""))         
        return nothing
    end

end

end # module StructEditor
