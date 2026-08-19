using StructEditor
using Test

include("utils.jl")

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

# delete and clear
manager.list.index = 1
ShoelaceWidgets.delete_selected!(manager)
@test [p.name for p in obs[].items] == ["Alice"]

empty!(manager)
@test isempty(obs[].items)
@test obs[].items isa Vector{TestPerson}