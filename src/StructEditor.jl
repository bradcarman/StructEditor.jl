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

function make_control!(value::Observable, ::Type{Bool}, sname::Symbol, dirty=identity)
    name = string(sname)
    val = getproperty(value[], sname)
    h = help(typeof(value[]), Val(sname) )

    checkbox = SLCheckbox(name; checked=val, help=h)
    on(checkbox.value) do x
        # println(":: checkbox ($name): $x")
        if ismutable(value[])
            setproperty!(value[], sname, x)
        else
            value[] = set(value[], PropertyLens(sname), x)
        end

        if dirty isa Function
            dirty(true)
        end
    end

    return [checkbox]
end

function make_control!(value::Observable, ::Type{Missing}, sname::Symbol, dirty=identity)
    name = string(sname)
    val = getproperty(value[], sname)
    h = help(typeof(value[]), Val(sname) )

    x = SLInput("missing"; label=name, help=h, disabled=true)

    return [x]
end

function make_control!(value::Observable, ::Type{T}, sname::Symbol, dirty=identity) where T <: Number
    name = string(sname)
    val = getproperty(value[], sname)
    h = help(typeof(value[]), Val(sname) )
    
    y = SLInput(val; label=name, help=h)
    on(y.value) do x
        # println(":: y ($name): $x")
        if ismutable(value[])
            setproperty!(value[], sname, T(x))
        else
            value[] = set(value[], PropertyLens(sname), T(x))
        end

        if dirty isa Function
            dirty(true)
        end
    end

    return [y]
end

function make_control!(value::Observable, ::Type{String}, sname::Symbol, dirty=identity)
    name = string(sname)
    val = getproperty(value[], sname)
    h = help(typeof(value[]), Val(sname) )

    y = SLInput(val; label=name, help=h)
    on(y.value) do x
        # println(":: y ($name): $x")
        if ismutable(value[])
            setproperty!(value[], sname, x)
        else
            value[] = set(value[], PropertyLens(sname), x)
        end

        if dirty isa Function
            dirty(true)
        end
    end

    return [y]
end

function make_control!(value::Observable, ::Type{Symbol}, sname::Symbol, dirty=identity)
    name = string(sname)
    val = getproperty(value[], sname)
    h = help(typeof(value[]), Val(sname) )

    y = SLInput(string(val); label=name, help=h)
    on(y.value) do x
        # println(":: y ($name): $x")
        if ismutable(value[])
            setproperty!(value[], sname, Symbol(x))
        else
            value[] = set(value[], PropertyLens(sname), Symbol(x))
        end

        if dirty isa Function
            dirty(true)
        end
    end

    return [y]
end

function make_control!(value::Observable, ::Type{T}, sname::Symbol, dirty=identity) where T <: Base.Enum
    name = string(sname)
    val = getproperty(value[], sname)
    h = help(typeof(value[]), Val(sname) )

    opts = instances(T)
    select = SLSelect([string(x) for x in opts]; label=name, help=h)
    select.index[] = something(findfirst(==(val), opts), 1)

    on(select.index) do i
        # println(":: select ($name): $i")
        i < 1 && return
        newval = opts[i]
        if ismutable(value[])
            setproperty!(value[], sname, newval)
        else
            value[] = set(value[], PropertyLens(sname), newval)
        end

        if dirty isa Function
            dirty(true)
        end
    end

    return [select]
end

function make_control!(value::Observable, ::Type{Date}, sname::Symbol, dirty=identity)
    name = string(sname)
    val = getproperty(value[], sname)
    h = help(typeof(value[]), Val(sname) )

    y = SLInput(val; label=name, help=h)
    on(y.value) do x
        # println(":: y ($name): $x type $(typeof(x))")
        if ismutable(value[])
            setproperty!(value[], sname, Date(x))
        else
            value[] = set(value[], PropertyLens(sname), Date(x))
        end

        if dirty isa Function
            dirty(true)
        end
    end

    return [y]
end

function make_control!(value::Observable, ::Type{Markdown.MD}, sname::Symbol, dirty=identity)
    name = string(sname)
    val = getproperty(value[], sname)
    h = help(typeof(value[]), Val(sname) )
    
    sval = Markdown.plain(val)
    y = SLTextarea(sval; label=name, rows=max(5, min(count('\n', sval) + 1, 20)), help=h)
    on(y.value) do x
        # println(":: y ($name): $x type $(typeof(x))")
        if ismutable(value[])
            setproperty!(value[], sname, Markdown.parse(x))
        else
            value[] = set(value[], PropertyLens(sname), Markdown.parse(x))
        end

        if dirty isa Function
            dirty(true)
        end
    end

    return [y]
end

function make_control!(value::Observable, ::Type{Vector{T}}, sname::Symbol, dirty=identity) where T <: Number
    name = string(sname)
    val = getproperty(value[], sname)
    h = help(typeof(value[]), Val(sname) )

    y = SLInput(join(string.(val),','); label=name, help=h)
    on(y.value) do data
        # println(":: y ($name): $x")
        if ismutable(value[])
            if isempty(data)
                setproperty!(value[], sname, T[])
            else
                setproperty!(value[], sname, map(x->parse(T, x), split(data,',')))
            end
        else
            value[] = if isempty(data)
                set(value[], PropertyLens(sname), T[])
            else
                set(value[], PropertyLens(sname), map(x->parse(T, x), split(data,',')))
            end
        end
        
        if dirty isa Function
            dirty(true)
        end
    end

    return [y]
end

