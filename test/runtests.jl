using Test
using Dates
using Markdown
using Bonito
using ShoelaceWidgets
using JSON
using StructUtils
using StructEditor

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

# ─────────────────────────────────────────────────────────────────────────────

@testset "StructEditor" begin

    @testset "JSON" begin
        # Direct lower / lift for Markdown.MD
        md = md"# Hello\nWorld"
        @test StructUtils.lower(md) == Markdown.plain(md)
        @test Markdown.plain(StructUtils.lift(Markdown.MD, Markdown.plain(md))) ==
              Markdown.plain(md)

        # Full round-trip for every supported field type
        original = TestAll()
        tmpfile = tempname() * ".json"
        try
            open(tmpfile, "w") do io
                JSON.json(io, original; pretty=true)
            end
            loaded = JSON.parsefile(tmpfile, TestAll)

            @test loaded.flag          == original.flag
            @test loaded.count         == original.count
            @test loaded.ratio         == original.ratio
            @test loaded.name          == original.name
            @test loaded.sym           == original.sym
            @test loaded.date          == original.date
            @test Markdown.plain(loaded.notes) == Markdown.plain(original.notes)
            @test length(loaded.items) == length(original.items)
            @test loaded.items[1].name == original.items[1].name
            @test loaded.items[1].age  == original.items[1].age
        finally
            isfile(tmpfile) && rm(tmpfile)
        end
    end

    @testset "ApplicationState" begin
        st, obs = appstate(TestAll())
        @test st isa ApplicationState{TestAll}
        @test st.value === obs
        @test isempty(st.memory)

        # The vector control's edit dialog keeps its form's Observable in `memory`,
        # keyed by parent and element type; `edit_function` looks it back up there.
        StructEditor.make_control!(st, Vector{TestPerson}, :items)
        @test haskey(st.memory, :edit_TestAll_TestPerson)
        @test st.memory[:edit_TestAll_TestPerson][] isa TestPerson

        # A composite field builds a nested ApplicationState that *shares* the parent's
        # memory Dict, so a control built one level down is visible from the top.
        group, _ = appstate(TestGroup())
        StructEditor.make_form(group)
        @test haskey(group.memory, :edit_TestAll_TestPerson)
    end

    @testset "make_control! types" begin
        st, obs = appstate(TestAll())

        controls = StructEditor.make_control!(st, Bool, :flag)
        @test length(controls) == 1
        @test controls[1] isa SLCheckbox

        controls = StructEditor.make_control!(st, Int, :count)
        @test length(controls) == 1
        @test controls[1] isa SLInput

        controls = StructEditor.make_control!(st, Float64, :ratio)
        @test length(controls) == 1
        @test controls[1] isa SLInput

        controls = StructEditor.make_control!(st, String, :name)
        @test length(controls) == 1
        @test controls[1] isa SLInput

        controls = StructEditor.make_control!(st, Symbol, :sym)
        @test length(controls) == 1
        @test controls[1] isa SLInput

        controls = StructEditor.make_control!(st, Date, :date)
        @test length(controls) == 1
        @test controls[1] isa SLInput

        controls = StructEditor.make_control!(st, Markdown.MD, :notes)
        @test length(controls) == 1
        @test controls[1] isa SLTextarea

        controls = StructEditor.make_control!(st, Vector{TestPerson}, :items)
        @test length(controls) == 1
        @test controls[1] isa ListManager

        # the field-specific hook falls through to the type-based methods by default
        @test isnothing(StructEditor.make_control!(st, Val(:flag)))
    end

    @testset "callbacks" begin
        # Bool: unchecking updates the Observable
        st, obs = appstate(TestAll(flag=true))
        checkbox = StructEditor.make_control!(st, Bool, :flag)[1]
        checkbox.value[] = false
        @test obs[].flag == false

        # Int
        st, obs = appstate(TestAll())
        input = StructEditor.make_control!(st, Int, :count)[1]
        input.value[] = 99
        @test obs[].count == 99

        # Float64
        st, obs = appstate(TestAll())
        input = StructEditor.make_control!(st, Float64, :ratio)[1]
        input.value[] = 2.71
        @test obs[].ratio ≈ 2.71

        # String
        st, obs = appstate(TestAll())
        input = StructEditor.make_control!(st, String, :name)[1]
        input.value[] = "world"
        @test obs[].name == "world"

        # Symbol: string fired by the widget is converted to Symbol
        st, obs = appstate(TestAll())
        input = StructEditor.make_control!(st, Symbol, :sym)[1]
        input.value[] = "bar"
        @test obs[].sym == :bar

        # Date: string fired by the widget is parsed to Date
        st, obs = appstate(TestAll())
        input = StructEditor.make_control!(st, Date, :date)[1]
        input.value[] = "2025-06-01"
        @test obs[].date == Date(2025, 6, 1)

        # Markdown.MD: plain-text string fired by the textarea is parsed to MD
        st, obs = appstate(TestAll())
        textarea = StructEditor.make_control!(st, Markdown.MD, :notes)[1]
        textarea.value[] = "# New\n"
        @test Markdown.plain(obs[].notes) == Markdown.plain(Markdown.parse("# New\n"))

        # Vector: the ListManager is the source of truth and syncs the field on
        # every structural change
        st, obs = appstate(TestAll())
        manager = StructEditor.make_control!(st, Vector{TestPerson}, :items)[1]
        @test [p.name for p in obs[].items] == ["Alice"]

        push!(manager, TestPerson("Bob", 2))
        @test [p.name for p in obs[].items] == ["Alice", "Bob"]
        @test obs[].items isa Vector{TestPerson}

        # reordering writes the new order back
        manager.list.index = 2
        ShoelaceWidgets.move_up!(manager)
        @test [p.name for p in obs[].items] == ["Bob", "Alice"]
        @test ShoelaceWidgets.selected_index(manager) == 1

        # the edit dialog commits on OK and discards on Cancel. The dialog's form is
        # driven by the Observable `edit_content` parked in `st.memory`.
        ShoelaceWidgets.open_editor!(manager)
        @test st.memory[:edit_TestAll_TestPerson][].name == "Bob"
        ShoelaceWidgets.accept!(manager.edit_dialog)
        @test [p.name for p in obs[].items] == ["Bob", "Alice"]

        ShoelaceWidgets.open_editor!(manager)
        ShoelaceWidgets.reject!(manager.edit_dialog)
        @test [p.name for p in obs[].items] == ["Bob", "Alice"]

        # editing through the dialog's form writes the change back on OK
        ShoelaceWidgets.open_editor!(manager)
        st.memory[:edit_TestAll_TestPerson][] = TestPerson("Zed", 9)
        ShoelaceWidgets.accept!(manager.edit_dialog)
        @test [p.name for p in obs[].items] == ["Zed", "Alice"]

        # delete and clear
        manager.list.index = 1
        ShoelaceWidgets.delete_selected!(manager)
        @test [p.name for p in obs[].items] == ["Alice"]

        empty!(manager)
        @test isempty(obs[].items)
        @test obs[].items isa Vector{TestPerson}
    end

    @testset "sync from value" begin
        # `bind_field!` binds both ways: a change to `value` re-seeds every widget.
        # This is what lets the ListManager item dialog re-seed one persistent form.
        st, obs  = appstate(TestAll())
        checkbox = StructEditor.make_control!(st, Bool, :flag)[1]
        num      = StructEditor.make_control!(st, Int, :count)[1]
        str      = StructEditor.make_control!(st, String, :name)[1]
        sym      = StructEditor.make_control!(st, Symbol, :sym)[1]
        date     = StructEditor.make_control!(st, Date, :date)[1]
        notes    = StructEditor.make_control!(st, Markdown.MD, :notes)[1]

        obs[] = TestAll(flag=false, count=7, name="synced", sym=:bar,
                        date=Date(2030, 3, 4), notes=md"## Synced")

        @test checkbox.value[] == false
        @test num.value[] == 7
        @test str.value[] == "synced"
        @test sym.value[] == "bar"           # widget space is the string
        @test date.value[] == "2030-03-04"   # SLInput(::Date) is an SLInput{String}
        @test notes.value[] == Markdown.plain(md"## Synced")

        st, obs = appstate(TestSync())
        select = StructEditor.make_control!(st, TestColor, :color)[1]
        vec = StructEditor.make_control!(st, Vector{Int}, :vec)[1]

        @test select.index[] == 1
        @test vec.value[] == "1,2,3"

        obs[] = TestSync(color=Blue, vec=[9, 8])
        @test select.index[] == 3             # widget space is the option index
        @test vec.value[] == "9,8"

        # and the control direction still writes through
        select.index[] = 2
        @test obs[].color == Green
        vec.value[] = "4,5,6"
        @test obs[].vec == [4, 5, 6]

        # `valid` rejects a cleared selection instead of indexing opts out of bounds
        select.index[] = 0
        @test obs[].color == Green

        # Composite field: the nested ApplicationState's Observable is the widget, so
        # re-seeding it cascades into the nested controls. Those widgets are inside the
        # card and not reachable from the return value, so this only asserts the cascade
        # terminates without erroring and without clobbering the value on the way back up.
        st, obs = appstate(TestNested())
        parts = StructEditor.make_control!(st, TestPerson, :person)
        @test length(parts) == 2

        obs[] = TestNested(person=TestPerson("Bob", 2))
        @test obs[].person.name == "Bob"
        @test obs[].person.age == 2
    end

    @testset "update cycle" begin
        # A programmatic change to `value` must not mark the form dirty, and an echo
        # of a value the field already holds must not either.
        dirty_calls = Ref(0)
        st, obs = appstate(TestAll())
        checkbox = StructEditor.make_control!(st, Bool, :flag, x -> (dirty_calls[] += 1))[1]

        obs[] = TestAll(flag=false)
        @test checkbox.value[] == false
        @test dirty_calls[] == 0

        # a real edit does mark it dirty
        checkbox.value[] = true
        @test obs[].flag == true
        @test dirty_calls[] == 1

        # re-firing the same value is an echo, not an edit
        checkbox.value[] = true
        @test dirty_calls[] == 1

        # Markdown compares parsed values rather than Markdown.plain output, so the
        # textarea is not rewritten to canonical form under the user's cursor
        st, obs = appstate(TestAll())
        textarea = StructEditor.make_control!(st, Markdown.MD, :notes)[1]
        textarea.value[] = "# New"          # note: no trailing newline
        @test textarea.value[] == "# New"
        @test Markdown.plain(obs[].notes) == Markdown.plain(Markdown.parse("# New"))
    end

    @testset "notify mid-edit" begin
        # A handler on the same widget that notifies `value` before the binding has
        # written the field leaves the widget ahead of its field. The sync must not
        # treat the stale field as authoritative and push it back over the widget --
        # doing so re-enters the widget's handlers and replays the edit. Regression
        # for a select whose handler appended to a second field: picking "B" once
        # produced ["B", "A", "B"].
        st, obs = appstate(TestSync())
        select = StructEditor.make_control!(st, TestColor, :color)[1]

        seen = String[]
        on(select.index) do i          # registered BEFORE the binding below
            i > 0 && (push!(seen, string(instances(TestColor)[i])); notify(obs))
        end
        # `bind_field!` still takes the Observable, not the ApplicationState
        StructEditor.bind_field!(st, :color, select.index;
                                 to_field = i -> instances(TestColor)[i],
                                 to_widget = v -> something(findfirst(==(v), instances(TestColor)), 1),
                                 valid = i -> 1 <= i <= length(instances(TestColor)))

        select.index[] = 2
        @test seen == ["Green"]        # fired once, not three times
        @test obs[].color == Green
        @test select.index[] == 2      # and the widget was not rolled back

        select.index[] = 3
        @test seen == ["Green", "Blue"]
        @test obs[].color == Blue
    end

    @testset "vector sync" begin
        # The list mirrors its field both ways, and a change to an unrelated field
        # must not rebuild it (which would drop the user's selection).
        st, obs = appstate(TestAll())
        manager = StructEditor.make_control!(st, Vector{TestPerson}, :items)[1]

        # field changed elsewhere: the list rebuilds from it
        obs[] = TestAll(items=[TestPerson("Bob", 2), TestPerson("Cleo", 3)])
        @test [p.name for p in ShoelaceWidgets.get_values(manager)] == ["Bob", "Cleo"]

        # an unrelated field moving leaves the list and its selection alone
        manager.list.index = 2
        obs[] = TestAll(count=99, items=obs[].items)
        @test ShoelaceWidgets.selected_index(manager) == 2
        @test [p.name for p in ShoelaceWidgets.get_values(manager)] == ["Bob", "Cleo"]

        # in-place mutation of the field vector is still picked up, because `seen`
        # holds a copy rather than aliasing the field
        push!(obs[].items, TestPerson("Dee", 4))
        notify(obs)
        @test [p.name for p in ShoelaceWidgets.get_values(manager)] == ["Bob", "Cleo", "Dee"]

        # and the control direction still writes through
        ShoelaceWidgets.delete_selected!(manager)
        @test [p.name for p in obs[].items] == ["Bob", "Dee"]
    end

    @testset "make_form and editor" begin
        st, obs = appstate(TestAll())

        # make_form without a file (no save button)
        form = StructEditor.make_form(st)
        @test !isnothing(form)

        # make_form with a file (adds save button)
        st, obs = appstate(TestAll())
        form = StructEditor.make_form(st; save_function=StructEditor.SaveFunction(file=tempname() * ".json"))
        @test !isnothing(form)

        # editor from a value returns a Bonito App
        app = editor(TestAll(); save_function=StructEditor.SaveFunction(file=tempname() * ".json"))
        @test app isa Bonito.App

        # the `debugger` Ref is accepted and not forwarded on to make_form
        app = editor(TestAll(); debugger=Ref{ApplicationState}())
        @test app isa Bonito.App

        # editor from a file returns a Bonito App
        tmpfile = tempname() * ".json"
        try
            open(tmpfile, "w") do io
                JSON.json(io, TestAll(); pretty=true)
            end
            app = editor(tmpfile, TestAll)
            @test app isa Bonito.App
        finally
            isfile(tmpfile) && rm(tmpfile)
        end
    end

    @testset "viewer" begin
        # `make_view` / `viewer` still take the Observable directly
        obs = Observable(TestAll())
        @test !isnothing(StructEditor.make_view(obs))
        @test viewer(TestAll()) isa Bonito.App
    end

end
