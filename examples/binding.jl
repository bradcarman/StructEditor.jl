using StructEditor
using Bonito
using ShoelaceWidgets
using ShoelaceWidgets: get_values

@enum Choices A B C

@kwdef struct Chooser
    choice::Choices=A
    chosen::Int=1
end

c = Chooser()
state = ApplicationState(c)

App() do session

    opts = instances(Choices)
    select = SLSelect([string(x) for x in opts]; label="choice")
    number = SLInput(0; label="chosen")


    StructEditor.bind_field!(state, :choice, select.index; 
        to_field=x->Choices(x-1), 
        to_widget=x->Int(x)+1, 
        valid=x->x>0,
        initialize=true)
    StructEditor.bind_field!(state, :chosen, select.index)

    StructEditor.bind_field!(state, :chosen, number.value; initialize=true)
    

    return sl_tab_group(
        sl_tab("General"; panel="general", slot="nav"),
        sl_tab("Other"; panel="other", slot="nav"),

        sl_tab_panel(Grid(select, number, DOM.div(""; style="height:200px;background-color:gray")); name="general"),
        sl_tab_panel("TEST"; name="other");
        placement="start"
    )
end