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

export editor, viewer

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

    body {
        min-height: 100vh;
        margin: 0;
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

        dirty(true)
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

        
        dirty(true)
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
        
        dirty(true)
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

        dirty(true)
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

        dirty(true)
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

        
        dirty(true)
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

        dirty(true)
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
        
        dirty(true)
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

        container=DOM.div
        form = build_fields(ref,
            (v, key) -> make_control!(v, key, dirty),
            (v, ftype, name) -> make_control!(v, ftype, name, dirty),
            container)


        y = sl_card(form; style="width:100%;")

        on(ref) do x
            if ismutable(value[])
                setproperty!(value[], sname, ref[])
            else
                value[] = set(value[], PropertyLens(sname), ref[])
            end

            dirty(true)
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


# -----------------------------------------------------------------------------
# make_view! : read-only counterpart to make_control!
#
# Instead of an interactive control, each method renders the field's value as
# plain, labelled text and subscribes to `value` so the display updates whenever
# the Observable is notified (e.g. a parent struct changing). Signature mirrors
# make_control! minus `dirty` (a view never marks anything dirty).
# -----------------------------------------------------------------------------

"""
    view_field(value::Observable, sname::Symbol, format=string)

Render field `sname` of `value[]` as a label + reactive text value, matching the
`.shoelace-label` / `.shoelace-help` styling used by the editor controls. `format`
converts the field value to the displayed string. Reused by the scalar
`make_view!` methods.
"""
function view_field(value::Observable, sname::Symbol, format=string)
    name = string(sname)
    h = help(typeof(value[]), Val(sname))

    text = Observable{String}(format(getproperty(value[], sname)))
    on(value) do v
        text[] = format(getproperty(v, sname))
    end

    parts = Any[DOM.div(name; class="shoelace-label"), DOM.div(text)]
    isempty(h) || push!(parts, DOM.div(h; class="shoelace-help"))
    return parts
end

make_view!(value::Observable, ::Type{Bool}, sname::Symbol) = view_field(value, sname)
make_view!(value::Observable, ::Type{Missing}, sname::Symbol) = view_field(value, sname)
make_view!(value::Observable, ::Type{<:Number}, sname::Symbol) = view_field(value, sname)
make_view!(value::Observable, ::Type{String}, sname::Symbol) = view_field(value, sname)
make_view!(value::Observable, ::Type{Symbol}, sname::Symbol) = view_field(value, sname)
make_view!(value::Observable, ::Type{<:Base.Enum}, sname::Symbol) = view_field(value, sname)
make_view!(value::Observable, ::Type{Date}, sname::Symbol) = view_field(value, sname)
make_view!(value::Observable, ::Type{Vector{T}}, sname::Symbol) where T <: Number =
    view_field(value, sname, v -> join(string.(v), ", "))

function make_view!(value::Observable, ::Type{Markdown.MD}, sname::Symbol)
    name = string(sname)
    h = help(typeof(value[]), Val(sname))

    md = Observable{Any}(getproperty(value[], sname))
    on(value) do v
        md[] = getproperty(v, sname)
    end

    parts = Any[DOM.div(name; class="shoelace-label"), DOM.div(md)]
    isempty(h) || push!(parts, DOM.div(h; class="shoelace-help"))
    return parts
end

function make_view!(value::Observable, ::Type{<:Vector}, sname::Symbol)
    name = string(sname)
    h = help(typeof(value[]), Val(sname))

    items = Observable{Any}(getproperty(value[], sname))
    on(value) do v
        items[] = getproperty(v, sname)
    end

    # rebuild the (read-only) list whenever the vector changes; composite
    # elements recurse into make_view, scalars render as plain text.
    list = map(items) do vec
        rows = map(vec) do item
            if iscomposite(typeof(item))
                sl_card(make_view(Observable(item); class="", container=DOM.div); style="width:100%; padding: 2px")
            else
                DOM.div(string(item))
            end
        end
        DOM.div(rows...)
    end

    parts = Any[DOM.div(name; class="shoelace-label"), DOM.div(list)]
    isempty(h) || push!(parts, DOM.div(h; class="shoelace-help"))
    return parts
end

function make_view!(value::Observable, ::Type{T}, sname::Symbol) where T
    if iscomposite(T)
        name = string(sname)
        val = getproperty(value[], sname)
        ref = Observable(val)
        on(value) do v
            ref[] = getproperty(v, sname)
        end

        label = DOM.div(name; class="shoelace-label")
        y = sl_card(make_view(ref; class="", container=DOM.div); style="width:100%;")
        return [label, DOM.div(y)]
    else
        error("type $T not supported for viewing, add a `StructEditor.make_view!(value::Observable, ::Type{$T}, sname::Symbol)` function to your package.")
    end
end

"""
    make_view!(value::Observable, ::Val)

Field-specific dispatch hook (mirrors the `make_control!(::Val)` hook). The generic
definition returns `nothing`, falling through to the type-based `make_view!`.
"""
make_view!(value::Observable, ::Val) = nothing


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

"""
    SaveFunction(; file=nothing, func=nothing)

Describes what an [`editor`](@ref)'s `save` button does. Supplying a `SaveFunction` to
`editor` (or `make_form`) is what enables the save button; both fields default to `nothing`:

- `file`: path to the JSON file `value` is written to on save
- `func`: a zero-argument function called on save (e.g. to trigger downstream side effects)

Pass either or both.
"""
@kwdef struct SaveFunction
    file::Union{String,Nothing} = nothing
    func::Union{Function,Nothing} = nothing
end

"""
    build_fields(value::Observable, val_fn, type_fn, container)

Iterate the fields of `value[]`, building the parts for each. `val_fn(value, Val(name))`
(field-specific dispatch) is tried first; if it returns `nothing`, the type-based
`type_fn(value, ftype, name)` is used. Each field's parts are wrapped with `container`.
Shared by `make_form` (editor controls) and `make_view` (read-only views).
"""
function build_fields(value::Observable{T}, val_fn, type_fn, container) where T
    form = []
    for name in propertynames(value[])
        skip_field(T, Val(name)) && continue

        ftype = hasfield(T, name) ? fieldtype(T, name) : typeof(getproperty(value[], name))

        parts = val_fn(value, Val(name))          # try field-specific first
        if isnothing(parts)
            parts = type_fn(value, ftype, name)   # fall to generic type
        end

        push!(form, container(parts...))
    end
    return form
end

"""
    make_form(value::Observable{T}; save_function=nothing, class="centered", container=cell, buttons=[]) where T

Builds a `div::Hyperscript.Node` containing a form editor of struct `value::T`.  The struct `value` must be wrapped in an `Observable`.

## kwargs
- `save_function::Union{SaveFunction, Nothing}=nothing`: when a [`SaveFunction`](@ref) is given, a `save` button writes to its json `file` (if not nothing) and/or calls its `func` (if not nothing); when `nothing` the save button is not included
- `class="centered"`: the CSS class to style the form, "centered" is built-in
- `container=cell`: the function that each struct field control is wrapped with (for example `DOM.div`), `cell` is built-in
- `buttons=[]`: add additional buttons along side `save` thru this keyword
"""
function make_form(value::Observable{T}; save_function::Union{SaveFunction, Nothing}=nothing, class="centered", container=cell,  buttons=[]) where T

    dirty = identity

    if !isnothing(save_function)
        save_button = SLButton("save"; variant="primary", disabled=true)

        function dirty(x::Bool)
            save_button.disabled[] = !x
            notify(value)
        end

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



    form = build_fields(value,
        (v, key) -> make_control!(v, key, dirty),
        (v, ftype, name) -> make_control!(v, ftype, name, dirty),
        container)

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

"""
    make_view(value::Observable{T}; class="centered", container=cell) where T

Builds a `div::Hyperscript.Node` displaying (read-only) the struct `value::T`. The
view counterpart to [`make_form`](@ref): each field is rendered via `make_view!` and
updates reactively when `value` is notified. The struct `value` must be wrapped in an
`Observable`.

## kwargs
- `class="centered"`: the CSS class to style the view, "centered" is built-in
- `container=cell`: the function that each field's parts are wrapped with (for example `DOM.div`), `cell` is built-in
"""
function make_view(value::Observable{T}; class="centered", container=cell) where T
    form = build_fields(value, make_view!, make_view!, container)
    return DOM.div(form...; class)
end

function make_view(file::String, T::Type)
    value = JSON.parsefile(file, T)
    return make_view(Observable(value))
end

@enum Mode vscode browser online quite

# Wrap a form/view node in the standard HTML page (title, shoelace assets, style, favicon).
function page(form; title, icon)
    DOM.html(
        DOM.head(
            DOM.title(title),
            get_shoelace()...,
            DOM.style(STYLE_CSS),
            DOM.link(; rel="icon", type="image/svg+xml", href=icon)
        ),
        DOM.body(
            form
        )
    )
end

# Serve/return an App according to `mode`. Shared by editor and viewer.
function run_app(app; mode, server, path)
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

"""
    editor(value; save_function=nothing, mode=vscode, server=nothing, path="/", icon, title, kwargs...)
    editor(file::String, T::Type; mode=vscode, kwargs...)

Opens an interactive editor for struct `value` (or for a value of type `T` loaded from the
JSON `file`). The second form auto-creates a `SaveFunction` targeting `file`, so edits save
back to it.

## kwargs
- `save_function::Union{SaveFunction, Nothing}=nothing`: see [`SaveFunction`](@ref); when `nothing` no save button is shown
- `mode`: one of `StructEditor.vscode` (default), `browser`, `online`, or `quite`
- `server`: an optional `Bonito.Server` to route the app onto
- `path="/"`: route path when serving
- `icon`: favicon URL (default https://icons.getbootstrap.com/assets/icons/pencil.svg)
- `title=string(T)`: page title

Remaining keywords (`class`, `container`, `buttons`) are forwarded to [`make_form`](@ref).
See also [`viewer`](@ref) for a read-only display.
"""
function editor(file::String, T::Type; mode=vscode, kwargs...)
    value = JSON.parsefile(file, T)
    save_function=SaveFunction(;file)
    return editor(value; save_function, mode, kwargs...)
end

function editor(value::T; save_function::Union{SaveFunction, Nothing}=nothing, mode=vscode, server = nothing, path="/", icon="https://icons.getbootstrap.com/assets/icons/pencil.svg", title=string(T), kwargs...) where T

    app = App() do session

        # Build the form (and its widgets/Observables) fresh per session. Bonito
        # widgets carry mutable per-session state, so a form shared across sessions
        # breaks on the 2nd open (e.g. an SLSelect's value binding collides and the
        # client sends NaN on change). Constructing inside the closure isolates each open.
        obs_value = Observable(value)
        form = make_form(obs_value; save_function, kwargs...)

        page(form; title, icon)
    end

    return run_app(app; mode, server, path)
end

"""
    viewer(value; mode=vscode, server=nothing, path="/", icon, title, kwargs...)
    viewer(file::String, T::Type; mode=vscode, kwargs...)

Opens a read-only display of struct `value` (or a value of type `T` loaded from the JSON
`file`). The read-only counterpart to [`editor`](@ref): each field is rendered as labelled
text via [`make_view!`](@ref) instead of an editing control, and there is no save button.

## kwargs
- `mode`: one of `StructEditor.vscode` (default), `browser`, `online`, or `quite`
- `server`: an optional `Bonito.Server` to route the app onto
- `path="/"`: route path when serving
- `icon`: favicon URL (default https://icons.getbootstrap.com/assets/icons/eye.svg)
- `title=string(T)`: page title

Remaining keywords (`class`, `container`) are forwarded to [`make_view`](@ref).
"""
function viewer(file::String, T::Type; mode=vscode, kwargs...)
    value = JSON.parsefile(file, T)
    return viewer(value; mode, kwargs...)
end

function viewer(value::T; mode=vscode, server = nothing, path="/", icon="https://icons.getbootstrap.com/assets/icons/eye.svg", title=string(T), kwargs...) where T

    app = App() do session

        # Fresh Observables per session (same rationale as `editor`).
        obs_value = Observable(value)
        form = make_view(obs_value; kwargs...)

        page(form; title, icon)
    end

    return run_app(app; mode, server, path)
end

end # module StructEditor
