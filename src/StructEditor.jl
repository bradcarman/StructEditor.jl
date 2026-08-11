module StructEditor
using Dates
using Markdown
using ShoelaceWidgets
using ShoelaceWidgets: get_values, replace_selected!, Open, OK
using Bonito
using Accessors
using JSON
using StructUtils

struct ApplicationState{T}
    value::Observable{T}
    memory::Dict
end

ApplicationState(v::Observable) = ApplicationState(v, Dict())
ApplicationState(x::T) where T = ApplicationState(Observable(v))

StructUtils.structlike(::StructUtils.StructStyle, ::Type{Markdown.MD}) = false
StructUtils.lower(md::Markdown.MD) = Markdown.plain(md)
StructUtils.lift(::Type{Markdown.MD}, s::AbstractString) = Markdown.parse(s)

export editor, viewer, ApplicationState

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
field_label(::Type, ::Val{S}) where S = string(S)

change_callback(state::ApplicationState{T}, ::Val) where T = nothing

"""
    bind_field!(state::ApplicationState, sname::Symbol, wvalue::Observable, dirty=identity;
                to_field=identity, to_widget=identity, valid=(x -> true), same=...)

Two-way bind a widget's value Observable `wvalue` to field `sname` of the struct held by
`value`. Every `make_control!` method binds through here, so a control both writes its
field and re-seeds itself whenever `value` changes from elsewhere: a parent struct, a
file load, or the `ListManager` item dialog re-seeding its form.

- `to_field(wval)` converts what the widget fires into the field's type
- `to_widget(field)` is the inverse, converting the field into what the widget holds
- `valid(wval)` rejects widget values that must not be written (e.g. a cleared selection)
- `same(field, wval)` asks whether the widget already represents that field value

`same` is what breaks the update cycle. Both handlers bail out when it holds, so the echo
from the opposite direction terminates instead of recursing, and a programmatic change to
`value` does not mark the form dirty. It defaults to comparing in widget space, which
assumes `to_widget ∘ to_field` round-trips; where that does not hold (`Markdown.MD`, whose
`to_widget` reformats the text) pass a comparison in field space instead.
"""
function bind_field!(state::ApplicationState, sname::Symbol, wvalue::Observable, dirty=identity;
                     to_field=identity,
                     to_widget=identity,
                     valid=(x -> true),
                     same=(field, wval) -> isequal(to_widget(field), wval)
                     )

    value = state.value

    # The field value this binding last saw. `value` notifies whenever *any* field
    # changes, so the sync below must react only when its own field actually moved.
    # Without this it also fires on a notify raised mid-edit -- while the widget has
    # already changed but this binding has not written the field yet -- reads the
    # stale field as authoritative, and pushes it back over the user's input.
    seen = Ref{Any}(getproperty(value[], sname))

    # calls to_field
    on(wvalue) do x
        valid(x) || return
        field = getproperty(value[], sname)
        same(field, x) && return  # echo of the sync below

        new = to_field(x)
        seen[] = new              # this binding is the author of the change
        if ismutable(value[])
            setproperty!(value[], sname, new)
        else
            value[] = set(value[], PropertyLens(sname), new)
        end

        change_callback(state, Val(sname))
        dirty(true)
    end

    # this binding's field changed elsewhere, so re-seed the widget from it
    # calls to_widget
    on(value) do v
        field = getproperty(v, sname)
        isequal(seen[], field) && return  # some other field moved, not ours
        seen[] = field

        same(field, wvalue[]) || (wvalue[] = to_widget(field))
    end

    return wvalue
end





function make_control!(state::ApplicationState, ::Type{Bool}, sname::Symbol, dirty=identity)
    value_type = typeof(state.value[])
    name = field_label(value_type, Val(sname))
    val = getproperty(state.value[], sname)
    h = help(value_type, Val(sname) )
    
    checkbox = SLCheckbox(name; checked=val, help=h)
    bind_field!(state, sname, checkbox.value, dirty)

    return [checkbox]
end

function make_control!(state::ApplicationState, ::Type{Missing}, sname::Symbol, dirty=identity)
    value_type = typeof(state.value[])
    name = field_label(value_type, Val(sname))
    val = getproperty(state.value[], sname)
    h = help(value_type, Val(sname) )

    x = SLInput("missing"; label=name, help=h, disabled=true)

    return [x]
end

