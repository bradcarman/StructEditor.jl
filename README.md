# StructEditor.jl

StructEditor.jl generates interactive web-based forms for editing Julia structs. It automatically maps struct fields to appropriate UI controls (using [ShoelaceWidgets.jl](https://bradcarman.github.io/ShoelaceWidgets.jl/dev/)), and saves/loads the result to a JSON file.

Here is an example of the form generated straight out of the box using StructEditor.jl

![example](https://private-user-images.githubusercontent.com/40798837/572985923-647ba4f4-c209-4ed0-a6a0-7094f1f83a55.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NzUxMjI0MDcsIm5iZiI6MTc3NTEyMjEwNywicGF0aCI6Ii80MDc5ODgzNy81NzI5ODU5MjMtNjQ3YmE0ZjQtYzIwOS00ZWQwLWE2YTAtNzA5NGYxZjgzYTU1LnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNjA0MDIlMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjYwNDAyVDA5MjgyN1omWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPTAwMmE5YjRhMTYzMjFiODQzYzU3NDM2ZThmYzIzZTc4N2Q0NTBmMWNjOTZiOTAyYjRmMDRlMTI3ZTBiMDFmODgmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0.3uzRnojFWiQWbga-t4i5Gd3318nxTNkVSKlPloINT7c)

## Features

- Automatically generates form controls based on field types:
  - `Bool` → checkbox
  - `Number` / `String` → text input
  - `Date` → date input
  - `Markdown.MD` → multi-line textarea
  - `Vector` → tree view with per-item dialogs for nested structs
- Autoamitically builds control cards for special types inherriting `AbstractStructEditor`
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

# Edit a new value in VS Code
editor(All(); file)

# Load an existing JSON file and open in the browser
editor(file, All; mode = StructEditor.browser)
```

For a more advanced examples: 
- how to handle `abstract` types, see "examples/pets.jl"
- how to handle manipulation of controls based on set values, see "examples/toggle.jl"
- how to handle complex types using `AbstractStructEditor` type


## API

### `editor(value; file, mode, kwargs...)`

Opens an editor for `value` (a struct instance). Changes are saved to `file` when the **save** button is clicked.

- `file`: path to the JSON file (default: `"value.json"`)
- `mode`: `StructEditor.vscode` (default) or `StructEditor.browser`

### `editor(file, T; mode, kwargs...)`

Loads a struct of type `T` from a `file` path and opens an editor for it.

### `make_control!(value::Observable, ::Type{T}, sname::Symbol)`

By defining `make_control!` for your type `T`, customization is possible.  See "examples/pets.jl" for an example of how this can be implemented.


