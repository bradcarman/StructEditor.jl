using StructEditor
using Dates
using Markdown
using Bonito
using ShoelaceWidgets


struct Member
    name::String
    age::Int
end
Member() = Member("", 0)

@kwdef struct Group
    people::Vector{Member} = [Member("person 1", 1), Member("person 2", 2)]
end


default = Observable(Member())

function StructEditor.add_function(::Type{Member}, m::ShoelaceWidgets.ListManager, action::ShoelaceWidgets.OpenOKCancel)
    if action == ShoelaceWidgets.Open
        n = length(m.list.values[]) + 1
        default[] = Member("person $n", n)
        m.add_dialog.value[] = DOM.div("hi")
    elseif action == ShoelaceWidgets.OK
        push!(m, default[])
    end
end

StructEditor.add_mode(::Type{Member}) = ShoelaceWidgets.DialogMode
StructEditor.add_content(::Type{Member}) = StructEditor.make_form(default; class="")



# create a new file
all = Group();
editor(all)

# load an existing file
# editor(file, All, mode = StructEditor.browser)