function make_control!(value::Observable, ::Type{<:Vector}, sname::Symbol, dirty=identity)
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
                dialog.value[] = make_form(ref; class="")
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
                notify(value) # also notify the parent that the list changed
                y.index = i
                dirty(true)
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
        dirty(true)
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
            dirty(true)
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

    return [y, DOM.div(add, edit, delete), dialog]
end

function iscomposite(T::Type)
    n = 0
    try
        n = length(fieldnames(T))
    catch err
        if err isa MethodError
            # OK, likely something like MethodError: no method matching fieldnames(::Type{Union{Nothing, String}})
            # not a composite type
            # n = 0
        else
            rethrow(err)
        end
    end

    return n > 0
end

function make_control!(value::Observable, ::Type{T}, sname::Symbol, dirty=identity) where T
    if iscomposite(T) > 0
        name = string(sname)
        val = getproperty(value[], sname)
        ref = Observable(val) 
        label = DOM.div(name; class="shoelace-label")
        y = sl_card(make_form(ref; class="", container=DOM.div); style="width:100%;")

        on(ref) do x
            if ismutable(value[])
                setproperty!(value[], sname, ref[])
            else
                value[] = set(value[], PropertyLens(sname), ref[])
            end

            if dirty isa Function
                dirty(true)
            end
        end

        return [label, DOM.div(y)]
    else
        error("type $T not supported, add a `StructEditor.make_control!(value::Observable, ::Type{$T}, sname::Symbol, dirty=identity)` function to your package.")
    end
end

"""
    make_control!(value::Observable, ::Val, dirty=identity)

Defined to dispatch to a specific field `Val(field)`, generic definition defaults to nothing and falls to `make_control!(value::Observable, ::Type{T}, sname::Symbol) where T`
"""
make_control!(value::Observable, ::Val, dirty=identity) = nothing


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

@kwdef struct SaveFunction
    file::Union{String,Nothing} = nothing
    func::Union{Function,Nothing} = nothing
end

"""
    make_form(value::Observable{T}; file="", class="centered", container=cell, buttons=[]) where T

Builds a `div::Hyperscript.Node` containing a form editor of struct `value::T`.  The struct `value` must be wrapped in an `Observable`.

## kwargs
- `save_button::Union{SaveFunction, Nothing}=nothing`: outputs to json `file` path if not nothing and/or calls function `func` if not nothing, if set to nothing save button is not included
- `class="centered"`: the CSS class to style the form, "centered" is built-in
- `container=cell`: the function that each struct field control is wrapped with (for example `DOM.div`), `cell` is built-in
- `buttons=[]`: add additional buttons along side `save` thru this keyword
"""
function make_form(value::Observable{T}; save_function::Union{SaveFunction, Nothing}=nothing, class="centered", container=cell,  buttons=[]) where T

    form = []

    pnames = propertynames(value[])


    dirty = identity
    
    if !isnothing(save_function)
        save_button = SLButton("save"; variant="primary", disabled=true)

        dirty(x::Bool) = save_button.disabled[] = !x

        on(save_button.value) do x
            save_button.loading[] = true
            try
                if !isnothing(save_function.file)
                    open(save_function.file, "w") do io
                        JSON.json(io, value[]; pretty=true)
                    end
                end

                if !isnothing(save_function.func)
                    save_function.func()
                end    

                save_button.disabled[] = true
            catch err
                @error "Save failed" exception=(err, catch_backtrace())
            finally
                save_button.loading[] = false
            end
        end

        push!(buttons, save_button)
    end



    for name in pnames
        if !skip_field(T, Val(name))

            ftype = if hasfield(T, name)
                fieldtype(T, name)
            else
                typeof(getproperty(value[], name))
            end

            # try specific field first
            parts = make_control!(value, Val(name), dirty)
                
            # if nothing fall to generic type
            if isnothing(parts)
                parts = make_control!(value, ftype, name, dirty)
            end

            push!(form, container(parts...))
        end
    end



    if !isempty(buttons)
        return DOM.div(form..., DOM.hr(), buttons...; class)
    else
        return DOM.div(form...; class)
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

function make_form(file::String, T::Type)
    value = JSON.parsefile(file, T)
    return make_form(Observable(value); file)
end

@enum Mode vscode browser online quite

function editor(file::String, T::Type; mode=vscode, kwargs...)
    value = JSON.parsefile(file, T)
    save_function=SaveFunction(;file)
    return editor(value; save_function, mode, kwargs...)
end

function editor(value::T; save_function::Union{SaveFunction, Nothing}=nothing, mode=vscode, server = nothing, path="/", icon="https://icons.getbootstrap.com/assets/icons/pencil.svg", kwargs...) where T

    obs_value = Observable(value)
    form = make_form(obs_value; save_function, kwargs...)
   
    app = App() do session

        DOM.html(
            DOM.head(
                get_shoelace()...,
                DOM.style(STYLE_CSS),
                DOM.link(; rel="icon", type="image/svg+xml", href=icon)
            ),
            DOM.body(
                form
            )
        )
    end

    if !isnothing(server)
        route!(server, path => app);
    end

    if mode == vscode
        return app
    elseif mode == browser 
        if isnothing(server)
            server = Bonito.Server(app, "0.0.0.0", 8080)   
        end                                                                                                                      
        Bonito.HTTPServer.openurl(Bonito.HTTPServer.local_url(server, path))         
        return nothing
    elseif mode == online
        url = Bonito.HTTPServer.online_url(server, path)
        return url
    elseif mode == quite
        return nothing
    end

end

end # module StructEditor