function make_control!(state::ApplicationState, ::Type{T}, sname::Symbol, dirty=identity) where T <: Number
    value_type = typeof(state.value[])
    name = field_label(value_type, Val(sname))
    val = getproperty(state.value[], sname)
    h = help(value_type, Val(sname) )

    
    y = SLInput(val; label=name, help=h, select_on_focus=true)
    bind_field!(state, sname, y.value, dirty; to_field=T)

    return [y]
end

function make_control!(state::ApplicationState, ::Type{String}, sname::Symbol, dirty=identity)
    value_type = typeof(state.value[])
    name = field_label(value_type, Val(sname))
    val = getproperty(state.value[], sname)
    h = help(value_type, Val(sname) )

    y = SLInput(val; label=name, help=h, select_on_focus=true)
    bind_field!(state, sname, y.value, dirty)

    return [y]
end

function make_control!(state::ApplicationState, ::Type{Symbol}, sname::Symbol, dirty=identity)
    value_type = typeof(state.value[])
    name = field_label(value_type, Val(sname))
    val = getproperty(state.value[], sname)
    h = help(value_type, Val(sname) )

    y = SLInput(string(val); label=name, help=h, select_on_focus=true)
    bind_field!(state, sname, y.value, dirty; to_field=Symbol, to_widget=string)

    return [y]
end

function make_control!(state::ApplicationState, ::Type{T}, sname::Symbol, dirty=identity) where T <: Base.Enum
    value_type = typeof(state.value[])
    name = field_label(value_type, Val(sname))
    val = getproperty(state.value[], sname)
    h = help(value_type, Val(sname) )

    opts = instances(T)
    select = SLSelect([string(x) for x in opts]; label=name, help=h)
    select.index[] = something(findfirst(==(val), opts), 1)

    # widget space here is the 1-based option index; `valid` keeps a cleared selection
    # (index 0) from indexing `opts` out of bounds
    bind_field!(state, sname, select.index, dirty;
                to_field = i -> opts[i],
                to_widget = v -> something(findfirst(==(v), opts), 1),
                valid = i -> 1 <= i <= length(opts))

    return [select]
end

function make_control!(state::ApplicationState, ::Type{Date}, sname::Symbol, dirty=identity)
    value_type = typeof(state.value[])
    name = field_label(value_type, Val(sname))
    val = getproperty(state.value[], sname)
    h = help(value_type, Val(sname) )

    # SLInput(::Date) builds an SLInput{String}, so widget space is the date string
    y = SLInput(val; label=name, help=h)
    bind_field!(state, sname, y.value, dirty; to_field=Date, to_widget=string)

    return [y]
end

function make_control!(state::ApplicationState, ::Type{Markdown.MD}, sname::Symbol, dirty=identity)
    value_type = typeof(state.value[])
    name = field_label(value_type, Val(sname))
    val = getproperty(state.value[], sname)
    h = help(value_type, Val(sname) )
    
    sval = Markdown.plain(val)
    y = SLTextarea(sval; label=name, rows=max(5, min(count('\n', sval) + 1, 20)), help=h)

    # Markdown.plain reformats, so the widget-space default would rewrite the user's text
    # back at them on every commit; comparing parsed values keeps what they typed
    bind_field!(state, sname, y.value, dirty;
                to_field = Markdown.parse,
                to_widget = Markdown.plain,
                same = (field, wval) -> isequal(field, Markdown.parse(wval)))

    return [y]
end

function make_control!(state::ApplicationState, ::Type{Vector{T}}, sname::Symbol, dirty=identity) where T <: Number
    value_type = typeof(state.value[])
    name = field_label(value_type, Val(sname))
    val = getproperty(state.value[], sname)
    h = help(value_type, Val(sname) )

    y = SLInput(join(string.(val),','); label=name, help=h)

    bind_field!(state, sname, y.value, dirty;
                to_field = data -> isempty(data) ? T[] : map(x->parse(T, x), split(data,',')),
                to_widget = v -> join(string.(v), ','))

    return [y]
end

# ------------------------------------------------------------
# Support Functions for Vector Add and Edit
# ------------------------------------------------------------
add_function(state::ApplicationState, ::Type{T}, session::Session) where T = T() #add_function(session)::T or add_function(manager, action) on Open ::Hyperscript.Node, on OK ::T
add_mode(::Type{T}) where T = ShoelaceWidgets.FunctionMode
add_content(state::ApplicationState, ::Type{T}) where T = DOM.div()

