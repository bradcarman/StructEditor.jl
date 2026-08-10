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


# Here we show an example of generating a new element with an incrementing number
function StructEditor.add_function(state::ApplicationState, ::Type{Member}, m::ShoelaceWidgets.ListManager, action::ShoelaceWidgets.OpenOKCancel)
    if action == ShoelaceWidgets.Open
        n = length(m.list.values[]) + 1
        state.memory[:member][] = Member("person $n", n)
    elseif action == ShoelaceWidgets.OK
        push!(m, deepcopy(state.memory[:member][]))
    end
end
StructEditor.add_mode(::Type{Member}) = ShoelaceWidgets.DialogMode
function StructEditor.add_content(state::ApplicationState, ::Type{Member})
    
    member = Observable(Member("name", 0))
    state.memory[:member] = member

    member_state = ApplicationState(member, state.memory)

    return StructEditor.make_form(member_state; class="")
end

debugger = Ref{ApplicationState}()

all = Group();
editor(all; debugger)


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


function StructEditor.add_content(state::ApplicationState, ::Type{MemberID})
    
    member_add = Observable(Member("name", 0))
    state.memory[:member_add] = member_add

    member_state = ApplicationState(member_add, state.memory)

    return StructEditor.make_form(member_state; class="")
end

function StructEditor.add_function(state::ApplicationState, ::Type{MemberID}, m::ShoelaceWidgets.ListManager, action::ShoelaceWidgets.OpenOKCancel)
    if action == ShoelaceWidgets.Open
        state.memory[:member_add][] = Member("new person", 0)
    elseif action == ShoelaceWidgets.OK
        id = length(m.list.values[]) + 1
        member_add = state.memory[:member_add][]
        x = MemberID(member_add.name, member_add.age, id)
        push!(m, x)
    end
end
StructEditor.add_mode(::Type{MemberID}) = ShoelaceWidgets.DialogMode



function StructEditor.edit_content(state::ApplicationState, ::Type{MemberID})
    
    member_edit = Observable(Member("name", 0))
    state.memory[:member_edit] = member_edit

    member_state = ApplicationState(member_edit, state.memory)

    return StructEditor.make_form(member_state; class="")
end

function StructEditor.edit_function(state::ApplicationState, ::Type{MemberID}, m::ShoelaceWidgets.ListManager, action::ShoelaceWidgets.OpenOKCancel)
    selected_memberid = ShoelaceWidgets.selected_value(m)
    @unpack name, age, id = selected_memberid
    if action == ShoelaceWidgets.Open
        state.memory[:member_edit][] = Member(name, age)
    elseif action == ShoelaceWidgets.OK
        member = state.memory[:member_edit][]
        @unpack name, age = member
        new_memid = MemberID(name, age, id)
        ShoelaceWidgets.replace_selected!(m, new_memid)
    end
end





debugger = Ref{ApplicationState}()

all = GroupID();
editor(all; debugger)

