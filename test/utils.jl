# ── Test structs ──────────────────────────────────────────────────────────────

@kwdef struct TestPerson
    name::String = ""
    age::Int = 0
end

@kwdef struct TestAll
    flag::Bool         = true
    count::Int         = 42
    ratio::Float64     = 3.14
    name::String       = "hello"
    sym::Symbol        = :foo
    date::Date         = Date(2024, 1, 15)
    notes::Markdown.MD = md"# Test"
    items::Vector{TestPerson} = [TestPerson("Alice", 1)]
end

@kwdef struct TestNested
    person::TestPerson = TestPerson("Alice", 1)
    label::String = "outer"
end

@enum TestColor Red Green Blue

# the Enum and numeric-vector controls live here so TestAll stays as it is
@kwdef struct TestSync
    color::TestColor = Red
    vec::Vector{Int} = [1, 2, 3]
end

# a composite field that itself holds a vector, so the nested control registers into
# the parent's `memory`
@kwdef struct TestGroup
    team::TestAll = TestAll()
    label::String = "group"
end

# readonly() is exercised on this struct rather than TestAll/TestPerson, so marking
# fields readonly here doesn't affect the JSON round-trip / sync tests above
@kwdef struct TestReadonly
    name::String = "Alice"
    color::TestColor = Red
    people::Vector{TestPerson} = [TestPerson("Bob", 5)]
    nested::TestPerson = TestPerson("Cleo", 9)   # left editable, to test `forced` cascade
end

StructEditor.readonly(::Type{TestReadonly}, ::Val{:name}) = true
StructEditor.readonly(::Type{TestReadonly}, ::Val{:color}) = true
StructEditor.readonly(::Type{TestReadonly}, ::Val{:people}) = true

# ── Helpers ───────────────────────────────────────────────────────────────────

"""
`make_control!` and `make_form` take an `ApplicationState`, so wrap the value and hand
back the underlying Observable alongside it: the assertions read and write the value
through the Observable exactly as the widgets' bindings do.
"""
function appstate(value)
    obs = Observable(value)
    return ApplicationState(obs, Dict()), obs
end