function edit_function(state::ApplicationState{P}, ::Type{T}, m::ShoelaceWidgets.ListManager, action::ShoelaceWidgets.OpenOKCancel) where {P,T}
    edit_obs = state.memory[Symbol(:edit_, string(P), :_, string(T))]
    if action == ShoelaceWidgets.Open
        edit_obs[] =  ShoelaceWidgets.selected_value(m)
    elseif action == ShoelaceWidgets.OK
        ShoelaceWidgets.replace_selected!(m, edit_obs[])
    end
end
function edit_content(state::ApplicationState{P}, ::Type{T}) where {P,T}
   
    edit_obs = if iscomposite(T)
        Observable(T())
    elseif T <: AbstractString
        Observable("")
    elseif T <: Number
        Observable(T(0))
    else
        error("Add handler for type $T")
    end

    state.memory[Symbol(:edit_, string(P), :_, string(T))] = edit_obs
    
    element_state = ApplicationState(edit_obs, state.memory)

    return make_form(element_state; class="")
end

item_function(x::T) where T = SLListItem(DOM.div(x); object=x)
get_function(::Type{T}, x::SLListItem) where T = x.object

function make_control!(state::ApplicationState, ::Type{<:Vector}, sname::Symbol, dirty=identity)
    value_type = typeof(state.value[])
    name = field_label(value_type, Val(sname))
    val = getproperty(state.value[], sname)
    h = help(value_type, Val(sname) )

    
    T = eltype(val)
    
    

    edit_funO = Base.Fix1(edit_function, state)
    edit_funT = Base.Fix1(edit_funO, T)
    edit_contO = Base.Fix1(edit_content, state) # call function, returns DOM.div

    add_funO = Base.Fix1(add_function, state)
    add_funT = Base.Fix1(add_funO, T) # creats a add_function(session) or add_function(m, action)
    add_contO = Base.Fix1(add_content, state) # call function, returns DOM.div


    y = ListManager(val; 
                    label=name,
                    help=h,

                    item_function=item_function,
                    get_function= Base.Fix1(get_function, T),
                    
                    add_mode=add_mode(T),
                    add_function=add_funT,
                    add_content=add_contO(T),

                    edit_function=edit_funT,
                    edit_content=edit_contO(T),
                    
                    dialog_label=string(T),
                    dialog_style="--width: 75vw;",
                    list_style="height: 40vh; overflow-y: auto; padding: 5px; border: 1px solid lightgray;")

    # The same two-way binding `bind_field!` does, but the widget here is the whole
    # list rather than a single value Observable. `seen` holds a *copy* so that a
    # caller mutating the field vector in place (`push!(value[].items, x)`) still
    # registers as a change; aliasing it would compare equal and miss the update.
    seen = Ref{Any}(copy(val))
    updating = false

    # Every structural change (add, delete, clear, reorder, edit commit) notifies
    # `values`, so this one handler covers them all; registering it after construction
    # keeps the initial seeding of `val` from firing a spurious `dirty`.
    on(y.list.values) do _
        updating && return  # mid-rebuild, the list is not a complete value yet

        newval = get_values(y)
        seen[] = copy(newval)
        if ismutable(state.value[])
            setproperty!(state.value[], sname, newval)
        else
            state.value[] = set(state.value[], PropertyLens(sname), newval)
        end

        change_callback(state, Val(sname))
        dirty(true)
    end

    # this field changed elsewhere, so rebuild the list from it
    on(state.value) do v
        field = getproperty(v, sname)
        isequal(seen[], field) && return  # some other field moved, not ours
        seen[] = copy(field)

        i = y.list.index  # rebuilding drops the selection, so put it back
        updating = true
        try
            empty!(y)
            append!(y, field)
        finally
            updating = false
        end
        isnothing(i) || (1 <= i <= length(y)) && (y.list.index = i)
    end

    # # ListManager's own add handler is registered first, so the new item is already
    # # appended by the time this selects it, ready for the edit button
    # on(y.add.value) do session
    #     isnothing(session) && return
    #     isempty(y) || (y.list.index = length(y))
    # end

    return [y]
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

