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

    @testset "make_control! types" begin
        obs = Observable(TestAll())

        controls = StructEditor.make_control!(obs, Bool, :flag)
        @test length(controls) == 1
        @test controls[1] isa SLCheckbox

        controls = StructEditor.make_control!(obs, Int, :count)
        @test length(controls) == 1
        @test controls[1] isa SLInput

        controls = StructEditor.make_control!(obs, Float64, :ratio)
        @test length(controls) == 1
        @test controls[1] isa SLInput

        controls = StructEditor.make_control!(obs, String, :name)
        @test length(controls) == 1
        @test controls[1] isa SLInput

        controls = StructEditor.make_control!(obs, Symbol, :sym)
        @test length(controls) == 1
        @test controls[1] isa SLInput

        controls = StructEditor.make_control!(obs, Date, :date)
        @test length(controls) == 1
        @test controls[1] isa SLInput

        controls = StructEditor.make_control!(obs, Markdown.MD, :notes)
        @test length(controls) == 1
        @test controls[1] isa SLTextarea

        controls = StructEditor.make_control!(obs, Vector{TestPerson}, :items)
        @test length(controls) == 1
        @test controls[1] isa ListManager
    end

    @testset "callbacks" begin
        # Bool: unchecking updates the Observable
        obs = Observable(TestAll(flag=true))
        checkbox = StructEditor.make_control!(obs, Bool, :flag)[1]
        checkbox.value[] = false
        @test obs[].flag == false

        # Int
        obs = Observable(TestAll())
        input = StructEditor.make_control!(obs, Int, :count)[1]
        input.value[] = 99
        @test obs[].count == 99

        # Float64
        obs = Observable(TestAll())
        input = StructEditor.make_control!(obs, Float64, :ratio)[1]
        input.value[] = 2.71
        @test obs[].ratio ≈ 2.71

        # String
        obs = Observable(TestAll())
        input = StructEditor.make_control!(obs, String, :name)[1]
        input.value[] = "world"
        @test obs[].name == "world"

        # Symbol: string fired by the widget is converted to Symbol
        obs = Observable(TestAll())
        input = StructEditor.make_control!(obs, Symbol, :sym)[1]
        input.value[] = "bar"
        @test obs[].sym == :bar

        # Date: string fired by the widget is parsed to Date
        obs = Observable(TestAll())
        input = StructEditor.make_control!(obs, Date, :date)[1]
        input.value[] = "2025-06-01"
        @test obs[].date == Date(2025, 6, 1)

        # Markdown.MD: plain-text string fired by the textarea is parsed to MD
        obs = Observable(TestAll())
        textarea = StructEditor.make_control!(obs, Markdown.MD, :notes)[1]
        textarea.value[] = "# New\n"
        @test Markdown.plain(obs[].notes) == Markdown.plain(Markdown.parse("# New\n"))

        # Vector: the ListManager is the source of truth and syncs the field on
        # every structural change
        obs = Observable(TestAll())
        manager = StructEditor.make_control!(obs, Vector{TestPerson}, :items)[1]
        @test [p.name for p in obs[].items] == ["Alice"]

        push!(manager, TestPerson("Bob", 2))
        @test [p.name for p in obs[].items] == ["Alice", "Bob"]
        @test obs[].items isa Vector{TestPerson}

        # reordering writes the new order back
        manager.list.index = 2
        ShoelaceWidgets.move_up!(manager)
        @test [p.name for p in obs[].items] == ["Bob", "Alice"]
        @test ShoelaceWidgets.selected_index(manager) == 1

        # the edit dialog commits on OK and discards on Cancel
        ShoelaceWidgets.open_editor!(manager)
        ShoelaceWidgets.accept!(manager.edit_dialog)
        @test [p.name for p in obs[].items] == ["Bob", "Alice"]

        ShoelaceWidgets.open_editor!(manager)
        ShoelaceWidgets.reject!(manager.edit_dialog)
        @test [p.name for p in obs[].items] == ["Bob", "Alice"]

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
        obs      = Observable(TestAll())
        checkbox = StructEditor.make_control!(obs, Bool, :flag)[1]
        num      = StructEditor.make_control!(obs, Int, :count)[1]
        str      = StructEditor.make_control!(obs, String, :name)[1]
        sym      = StructEditor.make_control!(obs, Symbol, :sym)[1]
        date     = StructEditor.make_control!(obs, Date, :date)[1]
        notes    = StructEditor.make_control!(obs, Markdown.MD, :notes)[1]

        obs[] = TestAll(flag=false, count=7, name="synced", sym=:bar,
                        date=Date(2030, 3, 4), notes=md"## Synced")

        @test checkbox.value[] == false
        @test num.value[] == 7
        @test str.value[] == "synced"
        @test sym.value[] == "bar"           # widget space is the string
        @test date.value[] == "2030-03-04"   # SLInput(::Date) is an SLInput{String}
        @test notes.value[] == Markdown.plain(md"## Synced")

        obs = Observable(TestSync())
        select = StructEditor.make_control!(obs, TestColor, :color)[1]
        vec = StructEditor.make_control!(obs, Vector{Int}, :vec)[1]

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

        # Composite field: `ref` is the widget, so re-seeding it cascades into the
        # nested controls. Those widgets are inside the card and not reachable from
        # the return value, so this only asserts the cascade terminates without
        # erroring and without clobbering the value on the way back up.
        obs = Observable(TestNested())
        parts = StructEditor.make_control!(obs, TestPerson, :person)
        @test length(parts) == 2

        obs[] = TestNested(person=TestPerson("Bob", 2))
        @test obs[].person.name == "Bob"
        @test obs[].person.age == 2
    end

    @testset "update cycle" begin
        # A programmatic change to `value` must not mark the form dirty, and an echo
        # of a value the field already holds must not either.
        dirty_calls = Ref(0)
        obs = Observable(TestAll())
        checkbox = StructEditor.make_control!(obs, Bool, :flag, x -> (dirty_calls[] += 1))[1]

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
        obs = Observable(TestAll())
        textarea = StructEditor.make_control!(obs, Markdown.MD, :notes)[1]
        textarea.value[] = "# New"          # note: no trailing newline
        @test textarea.value[] == "# New"
        @test Markdown.plain(obs[].notes) == Markdown.plain(Markdown.parse("# New"))
    end

    @testset "make_form and editor" begin
        obs = Observable(TestAll())

        # make_form without a file (no save button)
        form = StructEditor.make_form(obs)
        @test !isnothing(form)

        # make_form with a file (adds save button)
        form = StructEditor.make_form(obs; save_function=StructEditor.SaveFunction(file=tempname() * ".json"))
        @test !isnothing(form)

        # editor from a value returns a Bonito App
        app = editor(TestAll(); save_function=StructEditor.SaveFunction(file=tempname() * ".json"))
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

end
