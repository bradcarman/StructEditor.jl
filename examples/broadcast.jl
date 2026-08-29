using StructEditor
using ShoelaceWidgets
using Bonito


#=
In this example it's shown how to edit lists and items in separate editors (using the `link_editor` function) and pass the information
back to the original source.  To see the power of this example, click the "edit list" or the "edit item" buttons 
and when the "Save" button is clicked you can see the changes reflected in the original list.  This example is 
done with a server to show that the button links don't violate any pop-up rules, and this should work
in a deployed setting.
=#
server = Bonito.Server("0.0.0.0", 8080)

struct Item
    name::String
end

Item() = Item("new item")

struct ItemList
    items::Vector{Item}
end

StructEditor.edit_mode(::Type{ItemList}, ::Val{:items}) = StructEditor.NoEdit

struct EditList
    items::Vector{Item}
end

StructEditor.add_mode(::Type{EditList}, ::Val{:items}) = StructEditor.FunctionAdd

function StructEditor.make_control!(state::ApplicationState{ItemList}, ::Val{:items}, dirty::Function)

    # Here we get the list control
    list_manager, = StructEditor.make_control!(state, Vector{Item}, :items, dirty)
    
    # Adding the edit list button
    function onclick_list()
        main = state.value[]    
        edit = EditList(main.items)

        function save_update(edit_state::ApplicationState{EditList})

            main_items = state.value[]
            edit_items = edit_state.value[]
            empty!(main_items.items)
            append!(main_items.items, edit_items.items)

            notify(state.value)
        end

        return edit, StructEditor.SaveFunction(;func=save_update)
    end
    edit_list = StructEditor.link_editor("edit list", server, "/edit", onclick_list; icon="https://icons.getbootstrap.com/assets/icons/pencil.svg", title="Edit")

    # Adding the edit item button
    function onclick_edit()
        item = ShoelaceWidgets.selected_value(list_manager)

        function save_item(edit_state::ApplicationState{Item})
            ShoelaceWidgets.replace_selected!(list_manager, edit_state.value[])
        end

        return item, StructEditor.SaveFunction(; func = save_item)
    end
    edit_item = StructEditor.link_editor("edit item", server, "/item", onclick_edit; icon="https://icons.getbootstrap.com/assets/icons/box.svg", title="Item")
    
    return [list_manager, edit_list, edit_item]
end


# Here we have the original source to be edited.
main = ItemList([Item("A"), Item("B")])



url = editor(main;  
        server, 
        mode=StructEditor.online, 
        path="/", 
        icon="https://icons.getbootstrap.com/assets/icons/list.svg", 
        title="List Editor")
Bonito.HTTPServer.openurl(url)