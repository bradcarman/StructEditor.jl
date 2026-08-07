using StructEditor
using Dates
using Markdown
using Bonito
using ShoelaceWidgets
using UnPack


# -----------------------------------------------------------------
# -----------------------------------------------------------------
#   Here we demonstrate a more advanced handling of adding a new 
#   element to the vector.  The idea is to show a dialog before the 
#   new item is added to the list.  To do this we must implment 3 
#   interface functions:
#   - add_function: used to add logic for Open, OK, and Cancel actions
#   - add_mode: Chose DialogMode to use a form
#   - add_content: Use `make_form` to provide the form contents
# -----------------------------------------------------------------
# -----------------------------------------------------------------

struct Member
    name::String
    age::Int
end
Member() = Member("", 0)

@kwdef struct Group
    people::Vector{Member} = [Member("person 1", 1), Member("person 2", 2)]
end

# this variable holds that data shown in the Add form.  
default = Observable(Member())

# Here we show an example of generating a new element with an incrementing number
function StructEditor.add_function(::Type{Member}, m::ShoelaceWidgets.ListManager, action::ShoelaceWidgets.OpenOKCancel)
    if action == ShoelaceWidgets.Open
        n = length(m.list.values[]) + 1
        default[] = Member("person $n", n)
    elseif action == ShoelaceWidgets.OK
        push!(m, deepcopy(default[]))
    end
end
StructEditor.add_mode(::Type{Member}) = ShoelaceWidgets.DialogMode
StructEditor.add_content(::Type{Member}) = StructEditor.make_form(default; class="")

all = Group();
editor(all)


# -----------------------------------------------------------------
# -----------------------------------------------------------------
#   Here we demonstrate the concept of using one data type for 
#   adding/editing (i.e. Member) but service a vector of the target 
#   type MemberID.  This enables us to keep the id field protected.
# -----------------------------------------------------------------
# -----------------------------------------------------------------

struct MemberID
    name::String
    age::Int
    id::Int
end
MemberID() = MemberID("", 0, 0)

@kwdef struct GroupID
    people::Vector{MemberID} = [MemberID("person 1", 10, 1), MemberID("person 2", 20, 2)]
end


function StructEditor.add_function(::Type{MemberID}, m::ShoelaceWidgets.ListManager, action::ShoelaceWidgets.OpenOKCancel)
    if action == ShoelaceWidgets.Open
        default[] = Member("new person", 0)
    elseif action == ShoelaceWidgets.OK
        id = length(m.list.values[]) + 1
        member = default[]
        x = MemberID(member.name, member.age, id)
        push!(m, x)
    end
end
StructEditor.add_mode(::Type{MemberID}) = ShoelaceWidgets.DialogMode
StructEditor.add_content(::Type{MemberID}) = StructEditor.make_form(default; class="")

StructEditor.edit_observable(::Type{MemberID}) = default
function StructEditor.edit_function(::Type{MemberID}, value::Observable, m::ShoelaceWidgets.ListManager, action::ShoelaceWidgets.OpenOKCancel)
    selected_memberid = ShoelaceWidgets.selected_value(m)
    @unpack name, age, id = selected_memberid
    if action == ShoelaceWidgets.Open
        value[] = Member(name, age)
    elseif action == ShoelaceWidgets.OK
        member = value[]
        @unpack name, age = member
        new_memid = MemberID(name, age, id)
        ShoelaceWidgets.replace_selected!(m, new_memid)
    end
end

all = GroupID();
editor(all)

