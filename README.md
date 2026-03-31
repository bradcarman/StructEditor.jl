# StructEditor.jl

StructEditor.jl generates interactive web-based forms for editing Julia structs. It automatically maps struct fields to appropriate UI controls (using [ShoelaceWidgets.jl](https://bradcarman.github.io/ShoelaceWidgets.jl/dev/)), and saves/loads the result to a JSON file.

Here is an example of the form generated straight out of the box using StructEditor.jl

![example](https://private-user-images.githubusercontent.com/40798837/572129146-417f5886-1322-4ea9-bd16-2c87ca2da051.png?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NzQ5ODc1NjAsIm5iZiI6MTc3NDk4NzI2MCwicGF0aCI6Ii80MDc5ODgzNy81NzIxMjkxNDYtNDE3ZjU4ODYtMTMyMi00ZWE5LWJkMTYtMmM4N2NhMmRhMDUxLnBuZz9YLUFtei1BbGdvcml0aG09QVdTNC1ITUFDLVNIQTI1NiZYLUFtei1DcmVkZW50aWFsPUFLSUFWQ09EWUxTQTUzUFFLNFpBJTJGMjAyNjAzMzElMkZ1cy1lYXN0LTElMkZzMyUyRmF3czRfcmVxdWVzdCZYLUFtei1EYXRlPTIwMjYwMzMxVDIwMDEwMFomWC1BbXotRXhwaXJlcz0zMDAmWC1BbXotU2lnbmF0dXJlPWUyN2RjYTM5Y2E1N2JkNjAxMjBhOTgzNDlmMzg2ZWJlMGYzNmNlMGRiZWFkZjZlZjQ0ODk5OTk3MWYyMzNhMGUmWC1BbXotU2lnbmVkSGVhZGVycz1ob3N0In0._xrb5cdr1-pQTFqpTVwLygSGS-BFiP8uOhR2h9NY6kw)

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


