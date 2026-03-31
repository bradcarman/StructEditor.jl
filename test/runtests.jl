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
        @test length(controls) == 3
        @test controls[1] isa SLList
        @test controls[2] isa SLDialog
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
    end

    @testset "make_form and editor" begin
        obs = Observable(TestAll())

        # make_form without a file (no save button)
        form = StructEditor.make_form(obs; file="")
        @test !isnothing(form)

        # make_form with a file (adds save button)
        form = StructEditor.make_form(obs; file=tempname() * ".json")
        @test !isnothing(form)

        # editor from a value returns a Bonito App
        app = editor(TestAll(); file=tempname() * ".json")
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
