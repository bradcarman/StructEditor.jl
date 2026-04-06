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

export editor, AbstractStructEditor

abstract type AbstractStructEditor end

const STYLE_CSS = """

    .centered {
        width: 85vw;
        margin-inline: auto; /* Shorthand for margin-left: auto and margin-right: auto */
        
        /* Optional: Adds a "safety" so it doesn't get too wide on massive screens */
        max-width: 1200px; 
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

    .shoelace-help {
        /* Default text color for help text */
        color: var(--sl-input-help-text-color); 
        
        /* Use the size that matches your form control (medium is default) */
        font-size: var(--sl-input-help-text-font-size-medium); 
        
        /* Add a tiny bit of spacing to separate it from the input */
        margin-top: var(--sl-spacing-3x-small); 
        
        /* Standard Shoelace typography adjustments */
        font-family: var(--sl-font-sans);
        font-weight: var(--sl-font-weight-normal);
        line-height: var(--sl-line-height-normal);
    }
"""

help(::Type, ::Val) = ""
make_control!(value::Observable, ::Type{T}, sname::Symbol) where T = error("type $T not supported, add a `StructEditor.make_control!(value::Observable, ::Type{$T}, sname::Symbol)` function to your package.")

function make_control!(value::Observable, ::Type{Bool}, sname::Symbol)
    name = string(sname)
    val = getproperty(value[], sname)
    h = help(typeof(value[]), Val(sname) )

    checkbox = SLCheckbox(name; checked=val, help=h)
    on(checkbox.value) do x
        # println(":: checkbox ($name): $x")
        value[] = set(value[], PropertyLens(sname), x)
    end

    return [checkbox]
end

function make_control!(value::Observable, ::Union{Type{<:Number},Type{String}}, sname::Symbol)
    name = string(sname)
    val = getproperty(value[], sname)
    h = help(typeof(value[]), Val(sname) )

    y = SLInput(val; label=name, help=h)
    on(y.value) do x
        # println(":: y ($name): $x")
        value[] = set(value[], PropertyLens(sname), x)
    end

    return [y]
end

function make_control!(value::Observable, ::Type{Symbol}, sname::Symbol)
    name = string(sname)
    val = getproperty(value[], sname)
    h = help(typeof(value[]), Val(sname) )

    y = SLInput(string(val); label=name, help=h)
    on(y.value) do x
        # println(":: y ($name): $x")
        value[] = set(value[], PropertyLens(sname), Symbol(x))
    end

    return [y]
end

function make_control!(value::Observable, ::Type{Date}, sname::Symbol)
    name = string(sname)
    val = getproperty(value[], sname)
    h = help(typeof(value[]), Val(sname) )

    y = SLInput(val; label=name, help=h)
    on(y.value) do x
        # println(":: y ($name): $x type $(typeof(x))")
        value[] = set(value[], PropertyLens(sname), Date(x))
    end

    return [y]
end

function make_control!(value::Observable, ::Type{Markdown.MD}, sname::Symbol)
    name = string(sname)
    val = getproperty(value[], sname)
    h = help(typeof(value[]), Val(sname) )
    
    sval = Markdown.plain(val)
    y = SLTextarea(sval; label=name, rows=max(5, min(count('\n', sval) + 1, 20)), help=h)
    on(y.value) do x
        # println(":: y ($name): $x type $(typeof(x))")
        value[] = set(value[], PropertyLens(sname), Markdown.parse(x))
    end

    return [y]
end

function make_control!(value::Observable, ::Type{Vector{T}}, sname::Symbol) where T <: Number
    name = string(sname)
    val = getproperty(value[], sname)
    h = help(typeof(value[]), Val(sname) )

    y = SLInput(join(string.(val),','); label=name, help=h)
    on(y.value) do data
        # println(":: y ($name): $x")
        value[] = set(value[], PropertyLens(sname), map(x->parse(T, x), split(data,',')))
    end

    return [y]
end

