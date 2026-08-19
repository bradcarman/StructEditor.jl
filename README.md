# StructEditor.jl

StructEditor.jl generates interactive web-based forms for editing Julia structs. It automatically maps struct fields to appropriate UI controls (using [ShoelaceWidgets.jl](https://bradcarman.github.io/ShoelaceWidgets.jl/dev/)), and saves/loads the result to a JSON file. A read-only `viewer` is also provided for displaying a struct without editing controls.

Here is an example of the form generated straight out of the box using StructEditor.jl

![example](./docs/example.png)

## Features

- Automatically generates form controls based on field types:
  - `Bool` → checkbox
  - `Number` / `String` / `Symbol` → text input
  - `Enum` → dropdown select
  - `Date` → date input
  - `Markdown.MD` → multi-line textarea
  - `Vector` → tree view with per-item dialogs for nested structs
- Automatically builds control cards for child structs
- Read-only `viewer` that displays the same struct without editing controls (fields render as labelled text via `make_view!`) and updates reactively when the underlying value changes
- Loads and saves struct data as JSON
- Renders in VS Code (default) or a browser

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/bradcarman/StructEditor.jl")
```

## Usage

```julia
using StructEditor
using Dates
using Markdown

@kwdef struct Person
    name::String = "name"
    age::Int = 0
end

@kwdef struct All
    num::Float64 = 1.0
    date::Date = Date(now())
    string::String = "test"
    bool::Bool = true
    markdown::Markdown.MD = md"# Header"
    people::Vector{Person} = [Person("person 1", 1), Person("person 2", 2)]
end

file = joinpath(@__DIR__, "All.json")

# Edit a new value in VS Code, saving to `file` when the save button is clicked
editor(All(); save_function = StructEditor.SaveFunction(; file))

# Load an existing JSON file and open in the browser
editor(file, All; mode = StructEditor.browser)

# Display a value read-only (no editing controls, no save button)
viewer(All())

# Or load and display an existing JSON file
viewer(file, All)
```

For more advanced examples: 
- how to handle `abstract` types, see "examples/pets.jl"
- how to handle manipulation of controls based on set values, see "examples/toggle.jl"
- how to handle composite field types, see "examples/special.jl"
- how to define `make_control!` for specific fields, see "examples/fieldpattern.jl"
- how to manage vectors, see "examples/vectors.jl"

## Vector Controls
StructEditor.jl includes the ability to handle Vectors with add, remove, clear, edit, and re-ording controls.  It's possible to control how Vectors are handled thru the below functions.

### Add and Edit Modes
- `add_mode(parent::Type, child::Val)` set to `NoAdd` (default), `FunctionAdd`, or `DialogAdd`
- `edit_mode(parent::Type, child::Val)` set to `NoEdit` (default), or `DialogEdit`

The options `NoAdd` and `NoEdit` will hide the `add` and `edit` buttons, respectively.

### Add Mode : FunctionAdd 
To define what happens when the `add` button is clicked, the following function can be defined, specialzing on the struct type `P` and the vector element type `T`.  The `build_add` function must return 2 values: a `Hyperscript.Node` and an `add_function(session::Session)`.  For `FunctionAdd` mode, the first value is ignored.  See "examples/vectors.jl" to see how this can be used to define new items based on the applicaiton state.

```julia
function build_add(state::ApplicationState{P}, ::Type{T}, ::Val{FunctionAdd}) where {P, T}

    add_content = DOM.div()
    add_function(session::Session) = add_new(T)

    return add_content, add_function
end
```

### Add Mode : DialogAdd
When the `add` button is clicked it's possible to display a dialog first so that the new element can be edited before it's added to the Vector.  To control this behavior the below `build_add` function can be defined, specialzing on the struct type `P` and the vector element type `T`.  The `build_add` function must return 2 values: a `Hyperscript.Node` to define the dialog and an `add_function(m::ShoelaceWidgets.ListManager, action::ShoelaceWidgets.OpenOKCancel)` to define the dialog behavior on `Open`, `OK`, and `Cancel`.  See "examples/vectors.jl" to see how this can be used to implement 1 type for the adding dialog and then transfer the data to the Vector type, a useful method to hide and control certain fields such as an unique `id` field.

```julia
function build_add(state::ApplicationState{P}, ::Type{T}, ::Val{DialogAdd}) where {P, T}

    add_obs = Observable(add_new(T))

    element_state = ApplicationState(add_obs, state.memory)
    add_content = make_form(element_state; class="")

    function add_function(m::ShoelaceWidgets.ListManager, action::ShoelaceWidgets.OpenOKCancel)
        if action == ShoelaceWidgets.Open
            add_obs[] =  add_new(T)
        elseif action == ShoelaceWidgets.OK
            push!(m, deepcopy(add_obs[]))
        end
    end

    return add_content, add_function
end
```


### Edit Mode : DialogEdit
The edit dialog is setup the same as the add dialog, except the `build_edit` function is used, setup in the same way.  Again, see "examples/vectors.jl" for an example of how this can be used.

```julia
function build_edit(state::ApplicationState{P}, ::Type{T}, ::Val{DialogEdit}) where {P, T}

    edit_obs = Observable(add_new(T))

    element_state = ApplicationState(edit_obs, state.memory)
    edit_content = make_form(element_state; class="")

    function edit_function(m::ShoelaceWidgets.ListManager, action::ShoelaceWidgets.OpenOKCancel)
        if action == ShoelaceWidgets.Open
            edit_obs[] =  ShoelaceWidgets.selected_value(m)
        elseif action == ShoelaceWidgets.OK
            ShoelaceWidgets.replace_selected!(m, deepcopy(edit_obs[]))
        end
    end

    return edit_content, edit_function
end
```


## API

### editor
```julia
editor(value; save_function=nothing, mode=vscode, server=nothing, path="/", icon, title, kwargs...)
editor(file::String, T::Type; mode=vscode, kwargs...)
```

Opens an interactive editor for struct `value` (or for a value of type `T` loaded from the JSON `file`). The second form auto-creates a `SaveFunction` targeting `file`, so edits save back to it.

#### kwargs

  * `save_function::Union{SaveFunction, Nothing}=nothing`: see [`SaveFunction`](@ref); when `nothing` no save button is shown
  * `mode`: one of `StructEditor.vscode` (default), `browser`, `online`, or `quite`
  * `server`: an optional `Bonito.Server` to route the app onto
  * `path="/"`: route path when serving
  * `icon`: favicon URL (default https://icons.getbootstrap.com/assets/icons/pencil.svg)
  * `title=string(T)`: page title

Remaining keywords (`class`, `container`, `buttons`) are forwarded to [`make_form`](@ref). See also [`viewer`](@ref) for a read-only display.




### viewer
```julia
viewer(value; mode=vscode, server=nothing, path="/", icon, title, kwargs...)
viewer(file::String, T::Type; mode=vscode, kwargs...)
```

Opens a read-only display of struct `value` (or a value of type `T` loaded from the JSON `file`). The read-only counterpart to [`editor`](@ref): each field is rendered as labelled text via [`make_view!`](@ref) instead of an editing control, and there is no save button.

#### kwargs

  * `mode`: one of `StructEditor.vscode` (default), `browser`, `online`, or `quite`
  * `server`: an optional `Bonito.Server` to route the app onto
  * `path="/"`: route path when serving
  * `icon`: favicon URL (default https://icons.getbootstrap.com/assets/icons/eye.svg)
  * `title=string(T)`: page title

Remaining keywords (`class`, `container`) are forwarded to [`make_view`](@ref).

### StructEditor.SaveFunction
```julia
SaveFunction(; file=nothing, func=nothing)
```

Describes what an [`editor`](@ref)'s `save` button does. Supplying a `SaveFunction` to `editor` (or `make_form`) is what enables the save button; both fields default to `nothing`:

  * `file`: path to the JSON file `value` is written to on save
  * `func`: a zero-argument function called on save (e.g. to trigger downstream side effects)

Pass either or both.


### StructEditor.make_control!
```julia
make_control!(state::ApplicationState, ::Val, dirty=identity)
```

Defined to dispatch to a specific field `Val(field)`, generic definition defaults to nothing and falls to `make_control!(value::Observable, ::Type{T}, sname::Symbol) where T`


### StructEditor.make_view!
```julia
make_view!(value::Observable, ::Val)
```

Field-specific dispatch hook (mirrors the `make_control!(::Val)` hook). The generic definition returns `nothing`, falling through to the type-based `make_view!`.