function make_control!(state::ApplicationState, ::Type{T}, sname::Symbol, dirty=identity) where T
    if iscomposite(T) > 0
        value_type = typeof(state.value[])
        name = field_label(value_type, Val(sname))
        val = getproperty(state.value[], sname)
        
        
        ref = ApplicationState(Observable(val), state.memory)
        label = DOM.div(name; class="shoelace-label")

        container=DOM.div
        form = build_fields(ref,
            (v, key) -> make_control!(v, key, dirty),
            (v, ftype, name) -> make_control!(v, ftype, name, dirty),
            container)


        y = sl_card(form; style="width:100%;")

        # `ref` is this field's widget: binding it means a change to `value` re-seeds
        # `ref`, which cascades into the nested controls' own sync handlers
        bind_field!(state, sname, ref.value, dirty)

        return [label, DOM.div(y)]
    else
        error("type $T not supported, add a `StructEditor.make_control!(state::ApplicationState, ::Type{$T}, sname::Symbol, dirty=identity)` function to your package.")
    end
end

"""
    make_control!(state::ApplicationState, ::Val, dirty=identity)

Defined to dispatch to a specific field `Val(field)`, generic definition defaults to nothing and falls to `make_control!(state::ApplicationState, ::Type{T}, sname::Symbol) where T`
"""
make_control!(state::ApplicationState, ::Val, dirty=identity) = nothing


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
    value_type = typeof(value[])
    name = field_label(value_type, Val(sname))
    h = help(value_type, Val(sname) )


    md = Observable{Any}(getproperty(value[], sname))
    on(value) do v
        md[] = getproperty(v, sname)
    end

    parts = Any[DOM.div(name; class="shoelace-label"), DOM.div(md)]
    isempty(h) || push!(parts, DOM.div(h; class="shoelace-help"))
    return parts
end

function make_view!(value::Observable, ::Type{<:Vector}, sname::Symbol)
    value_type = typeof(value[])
    name = field_label(value_type, Val(sname))
    h = help(value_type, Val(sname) )

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
        value_type = typeof(value[])
        name = field_label(value_type, Val(sname))

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
function build_fields(state::ApplicationState{T}, val_fn, type_fn, container) where T
    form = []
    for name in propertynames(state.value[])
        skip_field(T, Val(name)) && continue

        ftype = hasfield(T, name) ? fieldtype(T, name) : typeof(getproperty(state.value[], name))

        parts = val_fn(state, Val(name))          # try field-specific first
        if isnothing(parts)
            parts = type_fn(state, ftype, name)   # fall to generic type
        end

        push!(form, container(parts...))
    end
    return form
end

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
function make_form(state::ApplicationState{T}; save_function::Union{SaveFunction, Nothing}=nothing, class="centered", container=cell,  buttons=[]) where T


    dirty = identity

    if !isnothing(save_function)
        save_button = SLButton("save"; variant="primary", disabled=true)

        function dirty(x::Bool)
            save_button.disabled[] = !x
            notify(state.value)
        end

        on(save_button.value) do x
            save_button.loading[] = true
            try
                if !isnothing(save_function.file)
                    open(save_function.file, "w") do io
                        JSON.json(io, state.value[]; pretty=true)
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


    

    form = build_fields(state,
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
    return make_form(ApplicationState(Observable(value)); save_function=SaveFunction(;file))
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





function editor(value::T; save_function::Union{SaveFunction, Nothing}=nothing, mode=vscode, server = nothing, path="/", icon="https://icons.getbootstrap.com/assets/icons/pencil.svg", title=string(T), debugger=nothing, kwargs...) where T

    app = App() do session

        # Build the form (and its widgets/Observables) fresh per session. Bonito
        # widgets carry mutable per-session state, so a form shared across sessions
        # breaks on the 2nd open (e.g. an SLSelect's value binding collides and the
        # client sends NaN on change). Constructing inside the closure isolates each open.
        #
        # `deepcopy` is essential: `Observable(x)` stores a *reference*, so without it
        # every session would share the same underlying struct. For mutable structs the
        # controls mutate in place (`setproperty!`), which would leak edits across all
        # open browser windows.
        obs_value = Observable(deepcopy(value))
        state = ApplicationState(obs_value, Dict())

        if !isnothing(debugger)
            debugger[] = state
        end

        form = make_form(state; save_function, kwargs...)


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

        # Fresh Observables per session (same rationale as `editor`, including the
        # `deepcopy` so sessions never share the same underlying struct).
        obs_value = Observable(deepcopy(value))
        form = make_view(obs_value; kwargs...)

        page(form; title, icon)
    end

    return run_app(app; mode, server, path)
end

end # module StructEditor