function make_control!(value::Observable, ::Type{<:Vector}, sname::Symbol)
    name = string(sname)
    val = getproperty(value[], sname)
    T = eltype(val)
    h = help(typeof(value[]), Val(sname))

    i=1 
    ref = Observable{T}()
    
    dialog = SLDialog(DOM.div("---"); label=string(T), style="--width: 75vw;")



    items = SLListItem[]
    
    for (i,item) in enumerate(val)
        label = "$item"
        push!(items, SLListItem(label))
       
    end
    # label = DOM.label(name; class="shoelace-label")
    y = SLList(items; label=name, help=h)

    updating = false
    on(dialog.open) do o
        if o # dialog opening
            i = y.index    
            if !isnothing(i) && (i > 0)
                ref = Observable(val[i])
                dialog.value[] = make_form(ref; file="", class="", container=DOM.div)
            else
                dialog.value[] = DOM.div("error")
            end
        else # dialog closing
            # update item...
            updating = true
            i = y.index    
            if !isnothing(i) && (i > 0)
                getproperty(value[], sname)[i] = ref[]
                insert!(y, i, ShoelaceWidgets.SLListItem("$(ref[])"))
                popat!(y, i+1)
                y.index = i
            end
            updating = false
        end
    end

    # add an item to the list
    add = SLButton("add"; variant="text", size="small")
    on(add.value) do x
        item = T() #<-- type must have a default constructor
        push!(val, item) 
        push!(y, ShoelaceWidgets.SLListItem("$item"))
        y.index = length(val)
    end

    edit = SLButton("edit"; variant="text", size="small", disabled=true)
    on(edit.value) do x
        i = y.index    
        if !isnothing(i) && (i > 0)
            dialog.open[] = true
        end
    end

    delete = SLButton("delete"; variant="text", size="small", disabled=true)
    on(delete.value) do x
        i = y.index    
        if !isnothing(i) && (i > 0)
            popat!(val, i)
            popat!(y, i)
            notify(y.value)
        end
    end

    # selection changed, open editor
    on(y.value) do x
        if !updating
            i = y.index
            if !isnothing(i) && (i > 0)
                delete.disabled[] = false
                edit.disabled[] = false
            else
                delete.disabled[] = true
                edit.disabled[] = true
            end
        end
    end

    return [y, dialog, DOM.div(add, edit, delete)]
end

function StructEditor.make_control!(value::Observable, ::Type{T}, sname::Symbol) where T <: AbstractStructEditor
   name = string(sname)
   val = getproperty(value[], sname)
   ref = Observable(val) 
   label = DOM.div(name; class="shoelace-label")
   y = sl_card(StructEditor.make_form(ref; file="", class="", container=DOM.div); style="width:100%;")

   on(ref) do x
        value[] = set(value[], PropertyLens(sname), ref[])
   end

   return [label, DOM.div(y)]
end

# background-color: var(--sl-color-neutral-50);
skip_field(parent::Type, child::Val) = false
cell(x...) = DOM.div(x...; 
                    style="""
                        width:100%; 
                        border-left: solid 4px var(--sl-color-neutral-200); 
                        margin: 20px 2px;
                        padding: 4px;
                    """
                    )

function make_form(value::Observable{T}; file="value.json", class="centered", container=cell) where T

    form = []
    
    for (sname, ftype) in zip(fieldnames(T), fieldtypes(T))
        if !skip_field(T, Val(sname))
            parts = make_control!(value, ftype, sname)
            push!(form, container(parts...))
        end
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

        return DOM.div(form..., DOM.hr(), save; class)
    else
        return DOM.div(form...; class)
    end
end

function make_form(file::String, T::Type)
    value = JSON.parsefile(file, T)
    return make_form(Observable(value); file)
end

@enum Mode vscode browser

function editor(file::String, T::Type; mode=vscode, kwargs...)
    value = JSON.parsefile(file, T)
    return editor(value; file, mode, kwargs...)
end

function editor(value::T; file="value.json", mode=vscode, kwargs...) where T

    form = make_form(Observable(value); file, kwargs...)

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
