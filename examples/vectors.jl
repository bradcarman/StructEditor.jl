using StructEditor
using Dates
using Markdown
using Bonito
using ShoelaceWidgets
using UnPack


struct ItemDisplayExample
    data::Vector{String}
end

function StructEditor.build_item(state::ApplicationState{ItemDisplayExample}, ::Type{String})

    function item_function(m::ShoelaceWidgets.ListManager, value::String)

        input = SLInput(value) 
        on(input.value) do x
            notify(m.list.values) # ensure item is updated to source
        end

        return SLListItem(DOM.div(input); object=input)
    end

    function get_function(m::ShoelaceWidgets.ListManager, x::SLListItem)
        input = x.object
        return input.value[]
    end

    return item_function, get_function
end


debugger = Ref{ApplicationState}()
editor(ItemDisplayExample(["A","B","C"]); debugger)

#=
Change a value in the list and hit enter, then view the changes in the source observable...

debugger[].value[].data #<-- should match changes in the list
=#

# -----------------------------------------------------------------
# -----------------------------------------------------------------
#   Here we demonstrate a more advanced handling of adding a new 
#   element to the vector.  The following 2 functions are needed:
#   - add_mode --> ShoelaceWidgets.FunctionAdd
#   - build_add --> add_function
#
#  The `add_mode` is set to `FunctionAdd` that means the `add_function`
#  is called to generate the new element to be added to the Vector.
#  The other mode is `DialogAdd` which displays a dialog to set the
#  item before it's added to the Vector.
#
#  For `FunctionAdd` mode, the `build_add` function returns just the
#  `add_function` used to generate a new item to add to the list (there
#  is no dialog content to build in this mode).
#
#  In this example we set the `age` to the next increment before adding
#  the item to the list.
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
StructEditor.add_mode(::Type{Group}, ::Val{:people}) = FunctionAdd
StructEditor.edit_mode(::Type{Group}, ::Val{:people}) = DialogEdit

function StructEditor.build_add(state::ApplicationState{Group}, ::Type{Member}, ::Val{ShoelaceWidgets.FunctionAdd})
    function add_function(session::Session)
        group = state.value[]
        n = length(group.people)+1
        return Member("person $n", n)
    end

    return add_function
end


# create a debugger object to analyze the application state in the REPL
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

StructEditor.add_mode(::Type{GroupID}, ::Val{:people}) = DialogAdd
function StructEditor.build_add(state::ApplicationState{GroupID}, ::Type{MemberID}, ::Val{ShoelaceWidgets.DialogAdd})
    
    add_obs = Observable(Member("name", 0))

    element_state = ApplicationState(add_obs, state.memory)
    add_content = StructEditor.make_form(element_state; class="")

    function add_function(m::ShoelaceWidgets.ListManager, action::ShoelaceWidgets.OpenOKCancel)
        if action == ShoelaceWidgets.Open
            add_obs[] =  Member("new person", 0)
        elseif action == ShoelaceWidgets.OK
            member = add_obs[]
            @unpack name, age = member
            groupid = state.value[]
            id = length(groupid.people)+1
            push!(m, MemberID(name, age, id))
        end
    end

    return add_content, add_function
end


StructEditor.edit_mode(::Type{GroupID}, ::Val{:people}) = DialogEdit
function StructEditor.build_edit(state::ApplicationState{GroupID}, ::Type{MemberID}, ::Val{ShoelaceWidgets.DialogEdit})

    edit_obs = Observable(Member("name", 0))

    element_state = ApplicationState(edit_obs, state.memory)
    edit_content = StructEditor.make_form(element_state; class="")

    function edit_function(m::ShoelaceWidgets.ListManager, action::ShoelaceWidgets.OpenOKCancel)
        selected_memberid = ShoelaceWidgets.selected_value(m)
        @unpack name, age, id = selected_memberid
        if action == ShoelaceWidgets.Open
            edit_obs[] = Member(name, age)
        elseif action == ShoelaceWidgets.OK
            member = edit_obs[]
            @unpack name, age = member
            new_memid = MemberID(name, age, id)
            ShoelaceWidgets.replace_selected!(m, new_memid)
        end
    end

    return edit_content, edit_function
end

debugger = Ref{ApplicationState}()

all = GroupID();
editor(all; debugger)

